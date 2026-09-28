import 'package:cloud_firestore/cloud_firestore.dart';

/// Un message de la conversation avec l'agent conseiller financier IA.
///
/// Contrairement aux messages du chatbot a mots-cles (qui ne vivaient que
/// le temps que l'ecran reste ouvert), ceux-ci sont enregistres dans
/// Firestore (voir [FirebaseDataService.advisorChatCollection]) afin que la
/// conversation soit retrouvee telle quelle a la prochaine ouverture de
/// l'ecran : c'est la "memoire" de la discussion elle-meme.
class AdvisorMessage {
  const AdvisorMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  /// 'user' (l'utilisateur) ou 'assistant' (l'agent conseiller).
  final String role;
  final String content;
  final DateTime timestamp;

  bool get isUser => role == 'user';

  factory AdvisorMessage.fromMap(Map<String, dynamic> map) {
    final Object? rawTimestamp = map['timestamp'];
    DateTime timestamp;
    if (rawTimestamp is Timestamp) {
      timestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      timestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      timestamp = DateTime.now();
    }

    return AdvisorMessage(
      role: map['role'] as String? ?? 'assistant',
      content: map['content'] as String? ?? '',
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'role': role,
      'content': content,
      // Le serveur (FieldValue.serverTimestamp) remplace cette valeur
      // locale au moment de l'ecriture ; on la garde ici seulement pour
      // pouvoir reconstruire un AdvisorMessage sans repasser par Firestore
      // (ex: juste apres l'avoir cree, avant confirmation d'ecriture).
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
