import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseDataService {
  FirebaseDataService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void>? _anonymousSignInFuture;

  FirebaseAuth get auth => _auth;

  User? get currentUser => _auth.currentUser;

  bool get hasAuthenticatedUser => _auth.currentUser != null;

  bool get isAnonymousUser => _auth.currentUser?.isAnonymous ?? false;

  Future<void> ensureSignedIn() {
    if (_auth.currentUser != null) {
      return Future<void>.value();
    }

    return _anonymousSignInFuture ??= _auth
        .signInAnonymously()
        .then((_) {})
        .catchError((Object error) {
          if (error is FirebaseAuthException) {
            throw StateError(_friendlyAuthError(error));
          }
          throw error;
        })
        .whenComplete(() => _anonymousSignInFuture = null);
  }

  DocumentReference<Map<String, dynamic>> _currentUserRoot() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated Firebase user.');
    }
    return _firestore.collection('users').doc(user.uid);
  }

  Future<CollectionReference<Map<String, dynamic>>> expensesCollection() async {
    await ensureSignedIn();
    return _currentUserRoot().collection('expenses');
  }

  Future<DocumentReference<Map<String, dynamic>>> settingsDocument() async {
    await ensureSignedIn();
    return _currentUserRoot().collection('meta').doc('settings');
  }

  Future<DocumentReference<Map<String, dynamic>>> toolsDocument() async {
    await ensureSignedIn();
    return _currentUserRoot().collection('meta').doc('tools');
  }

  Future<DocumentReference<Map<String, dynamic>>> usageDocument() async {
    await ensureSignedIn();
    return _currentUserRoot().collection('meta').doc('usage');
  }

  Future<DocumentReference<Map<String, dynamic>>> subscriptionDocument() async {
    await ensureSignedIn();
    return _currentUserRoot().collection('meta').doc('subscription');
  }

  /// Marqueur utilise par l'agent de resume mensuel (voir
  /// FinancialAdvisorService.maybeGenerateMonthlySummary) pour se souvenir
  /// du dernier mois deja resume, et ne jamais generer le meme resume deux
  /// fois.
  Future<DocumentReference<Map<String, dynamic>>>
  monthlySummaryDocument() async {
    await ensureSignedIn();
    return _currentUserRoot().collection('meta').doc('monthly_summary');
  }

  /// Archive permanente de chaque document scanne/importe (reçu, relevé
  /// photo ou PDF) : texte brut OCR + resume, conservee independamment des
  /// depenses qui en decoulent. C'est la "memoire documentaire" que
  /// l'agent conseiller financier (voir FinancialAdvisorService) consulte
  /// pour repondre a des questions portant sur l'historique (ex: "combien
  /// avais-je paye chez tel commercant en mars ?").
  Future<CollectionReference<Map<String, dynamic>>> archiveCollection() async {
    await ensureSignedIn();
    return _currentUserRoot().collection('archive');
  }

  /// Historique de conversation avec l'agent conseiller financier : c'est
  /// la "memoire" de la discussion elle-meme (distincte de la memoire
  /// documentaire ci-dessus), pour que le chat retrouve ses messages
  /// precedents meme apres avoir quitte puis rouvert l'ecran ou l'appli.
  Future<CollectionReference<Map<String, dynamic>>>
  advisorChatCollection() async {
    await ensureSignedIn();
    return _currentUserRoot().collection('advisor_chat');
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'Firebase anonymous auth is disabled. Enable it in Firebase Console > Authentication > Sign-in method.';
      case 'network-request-failed':
        return 'Network error while connecting to Firebase Auth.';
      case 'invalid-api-key':
        return 'Invalid Firebase API key in web/app configuration.';
      case 'app-not-authorized':
      case 'unauthorized-domain':
        return 'This app/domain is not authorized in Firebase Authentication settings.';
      default:
        return error.message ?? 'Firebase authentication failed.';
    }
  }
}
