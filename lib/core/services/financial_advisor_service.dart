import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:wfer_flousk_firebase/core/config/ai_config.dart';
import 'package:wfer_flousk_firebase/core/models/advisor_message.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_data_service.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

/// Le "cerveau" du systeme multi-agent conseiller financier de SmartSave.
///
/// ARCHITECTURE (version 100% gratuite, sans serveur) : ce service tourne
/// entierement sur le telephone de l'utilisateur et appelle directement
/// l'API Groq (voir core/config/ai_config.dart pour le detail du
/// compromis de securite que ca implique -- l'architecture initiale
/// passait par une Cloud Function pour ne jamais exposer la cle, mais ca
/// necessite le plan payant Firebase Blaze). Ce service implemente a lui
/// seul plusieurs des agents du systeme :
///
///  1. Agent d'ingestion : [archiveScannedDocument] enregistre chaque
///     document scanne/importe dans `users/{uid}/archive`.
///  2. Agent memoire : [_findRelevantArchiveEntries] recherche, par
///     mots-cles, les documents de l'archive pertinents pour une question.
///  3. Agent conseiller : [ask] envoie la question + le resume financier +
///     ce que l'agent memoire a retrouve a l'IA Groq, qui redige la
///     reponse.
///  4. Agent anomalies : [checkForAnomalies] compare une nouvelle depense a
///     l'historique de l'utilisateur (sans IA, juste des comparaisons) et
///     signale les montants inhabituels ou les doublons probables.
///  5. Agent resume mensuel : [maybeGenerateMonthlySummary] redige, via
///     l'IA, un resume du mois precedent des qu'un nouveau mois commence.
///  6. Agent de categorisation : [refineCategoriesWithAI] /
///     [refineSingleCategoryWithAI] ameliorent, via l'IA, la categorie
///     devinee localement par mots-cles pour un reçu ou un relevé scanne.
///
/// [loadHistory]/[appendMessage] gerent la memoire de la CONVERSATION
/// elle-meme (distincte de l'archive documentaire), pour que le chat
/// retrouve ses messages precedents a chaque ouverture. Les agents 4 et 5
/// ecrivent aussi dans ce meme fil de discussion (avec un champ `origin`
/// qui identifie l'agent a l'origine du message), pour que leurs alertes
/// et resumes apparaissent naturellement dans le chat, comme s'ils
/// venaient du conseiller.
class FinancialAdvisorService {
  FinancialAdvisorService({
    required FirebaseDataService dataService,
    http.Client? httpClient,
  }) : _dataService = dataService,
       _httpClient = httpClient ?? http.Client();

  final FirebaseDataService _dataService;
  final http.Client _httpClient;

  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  /// Modeles Groq essayes dans l'ordre, du premier au dernier. Groq retire
  /// regulierement d'anciens modeles (par exemple llama-3.3-70b-versatile,
  /// qui fonctionnait au debut de ce projet et ne fonctionne plus depuis) ;
  /// avoir plusieurs candidats ici evite qu'une seule decommission casse
  /// tout l'agent conseiller. Si un jour AUCUN des deux ne marche, allez
  /// voir la liste a jour sur https://console.groq.com/docs/models et
  /// remplacez les valeurs ci-dessous.
  static const List<String> _groqModelCandidates = <String>[
    'openai/gpt-oss-120b',
    'qwen/qwen3.6-27b',
  ];

  /// Nombre max de caracteres de texte OCR conserves par document archive.
  static const int _maxArchivedTextLength = 6000;

  /// Reglages de l'agent memoire (recherche dans l'archive).
  static const int _maxArchiveDocsToScan = 60;
  static const int _maxArchiveDocsInContext = 5;
  static const int _maxCharsPerArchiveEntry = 500;

  /// Reglages de l'agent anomalies.
  static const int _anomalyMinSamples = 4;
  static const double _anomalyRatioThreshold = 2.2;
  static const int _anomalyDuplicateWindowDays = 2;

  /// Categories valides cote app (voir ExpenseCategory) : l'agent de
  /// categorisation ne doit jamais en inventer d'autres.
  static const List<String> _allowedCategoryKeys = <String>[
    'food',
    'transport',
    'rent',
    'shopping',
    'bills',
    'other',
  ];

  static const Set<String> _stopwords = <String>{
    'le', 'la', 'les', 'de', 'des', 'du', 'un', 'une', 'et', 'en', 'pour',
    'sur', 'dans', 'au', 'aux', 'ce', 'cette', 'mon', 'ma', 'mes', 'the',
    'and', 'for', 'with', 'this', 'that', 'have', 'has', 'how', 'what',
    'much', 'many', 'did', 'was', 'were', 'are', 'combien', 'quel',
    'quelle', 'est', 'ai', 'j', 'je', 'tu', 'il', 'elle',
  };

  Future<CollectionReference<Map<String, dynamic>>>
  _archiveCollection() async {
    return _dataService.archiveCollection();
  }

  Future<CollectionReference<Map<String, dynamic>>> _chatCollection() async {
    return _dataService.advisorChatCollection();
  }

  // --------------------------------------------------------------------
  // Agent d'ingestion
  // --------------------------------------------------------------------

  /// Archive un document scanne/importe. Ne doit JAMAIS faire echouer le
  /// scan lui-meme : une erreur ici (hors-ligne, regles Firestore, etc.)
  /// est simplement avalee, l'utilisateur garde sa depense/ses
  /// transactions normalement.
  Future<void> archiveScannedDocument({
    required String type,
    required String rawText,
    required String sourceLabel,
    Map<String, dynamic>? summary,
  }) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection =
          await _archiveCollection();
      final String trimmedText = rawText.length > _maxArchivedTextLength
          ? rawText.substring(0, _maxArchivedTextLength)
          : rawText;
      await collection.add(<String, dynamic>{
        'type': type,
        'sourceLabel': sourceLabel,
        'rawText': trimmedText,
        'summary': summary ?? <String, dynamic>{},
        'importedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Volontairement silencieux : voir la doc de la methode.
    }
  }

  // --------------------------------------------------------------------
  // Memoire de conversation
  // --------------------------------------------------------------------

  /// Recharge l'historique de conversation deja enregistre (le plus
  /// ancien en premier), pour que le chat reprenne exactement ou
  /// l'utilisateur l'avait laisse.
  Future<List<AdvisorMessage>> loadHistory({int limit = 80}) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection =
          await _chatCollection();
      final QuerySnapshot<Map<String, dynamic>> snapshot = await collection
          .orderBy('timestamp')
          .limitToLast(limit)
          .get();
      return snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                AdvisorMessage.fromMap(doc.data()),
          )
          .toList(growable: false);
    } catch (_) {
      return const <AdvisorMessage>[];
    }
  }

  /// Enregistre un message (utilisateur ou assistant) dans l'historique.
  /// Silencieux en cas d'echec : la conversation continue normalement a
  /// l'ecran meme si elle n'a pas pu etre sauvegardee cette fois-ci.
  Future<void> appendMessage(AdvisorMessage message) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection =
          await _chatCollection();
      await collection.add(<String, dynamic>{
        'role': message.role,
        'content': message.content,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Volontairement silencieux : voir la doc de la methode.
    }
  }

  /// Ecrit un message "proactif" (non demande par l'utilisateur) dans le
  /// meme fil de discussion, avec un `origin` qui identifie l'agent a
  /// l'origine du message (voir agents anomalies et resume mensuel).
  Future<void> _pushAgentMessage(String content, String origin) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection =
          await _chatCollection();
      await collection.add(<String, dynamic>{
        'role': 'assistant',
        'content': content,
        'origin': origin,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Un agent en arriere-plan ne doit jamais faire planter l'app.
    }
  }

  // --------------------------------------------------------------------
  // Agent memoire + agent conseiller
  // --------------------------------------------------------------------

  String _truncate(String? text, int maxLength) {
    if (text == null || text.length <= maxLength) {
      return text ?? '';
    }
    return '${text.substring(0, maxLength).trim()}...';
  }

  /// Normalise un texte pour la comparaison de mots-cles : minuscules,
  /// accents simplifies, ponctuation retiree.
  String _normalize(String? text) {
    String result = (text ?? '').toLowerCase();
    const Map<String, String> accents = <String, String>{
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'ì': 'i',
      'ô': 'o', 'ö': 'o', 'ò': 'o', 'õ': 'o',
      'û': 'u', 'ü': 'u', 'ù': 'u', 'ú': 'u',
      'ç': 'c',
    };
    accents.forEach((String accented, String plain) {
      result = result.replaceAll(accented, plain);
    });
    return result
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// AGENT MEMOIRE : cherche, parmi les documents archives de
  /// l'utilisateur, ceux qui partagent le plus de mots avec la question
  /// posee. Renvoie les meilleurs (ou les plus recents si rien ne
  /// correspond) : mieux vaut un contexte generique que pas de contexte du
  /// tout.
  Future<List<Map<String, dynamic>>> _findRelevantArchiveEntries(
    String question,
  ) async {
    final CollectionReference<Map<String, dynamic>> collection =
        await _archiveCollection();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await collection
        .orderBy('importedAt', descending: true)
        .limit(_maxArchiveDocsToScan)
        .get();

    if (snapshot.docs.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final Set<String> questionWords = _normalize(
      question,
    ).split(' ').where((String w) => w.length >= 3 && !_stopwords.contains(w)).toSet();

    final List<_ScoredArchiveEntry> scored = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final Map<String, dynamic> data = doc.data();
      final String haystack = _normalize(
        '${data['sourceLabel'] ?? ''} ${data['rawText'] ?? ''}',
      );
      int score = 0;
      for (final String word in questionWords) {
        if (haystack.contains(word)) {
          score += 1;
        }
      }
      return _ScoredArchiveEntry(id: doc.id, data: data, score: score);
    }).toList();

    scored.sort(
      (_ScoredArchiveEntry a, _ScoredArchiveEntry b) =>
          b.score.compareTo(a.score),
    );

    final List<_ScoredArchiveEntry> withMatches = scored
        .where((_ScoredArchiveEntry e) => e.score > 0)
        .toList();
    final List<_ScoredArchiveEntry> chosen =
        (withMatches.isNotEmpty ? withMatches : scored)
            .take(_maxArchiveDocsInContext)
            .toList();

    return chosen.map((_ScoredArchiveEntry entry) {
      final Timestamp? importedAt = entry.data['importedAt'] as Timestamp?;
      return <String, dynamic>{
        'id': entry.id,
        'type': entry.data['type'] ?? 'document',
        'sourceLabel': entry.data['sourceLabel'] ?? '',
        'importedAt': importedAt?.toDate().toIso8601String(),
        'excerpt': _truncate(
          entry.data['rawText'] as String?,
          _maxCharsPerArchiveEntry,
        ),
      };
    }).toList(growable: false);
  }

  /// Construit le message systeme envoye a l'IA : son role, les donnees
  /// financieres actuelles de l'utilisateur, et ce que l'agent memoire a
  /// retrouve dans l'archive.
  String _buildSystemPrompt(
    Map<String, dynamic> snapshot,
    List<Map<String, dynamic>> archiveEntries,
  ) {
    String archiveText;
    if (archiveEntries.isEmpty) {
      archiveText = "(Aucun document archive pour l'instant.)";
    } else {
      final List<String> lines = <String>[];
      for (int i = 0; i < archiveEntries.length; i++) {
        final Map<String, dynamic> e = archiveEntries[i];
        final String? importedAt = e['importedAt'] as String?;
        final String date = importedAt != null
            ? DateTime.parse(importedAt).toLocal().toString().split(' ').first
            : 'date inconnue';
        lines.add(
          '${i + 1}. [${e['type']} - ${e['sourceLabel']} - $date]\n${e['excerpt']}',
        );
      }
      archiveText = lines.join('\n\n');
    }

    return '''
Tu es "SmartSave Conseiller", l'agent conseiller financier integre a l'application mobile SmartSave. Tu reponds a l'utilisateur de facon precise, bienveillante et actionnable, en te basant UNIQUEMENT sur les donnees fournies ci-dessous (n'invente jamais de chiffre). Reponds toujours dans la meme langue que la question de l'utilisateur (francais, anglais ou arabe). Sois concis (quelques phrases), donne des chiffres concrets quand c'est pertinent, et termine si possible par un conseil actionnable.

IMPORTANT - Pour toute question portant sur un montant ou une somme (depenses, revenus, solde...), utilise TOUJOURS les chiffres deja calcules dans le JSON ci-dessous (monthlySpending, weeklySpending, todaySpending, totalSpendingAllTime, categorySpending, etc.) — ne recalcule JAMAIS une somme toi-meme a partir du texte des extraits d'archive plus bas, celui-ci sert uniquement de contexte (dates, libelles, type de document), pas de source de calcul, et peut etre incomplet ou dans le desordre.
- monthlySpending / weeklySpending / todaySpending / categorySpending ne concernent QUE le mois, la semaine ou le jour en cours.
- totalSpendingAllTime, totalIncomeAllTime et totalTransactionsAllTime couvrent TOUTES les depenses enregistrees, quelle que soit leur date (utile si l'utilisateur a importe un releve d'un mois passe, ou pose une question generale comme "quelle est la somme de mes depenses" sans preciser de periode).
- Si l'utilisateur ne precise pas de periode, utilise totalSpendingAllTime et precise que c'est le total toutes periodes confondues ; propose-lui de preciser une periode (ce mois-ci, cette semaine...) s'il veut un chiffre plus cible.

=== Resume financier actuel de l'utilisateur (JSON) ===
${jsonEncode(snapshot)}

=== Extraits pertinents de l'historique de documents importes (archive, contexte uniquement) ===
$archiveText
''';
  }

  /// AGENT CONSEILLER (bas niveau) : envoie un prompt systeme + une
  /// question a l'API Groq et renvoie le texte de la reponse. Utilise
  /// aussi bien par [ask] que par [maybeGenerateMonthlySummary] et
  /// [_categorize].
  ///
  /// Essaie chaque modele de [_groqModelCandidates] dans l'ordre : si Groq
  /// repond que le modele n'existe plus (ce qui arrive de temps en temps,
  /// Groq retirant regulierement d'anciens modeles), on passe au suivant
  /// automatiquement plutot que de faire echouer tout l'agent conseiller.
  Future<String> _callGroq({
    required String systemPrompt,
    required String question,
    double temperature = 0.4,
    int maxTokens = 700,
  }) async {
    if (kGroqApiKey.trim().isEmpty ||
        kGroqApiKey == 'COLLEZ_VOTRE_CLE_GROQ_ICI') {
      throw StateError(
        "Aucune cle Groq configuree (voir lib/core/config/ai_config.dart).",
      );
    }

    Object lastError = StateError('Aucun modele Groq disponible.');

    for (final String model in _groqModelCandidates) {
      try {
        return await _callGroqWithModel(
          model: model,
          systemPrompt: systemPrompt,
          question: question,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      } on _GroqModelUnavailable catch (error) {
        // Ce modele precis n'est plus disponible : on essaie le suivant.
        lastError = error;
        continue;
      }
    }

    throw lastError;
  }

  /// Envoie effectivement la requete a Groq pour UN modele donne. Leve
  /// [_GroqModelUnavailable] (au lieu d'une erreur generique) quand la
  /// reponse indique specifiquement que ce modele n'existe plus, pour que
  /// [_callGroq] sache qu'il peut sans risque essayer le modele suivant.
  Future<String> _callGroqWithModel({
    required String model,
    required String systemPrompt,
    required String question,
    required double temperature,
    required int maxTokens,
  }) async {
    final http.Response response = await _httpClient
        .post(
          Uri.parse(_groqEndpoint),
          headers: <String, String>{
            'Authorization': 'Bearer $kGroqApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'model': model,
            'messages': <Map<String, String>>[
              <String, String>{'role': 'system', 'content': systemPrompt},
              <String, String>{'role': 'user', 'content': question},
            ],
            'temperature': temperature,
            'max_tokens': maxTokens,
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 404 &&
        (response.body.contains('model_not_found') ||
            response.body.contains('does not exist'))) {
      throw _GroqModelUnavailable(
        'Le modele "$model" n\'est plus disponible sur Groq : ${response.body}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Groq a repondu avec le statut ${response.statusCode}: ${response.body}',
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final List<dynamic>? choices = json['choices'] as List<dynamic>?;
    final Map<String, dynamic>? firstChoice =
        (choices != null && choices.isNotEmpty)
        ? choices.first as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? messageMap =
        firstChoice?['message'] as Map<String, dynamic>?;
    final String? reply = messageMap?['content'] as String?;

    if (reply == null || reply.trim().isEmpty) {
      throw StateError('Reponse Groq vide ou dans un format inattendu.');
    }

    return reply.trim();
  }

  /// Pose une question a l'agent conseiller financier. Orchestre l'agent
  /// memoire (recherche dans l'archive) puis l'agent conseiller (appel a
  /// l'IA) directement depuis le telephone.
  ///
  /// Leve une exception si l'appel echoue (hors-ligne, cle manquante...) :
  /// c'est volontaire, pour que l'appelant puisse basculer sur une reponse
  /// de secours (voir [FinanceChatbotService] dans
  /// finance_chatbot_service.dart) plutot que de laisser l'utilisateur
  /// sans reponse.
  Future<String> ask({
    required String question,
    required Map<String, dynamic> snapshot,
  }) async {
    final String trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) {
      throw StateError('La question est vide.');
    }

    final List<Map<String, dynamic>> archiveEntries =
        await _findRelevantArchiveEntries(trimmedQuestion);
    final String systemPrompt = _buildSystemPrompt(snapshot, archiveEntries);
    return _callGroq(systemPrompt: systemPrompt, question: trimmedQuestion);
  }

  // --------------------------------------------------------------------
  // Agent anomalies (100% local, sans IA : juste des comparaisons)
  // --------------------------------------------------------------------

  /// Analyse une depense qui vient d'etre ajoutee et, si elle semble
  /// inhabituelle (montant tres superieur a la moyenne habituelle de
  /// l'utilisateur pour cette categorie/ce compte, ou doublon probable
  /// d'une depense recente), envoie une alerte dans le chat du conseiller.
  /// Ne fait jamais echouer l'ajout de la depense : toute erreur ici est
  /// silencieuse.
  Future<void> checkForAnomalies(Expense expense) async {
    if (expense.amount <= 0) {
      return;
    }
    try {
      final CollectionReference<Map<String, dynamic>> collection =
          await _dataService.expensesCollection();
      final QuerySnapshot<Map<String, dynamic>> snapshot = await collection
          .where('categoryKey', isEqualTo: expense.category.key)
          .where('accountId', isEqualTo: expense.accountId)
          .orderBy('date', descending: true)
          .limit(40)
          .get();

      final List<Map<String, dynamic>> comparable = snapshot.docs
          .where(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                doc.id != expense.id,
          )
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data(),
          )
          .toList();

      // --- Heuristique 1 : montant inhabituel pour cette categorie ---
      if (comparable.length >= _anomalyMinSamples) {
        final List<double> amounts = comparable
            .map(
              (Map<String, dynamic> e) =>
                  (e['amount'] as num?)?.toDouble() ?? 0,
            )
            .where((double n) => n > 0)
            .toList();
        if (amounts.isNotEmpty) {
          final double avg =
              amounts.reduce((double a, double b) => a + b) / amounts.length;
          if (avg > 0 && expense.amount >= avg * _anomalyRatioThreshold) {
            await _pushAgentMessage(
              '⚠️ Depense inhabituelle detectee : ${expense.amount.toStringAsFixed(2)} dans la categorie "${expense.category.key}", alors que votre depense habituelle dans cette categorie est plutot autour de ${avg.toStringAsFixed(2)}. Verifiez que ce montant est correct.',
              'anomaly_agent',
            );
            return;
          }
        }
      }

      // --- Heuristique 2 : doublon probable ---
      final bool hasDuplicate = comparable.any((Map<String, dynamic> e) {
        final double amount = (e['amount'] as num?)?.toDouble() ?? -1;
        if (amount != expense.amount) {
          return false;
        }
        final String? otherDateStr = e['date'] as String?;
        if (otherDateStr == null) {
          return false;
        }
        final DateTime? otherDate = DateTime.tryParse(otherDateStr);
        if (otherDate == null) {
          return false;
        }
        final int diffHours = expense.date.difference(otherDate).inHours.abs();
        return (diffHours / 24) <= _anomalyDuplicateWindowDays;
      });

      if (hasDuplicate) {
        await _pushAgentMessage(
          "🔁 Possible doublon : une autre depense de ${expense.amount.toStringAsFixed(2)} dans la meme categorie a ete enregistree a une date tres proche. Verifiez qu'il ne s'agit pas d'une double saisie.",
          'anomaly_agent',
        );
      }
    } catch (_) {
      // Silencieux : voir la doc de la methode.
    }
  }

  // --------------------------------------------------------------------
  // Agent resume mensuel
  // --------------------------------------------------------------------

  /// A appeler une fois au demarrage de l'app (voir main.dart). Verifie si
  /// un nouveau mois a commence depuis le dernier resume genere pour cet
  /// utilisateur ; si oui, calcule les depenses du mois precedent et
  /// redige un resume (via l'IA, avec un repli simple sans IA en cas
  /// d'echec), envoye dans le chat du conseiller. Ne fait jamais planter
  /// l'app : toute erreur est silencieuse.
  ///
  /// NOTE : contrairement a une Cloud Function planifiee (qui tournerait
  /// chaque jour meme app fermee), cette version s'execute au moment ou
  /// l'utilisateur ouvre l'application -- c'est le compromis accepte pour
  /// rester sur une architecture 100% gratuite.
  Future<void> maybeGenerateMonthlySummary() async {
    try {
      final DateTime now = DateTime.now();
      final String currentMonthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final DocumentReference<Map<String, dynamic>> markerRef =
          await _dataService.monthlySummaryDocument();
      final DocumentSnapshot<Map<String, dynamic>> markerSnap =
          await markerRef.get();
      final String? lastMonth = markerSnap.data()?['lastMonth'] as String?;

      if (lastMonth == currentMonthKey) {
        return; // deja traite ce mois-ci
      }

      // On marque tout de suite le mois comme traite, pour ne jamais
      // reessayer en boucle si la suite echoue ou s'il n'y a rien a
      // resumer.
      await markerRef.set(<String, dynamic>{
        'lastMonth': currentMonthKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final DateTime targetDate = DateTime(now.year, now.month - 1, 1);
      final String rangeStart = targetDate.toIso8601String();
      final String rangeEnd = DateTime(
        targetDate.year,
        targetDate.month + 1,
        1,
      ).toIso8601String();

      final CollectionReference<Map<String, dynamic>> expensesCollection =
          await _dataService.expensesCollection();
      final QuerySnapshot<Map<String, dynamic>> expensesSnap =
          await expensesCollection
              .where('date', isGreaterThanOrEqualTo: rangeStart)
              .where('date', isLessThan: rangeEnd)
              .get();

      if (expensesSnap.docs.isEmpty) {
        return; // rien depense ce mois-la
      }

      final List<Map<String, dynamic>> expenseData = expensesSnap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data(),
          )
          .toList();
      final double total = expenseData.fold<double>(
        0,
        (double sum, Map<String, dynamic> e) =>
            sum + ((e['amount'] as num?)?.toDouble() ?? 0),
      );

      final Map<String, double> byCategory = <String, double>{};
      for (final Map<String, dynamic> e in expenseData) {
        final String key = (e['categoryKey'] as String?) ?? 'other';
        final double amount = (e['amount'] as num?)?.toDouble() ?? 0;
        byCategory[key] = (byCategory[key] ?? 0) + amount;
      }
      final List<MapEntry<String, double>> sortedCategories =
          byCategory.entries.toList()
            ..sort(
              (MapEntry<String, double> a, MapEntry<String, double> b) =>
                  b.value.compareTo(a.value),
            );
      final MapEntry<String, double>? topCategory = sortedCategories
          .isNotEmpty
          ? sortedCategories.first
          : null;

      final String monthLabel = _monthLabelFr(targetDate);

      String message;
      try {
        final String systemPrompt =
            'Tu es "SmartSave Conseiller". Redige un court resume mensuel '
            '(3 a 4 phrases maximum) des depenses de l\'utilisateur pour '
            '$monthLabel, en francais, sur un ton chaleureux et '
            "actionnable, a partir de ces donnees JSON (n'invente aucun "
            'autre chiffre) : '
            '${jsonEncode(<String, dynamic>{'total': total, 'byCategory': byCategory, 'transactionCount': expenseData.length, 'topCategory': topCategory?.key})}'
            ". N'ecris jamais que ce sont des donnees JSON : ecris "
            "directement comme si tu parlais a l'utilisateur.";

        message = await _callGroq(
          systemPrompt: systemPrompt,
          question: 'Redige le resume mensuel.',
        );
      } catch (_) {
        final String topLine = topCategory != null
            ? ' Votre plus grosse categorie de depense est "${topCategory.key}" (${topCategory.value.toStringAsFixed(2)}).'
            : '';
        message =
            '📊 Resume de $monthLabel : vous avez depense un total de '
            '${total.toStringAsFixed(2)} sur ${expenseData.length} '
            'transaction(s).$topLine';
      }

      await _pushAgentMessage(message, 'monthly_summary_agent');
    } catch (_) {
      // Silencieux : voir la doc de la methode.
    }
  }

  String _monthLabelFr(DateTime date) {
    const List<String> months = <String>[
      'janvier',
      'fevrier',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'aout',
      'septembre',
      'octobre',
      'novembre',
      'decembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // --------------------------------------------------------------------
  // Agent de categorisation
  // --------------------------------------------------------------------

  /// Nombre max de transactions envoyees en une seule fois a l'agent de
  /// categorisation.
  static const int _maxTransactionsPerBatch = 60;

  /// AGENT CATEGORISATION (relevé bancaire) : ameliore, via l'IA, la
  /// categorie de chaque transaction detectee dans un relevé scanne.
  /// Modifie `transactions` DIRECTEMENT (leur `suggestedCategory` est
  /// modifiable) : les categories devinees localement par mots-cles
  /// restent en place tant que l'IA n'a pas repondu, et le restent aussi
  /// en cas d'echec -- cette methode n'interrompt et ne fait jamais
  /// echouer le scan.
  Future<void> refineCategoriesWithAI(
    List<ScannedTransaction> transactions,
  ) async {
    if (transactions.isEmpty) {
      return;
    }
    final List<ScannedTransaction> batch = transactions
        .take(_maxTransactionsPerBatch)
        .toList(growable: false);
    try {
      final List<String> descriptions = batch
          .map(
            (ScannedTransaction t) =>
                t.description.trim().isNotEmpty ? t.description : t.rawLine,
          )
          .toList(growable: false);
      final List<ExpenseCategory>? categories = await _categorize(
        descriptions,
      );
      if (categories == null || categories.length != batch.length) {
        return;
      }
      for (int i = 0; i < batch.length; i++) {
        batch[i].suggestedCategory = categories[i];
      }
    } catch (_) {
      // Silencieux : les categories devinees localement restent valables.
    }
  }

  /// AGENT CATEGORISATION (reçu unique) : meme principe que
  /// [refineCategoriesWithAI], mais pour un seul reçu scanne. La categorie
  /// d'un [OcrScanResult] n'est pas modifiable en place (champ `final`),
  /// donc cette methode renvoie la categorie choisie par l'IA plutot que
  /// de muter un objet ; renvoie `null` en cas d'echec, l'appelant doit
  /// alors garder [fallback] (la categorie devinee localement).
  Future<ExpenseCategory?> refineSingleCategoryWithAI({
    required String rawText,
    required ExpenseCategory fallback,
  }) async {
    if (rawText.trim().isEmpty) {
      return null;
    }
    try {
      final List<ExpenseCategory>? categories = await _categorize(
        <String>[rawText],
      );
      if (categories == null || categories.isEmpty) {
        return null;
      }
      return categories.first;
    } catch (_) {
      return null;
    }
  }

  /// Appelle directement l'IA Groq (agent de categorisation) avec une
  /// liste de descriptions, et renvoie une categorie [ExpenseCategory]
  /// pour chacune, dans le meme ordre. Renvoie `null` si la reponse est
  /// absente ou mal formee : c'est au code appelant de decider du repli
  /// dans ce cas.
  Future<List<ExpenseCategory>?> _categorize(
    List<String> descriptions,
  ) async {
    if (descriptions.isEmpty) {
      return null;
    }

    final String systemPrompt =
        'Tu categorises des transactions financieres. Pour chaque '
        'description fournie, choisis EXACTEMENT une categorie parmi '
        'cette liste : ${_allowedCategoryKeys.join(', ')}. Reponds '
        'UNIQUEMENT avec un tableau JSON de chaines de caracteres (une '
        'categorie par description, dans le meme ordre, meme longueur '
        'que la liste fournie), sans aucun texte autour, par exemple : '
        '["food","transport","other"]. Si une description est ambigue '
        'ou ne correspond a aucune categorie evidente, choisis "other".';

    final String raw = await _callGroq(
      systemPrompt: systemPrompt,
      question: jsonEncode(descriptions),
      temperature: 0.1,
      maxTokens: 500,
    );

    // L'IA repond parfois avec du texte autour du JSON malgre la
    // consigne ; on extrait le premier tableau JSON trouve.
    final RegExpMatch? match = RegExp(r'\[[\s\S]*\]').firstMatch(raw);
    final dynamic parsed = jsonDecode(match != null ? match.group(0)! : raw);

    if (parsed is! List || parsed.length != descriptions.length) {
      return null;
    }

    return parsed.map((dynamic value) {
      final String key = value.toString().toLowerCase().trim();
      return _allowedCategoryKeys.contains(key)
          ? ExpenseCategoryX.fromKey(key)
          : ExpenseCategory.other;
    }).toList(growable: false);
  }
}

class _ScoredArchiveEntry {
  _ScoredArchiveEntry({
    required this.id,
    required this.data,
    required this.score,
  });

  final String id;
  final Map<String, dynamic> data;
  final int score;
}

/// Levee quand Groq indique qu'un modele precis n'existe plus (code
/// `model_not_found`), pour que [FinancialAdvisorService._callGroq] sache
/// qu'il peut essayer le modele candidat suivant sans faire echouer toute
/// la requete.
class _GroqModelUnavailable implements Exception {
  _GroqModelUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
