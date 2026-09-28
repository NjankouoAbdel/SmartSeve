import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

class OcrService {
  OcrService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<OcrScanResult?> scanReceipt(ImageSource source) async {
    if (kIsWeb) {
      throw const OcrServiceException(
        'Receipt scanner is available on Android and iOS. Web does not support ML OCR here.',
      );
    }

    final bool allowed = await _requestPermission(source);
    if (!allowed) {
      throw const OcrServiceException(
        'Camera/Photos permission is required to scan receipts.',
      );
    }

    final XFile? image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2000,
    );
    if (image == null) {
      return null;
    }

    final InputImage inputImage = InputImage.fromFilePath(image.path);
    final RecognizedText recognized = await _textRecognizer.processImage(
      inputImage,
    );

    final String text = recognized.text;
    if (text.trim().isEmpty) {
      throw const OcrServiceException(
        'No readable text was found. Try a clearer photo.',
      );
    }
    final double? amount = _extractAmount(text);
    final DateTime? date = _extractDate(text);
    final String note = _extractNote(recognized);
    // La categorie n'est jamais demandee a l'utilisateur pour un scan: elle
    // est devinee automatiquement a partir du texte du reçu (mots-cles de
    // marchand), meme logique que pour un relevé bancaire.
    final ExpenseCategory suggestedCategory = _guessCategory(text);

    return OcrScanResult(
      rawText: text,
      amount: amount,
      date: date,
      suggestedNote: note,
      suggestedCategory: suggestedCategory,
    );
  }

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final PermissionStatus status = await Permission.camera.request();
      return status.isGranted;
    }

    final PermissionStatus photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) {
      return true;
    }

    final PermissionStatus storage = await Permission.storage.request();
    return storage.isGranted;
  }

  double? _extractAmount(String text) {
    final RegExp regex = RegExp(r'(\d+[\.,]\d{2})');
    final Iterable<RegExpMatch> matches = regex.allMatches(text);
    double? best;

    for (final RegExpMatch match in matches) {
      final String? group = match.group(0);
      if (group == null) {
        continue;
      }
      final double? value = double.tryParse(group.replaceAll(',', '.'));
      if (value == null) {
        continue;
      }

      if (best == null || value > best) {
        best = value;
      }
    }

    return best;
  }

  DateTime? _extractDate(String text) {
    final RegExp slashDate = RegExp(r'(\d{1,2})[\/-](\d{1,2})[\/-](\d{2,4})');
    final RegExpMatch? match = slashDate.firstMatch(text);
    if (match == null) {
      return null;
    }

    final int? day = int.tryParse(match.group(1) ?? '');
    final int? month = int.tryParse(match.group(2) ?? '');
    int? year = int.tryParse(match.group(3) ?? '');

    if (day == null || month == null || year == null) {
      return null;
    }
    if (year < 100) {
      year += 2000;
    }

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _extractNote(RecognizedText recognizedText) {
    for (final TextBlock block in recognizedText.blocks) {
      for (final TextLine line in block.lines) {
        final String clean = line.text.trim();
        if (clean.length > 3 && !_looksLikeOnlyNumbers(clean)) {
          return clean;
        }
      }
    }

    return 'Scanned receipt';
  }

  bool _looksLikeOnlyNumbers(String value) {
    return RegExp(r'^[\d\s\.,\-/:]+$').hasMatch(value);
  }

  // ===========================================================================
  // SCAN DE RELEVE BANCAIRE - plusieurs transactions en une seule photo
  // ===========================================================================
  //
  // Contrairement a scanReceipt() (qui cherche UN montant sur UN recu), ici on
  // essaie de retrouver PLUSIEURS transactions, une par ligne du relevé.
  // C'est un parsing "au mieux": la reconnaissance de texte ne recree pas
  // parfaitement un tableau, donc une ligne mal alignee ou mal photographiee
  // peut etre ratee ou mal lue. C'est pour ca que l'ecran de revue (cote UI)
  // laisse l'utilisateur corriger/decocher chaque ligne avant l'import.

  // Date: 05/09/2026, 05-09-26, 05.09.2026, etc.
  static final RegExp _dateLineRegex = RegExp(
    r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})',
  );

  // Montant: -45,20 / +1 200,00 / 1.200,00 / 60.00 (espace ou point comme
  // separateur de milliers, virgule ou point comme separateur decimal).
  static final RegExp _amountLineRegex = RegExp(
    r'([+-]?\d{1,3}(?:[ .]\d{3})*(?:[.,]\d{2}))',
  );

  static const List<String> _incomeKeywords = <String>[
    'virement recu',
    'vir recu',
    'salaire',
    'remboursement',
    'remb.',
    'depot',
    'credit ',
    'paie',
    'salary',
    'refund',
    'deposit',
  ];

  static const Map<String, ExpenseCategory> _categoryKeywordHints = <String, ExpenseCategory>{
    'carrefour': ExpenseCategory.food,
    'supermarche': ExpenseCategory.food,
    'super u': ExpenseCategory.food,
    'leclerc': ExpenseCategory.food,
    'monoprix': ExpenseCategory.food,
    'restaurant': ExpenseCategory.food,
    'boulangerie': ExpenseCategory.food,
    'uber': ExpenseCategory.transport,
    'sncf': ExpenseCategory.transport,
    'ratp': ExpenseCategory.transport,
    'essence': ExpenseCategory.transport,
    'station': ExpenseCategory.transport,
    'parking': ExpenseCategory.transport,
    'loyer': ExpenseCategory.rent,
    'edf': ExpenseCategory.bills,
    'engie': ExpenseCategory.bills,
    'orange': ExpenseCategory.bills,
    'sfr': ExpenseCategory.bills,
    'free mobile': ExpenseCategory.bills,
    'bouygues': ExpenseCategory.bills,
    'facture': ExpenseCategory.bills,
    'assurance': ExpenseCategory.bills,
    'amazon': ExpenseCategory.shopping,
    'zara': ExpenseCategory.shopping,
    'fnac': ExpenseCategory.shopping,
  };

  /// Scanne une photo de relevé bancaire et tente d'en extraire toutes les
  /// transactions (une par ligne detectee avec a la fois une date et un
  /// montant). Retourne `null` si l'utilisateur annule la selection d'image.
  Future<BankStatementScanResult?> scanBankStatement(ImageSource source) async {
    if (kIsWeb) {
      throw const OcrServiceException(
        'Bank statement scanning is available on Android and iOS. Web does not support ML OCR here.',
      );
    }

    final bool allowed = await _requestPermission(source);
    if (!allowed) {
      throw const OcrServiceException(
        'Camera/Photos permission is required to scan a statement.',
      );
    }

    final XFile? image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2400,
    );
    if (image == null) {
      return null;
    }

    final InputImage inputImage = InputImage.fromFilePath(image.path);
    final RecognizedText recognized = await _textRecognizer.processImage(
      inputImage,
    );

    final String text = recognized.text;
    if (text.trim().isEmpty) {
      throw const OcrServiceException(
        'No readable text was found. Try a clearer, well-lit photo of the statement.',
      );
    }

    final List<ScannedTransaction> transactions = _parseStatementTransactions(
      recognized,
    );
    if (transactions.isEmpty) {
      throw const OcrServiceException(
        'No transaction lines were recognized. Make sure the photo shows '
        'clear rows with a date and an amount on each line.',
      );
    }

    return BankStatementScanResult(rawText: text, transactions: transactions);
  }

  /// Meme objectif que [scanBankStatement], mais a partir d'un fichier PDF
  /// (par exemple un relevé bancaire telecharge en PDF) plutot qu'une photo.
  ///
  /// Chaque page du PDF est convertie en image (rasterisation), puis chaque
  /// image passe par le meme moteur de reconnaissance de texte (ML Kit) et le
  /// meme parsing ligne-par-ligne que [scanBankStatement]. Les transactions
  /// detectees sur toutes les pages sont fusionnees dans un seul resultat.
  ///
  /// Retourne `null` si l'utilisateur annule la selection du fichier.
  Future<BankStatementScanResult?> scanBankStatementFromPdf() async {
    if (kIsWeb) {
      throw const OcrServiceException(
        'Bank statement scanning is available on Android and iOS. Web does not support ML OCR here.',
      );
    }

    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
      withData: false,
    );
    final String? path = picked?.files.single.path;
    if (path == null) {
      return null; // annule par l'utilisateur
    }

    final File pdfFile = File(path);
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    if (pdfBytes.isEmpty) {
      throw const OcrServiceException(
        'The selected PDF file could not be read.',
      );
    }

    // Garde-fou: un tres long releve (des dizaines de pages) prendrait trop
    // de temps a analyser image par image sur un telephone.
    const int maxPages = 15;

    final Directory tempDir = await getTemporaryDirectory();
    final List<ScannedTransaction> allTransactions = <ScannedTransaction>[];
    // TEMPORAIRE (diagnostic) : garde une trace des rangees reconstruites
    // par l'OCR pour pouvoir les afficher dans le message d'erreur si aucune
    // transaction n'est trouvee. A retirer une fois le parsing confirme
    // fiable sur de vrais relevés.
    final List<String> debugRows = <String>[];
    final StringBuffer combinedText = StringBuffer();
    int pageIndex = 0;

    await for (final PdfRaster page in Printing.raster(
      pdfBytes,
      dpi: 200,
    )) {
      if (pageIndex >= maxPages) {
        break;
      }

      final Uint8List pageImageBytes = await page.toPng();
      final File pageImageFile = File(
        '${tempDir.path}/statement_pdf_page_${DateTime.now().millisecondsSinceEpoch}_$pageIndex.png',
      );
      await pageImageFile.writeAsBytes(pageImageBytes);

      try {
        final InputImage inputImage = InputImage.fromFilePath(
          pageImageFile.path,
        );
        final RecognizedText recognized = await _textRecognizer.processImage(
          inputImage,
        );
        combinedText.writeln(recognized.text);
        allTransactions.addAll(
          _parseStatementTransactions(recognized, debugRows: debugRows),
        );
      } finally {
        // Nettoyage best-effort: peu importe si ca echoue, ce n'est qu'un
        // fichier temporaire.
        unawaited(pageImageFile.delete().catchError((_) => pageImageFile));
      }

      pageIndex++;
    }

    if (allTransactions.isEmpty) {
      // TEMPORAIRE (diagnostic) : on ajoute des details techniques a la fin
      // du message pour comprendre, via une simple capture d'ecran de
      // l'utilisateur, pourquoi l'OCR n'a trouve aucune transaction (plutot
      // que de devoir recuperer les logs Android). A retirer une fois le
      // probleme resolu.
      final String extractedChars = combinedText.length.toString();
      final int rowCount = debugRows.length;
      final String sample = debugRows.isEmpty
          ? '(aucune rangee de texte reconstruite du tout)'
          : debugRows
                .take(8)
                .map(
                  (String r) =>
                      '- ${r.length > 90 ? '${r.substring(0, 90)}...' : r}',
                )
                .join('\n');
      throw OcrServiceException(
        'No transaction lines were recognized in this PDF. Make sure it '
        'contains a text-based statement with clear rows (date and amount '
        'on each line).\n\n'
        '[DEBUG] $extractedChars caracteres de texte lus par l\'OCR, '
        '$rowCount rangee(s) reconstruite(s). Exemples de rangees:\n$sample',
      );
    }

    return BankStatementScanResult(
      rawText: combinedText.toString(),
      transactions: allTransactions,
    );
  }

  /// Reconstruit les "vraies" lignes du tableau d'un relevé bancaire a
  /// partir des fragments de texte detectes par l'OCR.
  ///
  /// POURQUOI CETTE ETAPE EST NECESSAIRE : un relevé bancaire presente
  /// presque toujours ses colonnes (date, libelle, montant, categorie...)
  /// assez espacees horizontalement pour que l'OCR (ML Kit) les traite
  /// comme des lignes de texte SEPAREES plutot que comme une seule ligne de
  /// tableau — chaque colonne devient son propre `TextLine`. Si on cherchait
  /// une date ET un montant sur un seul `TextLine` comme avant, aucune
  /// transaction ne serait jamais detectee sur un vrai relevé en tableau
  /// (uniquement sur un reçu simple ou tout tient sur une ligne).
  ///
  /// On regroupe donc tous les fragments de texte de la page par hauteur
  /// approximative (leur centre vertical sur l'image), pour reconstituer
  /// chaque rangee du tableau, puis on cherche une date et un montant dans
  /// le texte de la rangee entiere (tous les fragments de cette rangee mis
  /// bout a bout, tries de gauche a droite).
  List<ScannedTransaction> _parseStatementTransactions(
    RecognizedText recognized, {
    // TEMPORAIRE (diagnostic) : si fourni, rempli avec le texte de chaque
    // rangee reconstruite (meme celles qui ne matchent pas), pour pouvoir
    // afficher un message d'erreur utile a l'utilisateur en cas d'echec.
    // A retirer une fois le parsing du releve PDF confirme fiable.
    List<String>? debugRows,
  }) {
    final List<ScannedTransaction> results = <ScannedTransaction>[];
    // Cap de securite: une tres longue liste de lignes mal reconnues ne doit
    // pas produire des centaines de fausses transactions a trier.
    const int maxTransactions = 200;

    final List<_TextFragment> fragments = <_TextFragment>[];
    for (final TextBlock block in recognized.blocks) {
      for (final TextLine line in block.lines) {
        final String raw = line.text.trim();
        if (raw.isEmpty) {
          continue;
        }
        fragments.add(_TextFragment(text: raw, box: line.boundingBox));
      }
    }

    if (fragments.isEmpty) {
      return results;
    }

    fragments.sort(
      (_TextFragment a, _TextFragment b) =>
          a.verticalCenter.compareTo(b.verticalCenter),
    );

    // Tolerance relative a la hauteur moyenne du texte detecte, pour que ca
    // s'adapte a n'importe quelle resolution d'image/PDF plutot que de
    // dependre d'une valeur fixe en pixels.
    final double averageHeight =
        fragments.fold<double>(
          0,
          (double sum, _TextFragment f) => sum + f.height,
        ) /
        fragments.length;
    final double rowTolerance = (averageHeight * 0.6).clamp(4, 40);

    final List<List<_TextFragment>> rows = <List<_TextFragment>>[];
    for (final _TextFragment fragment in fragments) {
      final List<_TextFragment>? currentRow = rows.isEmpty ? null : rows.last;
      if (currentRow != null &&
          (fragment.verticalCenter - currentRow.last.verticalCenter).abs() <=
              rowTolerance) {
        currentRow.add(fragment);
      } else {
        rows.add(<_TextFragment>[fragment]);
      }
    }

    for (final List<_TextFragment> row in rows) {
      if (results.length >= maxTransactions) {
        break;
      }

      row.sort(
        (_TextFragment a, _TextFragment b) =>
            a.box.left.compareTo(b.box.left),
      );
      final String raw = row.map((_TextFragment f) => f.text).join('   ');
      debugRows?.add(raw);

      final RegExpMatch? dateMatch = _dateLineRegex.firstMatch(raw);
      final DateTime? date = _extractLineDate(raw);
      final RegExpMatch? amountMatch = _amountLineRegex.firstMatch(raw);
      if (date == null || dateMatch == null || amountMatch == null) {
        continue; // pas assez d'info pour etre sur d'une transaction
      }

      final double? parsedAmount = _parseAmountToken(amountMatch.group(0)!);
      if (parsedAmount == null) {
        continue;
      }

      final String token = amountMatch.group(0)!;
      final bool explicitDebit = token.trim().startsWith('-');
      final bool explicitCredit = token.trim().startsWith('+');
      final bool incomeLike = _looksLikeIncome(raw);

      // Convention de l'app: positif = depense, negatif = revenu (voir le
      // commentaire sur ScannedTransaction). Le relevé, lui, montre les
      // depenses en negatif -> on inverse le signe ici.
      final double appAmount = explicitDebit
          ? parsedAmount.abs()
          : explicitCredit
          ? -parsedAmount.abs()
          : (incomeLike ? -parsedAmount.abs() : parsedAmount.abs());

      // La description est le texte entre la date et le montant (par
      // exemple la colonne "Libelle" d'un tableau) quand la rangee est
      // ordonnee normalement (date, puis libelle, puis montant) ; sinon on
      // retombe sur l'ancienne methode (retirer juste la date et le
      // montant du texte complet).
      String description;
      if (dateMatch.end <= amountMatch.start) {
        description = raw.substring(dateMatch.end, amountMatch.start);
      } else {
        description = raw.replaceAll(token, ' ').replaceAll(_dateLineRegex, ' ');
      }
      description = description.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (description.length < 2) {
        description = 'Transaction';
      }

      results.add(
        ScannedTransaction(
          rawLine: raw,
          amount: appAmount,
          date: date,
          description: description,
          suggestedCategory: _guessCategory(description),
        ),
      );
    }

    return results;
  }

  DateTime? _extractLineDate(String line) {
    final RegExpMatch? match = _dateLineRegex.firstMatch(line);
    if (match == null) {
      return null;
    }
    final int? day = int.tryParse(match.group(1) ?? '');
    final int? month = int.tryParse(match.group(2) ?? '');
    int? year = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || year == null) {
      return null;
    }
    if (year < 100) {
      year += 2000;
    }
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  double? _parseAmountToken(String token) {
    String normalized = token.trim().replaceAll(' ', '');
    normalized = normalized.replaceAll(RegExp(r'^[+-]'), '');
    if (normalized.contains(',')) {
      // Format europeen: point = milliers, virgule = decimales.
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  bool _looksLikeIncome(String line) {
    final String lower = line.toLowerCase();
    return _incomeKeywords.any((String k) => lower.contains(k));
  }

  ExpenseCategory _guessCategory(String description) {
    final String lower = description.toLowerCase();
    for (final MapEntry<String, ExpenseCategory> entry
        in _categoryKeywordHints.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return ExpenseCategory.other;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class OcrServiceException implements Exception {
  const OcrServiceException(this.message);

  final String message;
}

/// Un fragment de texte reconnu par l'OCR (une "TextLine" de ML Kit),
/// avec sa position dans l'image (`box`). Sert a reconstruire les lignes
/// d'un tableau (relevé bancaire) en regroupant les fragments qui sont
/// a la meme hauteur, meme si l'OCR les a lus comme des blocs separes
/// (colonnes eloignees les unes des autres).
class _TextFragment {
  _TextFragment({required this.text, required this.box});

  final String text;
  final Rect box;

  double get verticalCenter => (box.top + box.bottom) / 2;
  double get height => box.bottom - box.top;
}

