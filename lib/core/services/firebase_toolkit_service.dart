import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_data_service.dart';
import 'package:wfer_flousk_firebase/data/models/expense_model.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

class UsageOverview {
  const UsageOverview({
    required this.used,
    required this.limit,
    required this.isPro,
    required this.remaining,
  });

  final int used;
  final int limit;
  final bool isPro;
  final int remaining;
}

class UsageConsumeResult {
  const UsageConsumeResult({
    required this.allowed,
    required this.overview,
    this.message,
  });

  final bool allowed;
  final UsageOverview overview;
  final String? message;
}

class FirebaseToolkitService {
  FirebaseToolkitService({FirebaseDataService? dataService})
    : _dataService = dataService ?? FirebaseDataService();

  final FirebaseDataService _dataService;

  static const int _freeMonthlyLimit = 180;

  bool _initialized = false;
  bool _crashReportingEnabled = false;
  String? _initError;

  bool get isAvailable => _initError == null;
  String? get initError => _initError;
  String? get currentUserEmail => _dataService.currentUser?.email;
  bool get isLoggedIn => !(_dataService.currentUser?.isAnonymous ?? true);
  bool get isCrashReportingEnabled => _crashReportingEnabled;
  int get freeMonthlyUsageLimit => _freeMonthlyLimit;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      await _dataService.ensureSignedIn();

      if (!kIsWeb) {
        final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
        await crashlytics.setCrashlyticsCollectionEnabled(true);
        if (_dataService.currentUser != null) {
          await crashlytics.setUserIdentifier(_dataService.currentUser!.uid);
        }
        _crashReportingEnabled = true;
      }
    } catch (error) {
      _initError = error.toString();
      _crashReportingEnabled = false;
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _dataService.ensureSignedIn();
      final User? current = _dataService.currentUser;
      if (current != null && current.isAnonymous) {
        final AuthCredential credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await current.linkWithCredential(credential);
      } else {
        await _dataService.auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      await _afterAuthChange();
      return null;
    } on FirebaseAuthException catch (error) {
      return _authErrorMessage(error);
    } catch (error) {
      return 'Signup failed: $error';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _dataService.ensureSignedIn();
      final User? current = _dataService.currentUser;
      final String? anonymousUid = (current != null && current.isAnonymous)
          ? current.uid
          : null;

      final _UserBundle? anonymousData = anonymousUid == null
          ? null
          : await _readUserBundle(anonymousUid);

      await _dataService.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (anonymousData != null) {
        await _mergeBundleIntoCurrentUser(anonymousData);
      }

      await _afterAuthChange();
      return null;
    } on FirebaseAuthException catch (error) {
      return _authErrorMessage(error);
    } catch (error) {
      return 'Login failed: $error';
    }
  }

  Future<void> signOut() async {
    await _dataService.auth.signOut();
    await _dataService.ensureSignedIn();
    await _afterAuthChange();
  }

  Future<String?> uploadExpenses(List<Expense> expenses) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection =
          await _dataService.expensesCollection();
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      for (final Expense expense in expenses) {
        final ExpenseModel model = ExpenseModel.fromEntity(expense);
        batch.set(
          collection.doc(expense.id),
          <String, dynamic>{...model.toMap(), 'id': expense.id},
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      return null;
    } catch (error) {
      return 'Cloud upload failed: $error';
    }
  }

  Future<void> setSubscriptionStatus({required bool isPro}) async {
    final DocumentReference<Map<String, dynamic>> subscriptionDoc =
        await _dataService.subscriptionDocument();
    await subscriptionDoc.set(<String, dynamic>{
      'isPro': isPro,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UsageOverview> getUsageOverview({required bool isProLocal}) async {
    final bool isProRemote = await _isProFromCloud();
    final bool isPro = isProLocal || isProRemote;
    final _UsageState usage = await _getOrCreateUsageState();
    final int remaining = isPro ? _freeMonthlyLimit : max(0, usage.limit - usage.used);

    return UsageOverview(
      used: usage.used,
      limit: usage.limit,
      isPro: isPro,
      remaining: remaining,
    );
  }

  Future<UsageConsumeResult> tryConsumeUsage({
    required int amount,
    required bool isProLocal,
  }) async {
    if (amount <= 0) {
      final UsageOverview overview = await getUsageOverview(
        isProLocal: isProLocal,
      );
      return UsageConsumeResult(allowed: true, overview: overview);
    }

    final bool isProRemote = await _isProFromCloud();
    final bool isPro = isProLocal || isProRemote;
    if (isPro) {
      final _UsageState usage = await _getOrCreateUsageState();
      return UsageConsumeResult(
        allowed: true,
        overview: UsageOverview(
          used: usage.used,
          limit: usage.limit,
          isPro: true,
          remaining: usage.limit,
        ),
      );
    }

    final DocumentReference<Map<String, dynamic>> usageDoc =
        await _dataService.usageDocument();
    final String month = _monthKey(DateTime.now());
    final int limit = _freeMonthlyLimit;

    final UsageConsumeResult result = await FirebaseFirestore.instance
        .runTransaction((Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(usageDoc);
          final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

          final String storedMonth = data['month'] as String? ?? month;
          final int used = (data['used'] as num?)?.toInt() ?? 0;
          final int effectiveUsed = storedMonth == month ? used : 0;
          final int updatedUsed = effectiveUsed + amount;

          if (updatedUsed > limit) {
            return UsageConsumeResult(
              allowed: false,
              message:
                  'Free monthly usage limit reached ($_freeMonthlyLimit). Upgrade to Pro.',
              overview: UsageOverview(
                used: effectiveUsed,
                limit: limit,
                isPro: false,
                remaining: max(0, limit - effectiveUsed),
              ),
            );
          }

          transaction.set(usageDoc, <String, dynamic>{
            'month': month,
            'used': updatedUsed,
            'limit': limit,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return UsageConsumeResult(
            allowed: true,
            overview: UsageOverview(
              used: updatedUsed,
              limit: limit,
              isPro: false,
              remaining: max(0, limit - updatedUsed),
            ),
          );
        });

    return result;
  }

  Future<(List<Expense>, String?)> downloadExpenses() async {
    try {
      final CollectionReference<Map<String, dynamic>> collection =
          await _dataService.expensesCollection();
      final QuerySnapshot<Map<String, dynamic>> snapshot = await collection.get();

      final List<Expense> expenses = <Expense>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        try {
          final Map<String, dynamic> map = <String, dynamic>{
            ...doc.data(),
            if (!doc.data().containsKey('id')) 'id': doc.id,
          };
          expenses.add(ExpenseModel.fromMap(map).toEntity());
        } catch (_) {
          // Skip malformed cloud document.
        }
      }

      expenses.sort((Expense a, Expense b) => b.date.compareTo(a.date));
      return (expenses, null);
    } catch (error) {
      return (<Expense>[], 'Cloud download failed: $error');
    }
  }

  Future<void> crashTest() async {
    if (!_initialized || !_crashReportingEnabled || kIsWeb) {
      return;
    }
    try {
      throw StateError('Crash test from SMART SAVE tools center.');
    } catch (error, stackTrace) {
      await recordNonFatal(error, stackTrace);
    }
  }

  Future<void> recordNonFatal(Object error, StackTrace stackTrace) async {
    if (!_crashReportingEnabled || kIsWeb) {
      return;
    }
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: false,
    );
  }

  Future<_UsageState> _getOrCreateUsageState() async {
    final DocumentReference<Map<String, dynamic>> usageDoc =
        await _dataService.usageDocument();
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await usageDoc.get();
    final String month = _monthKey(DateTime.now());

    if (!snapshot.exists) {
      final _UsageState fresh = _UsageState(
        month: month,
        used: 0,
        limit: _freeMonthlyLimit,
      );
      await usageDoc.set(<String, dynamic>{
        'month': fresh.month,
        'used': fresh.used,
        'limit': fresh.limit,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return fresh;
    }

    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    final String storedMonth = data['month'] as String? ?? month;
    final int storedUsed = (data['used'] as num?)?.toInt() ?? 0;
    final int storedLimit = (data['limit'] as num?)?.toInt() ?? _freeMonthlyLimit;

    if (storedMonth != month) {
      await usageDoc.set(<String, dynamic>{
        'month': month,
        'used': 0,
        'limit': _freeMonthlyLimit,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return _UsageState(month: month, used: 0, limit: _freeMonthlyLimit);
    }

    return _UsageState(
      month: storedMonth,
      used: storedUsed,
      limit: storedLimit,
    );
  }

  Future<bool> _isProFromCloud() async {
    final DocumentReference<Map<String, dynamic>> subscriptionDoc =
        await _dataService.subscriptionDocument();
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await subscriptionDoc.get();
    final Map<String, dynamic>? data = snapshot.data();
    return data?['isPro'] as bool? ?? false;
  }

  Future<void> _afterAuthChange() async {
    if (_crashReportingEnabled && !kIsWeb) {
      final User? user = _dataService.currentUser;
      if (user != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
      }
    }
  }

  Future<_UserBundle?> _readUserBundle(String uid) async {
    final DocumentReference<Map<String, dynamic>> userRoot = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid);

    final DocumentSnapshot<Map<String, dynamic>> settings =
        await userRoot.collection('meta').doc('settings').get();
    final DocumentSnapshot<Map<String, dynamic>> tools =
        await userRoot.collection('meta').doc('tools').get();
    final QuerySnapshot<Map<String, dynamic>> expenses =
        await userRoot.collection('expenses').get();

    if (!settings.exists && !tools.exists && expenses.docs.isEmpty) {
      return null;
    }

    final List<Map<String, dynamic>> serializedExpenses = expenses.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data();
          return <String, dynamic>{...data, if (!data.containsKey('id')) 'id': doc.id};
        })
        .toList(growable: false);

    return _UserBundle(
      settings: settings.data(),
      tools: tools.data(),
      expenses: serializedExpenses,
    );
  }

  Future<void> _mergeBundleIntoCurrentUser(_UserBundle bundle) async {
    if (bundle.isEmpty) {
      return;
    }

    await _dataService.ensureSignedIn();
    final User? user = _dataService.currentUser;
    if (user == null) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> userRoot = FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid);

    if (bundle.settings != null && bundle.settings!.isNotEmpty) {
      await userRoot.collection('meta').doc('settings').set(
        bundle.settings!,
        SetOptions(merge: true),
      );
    }

    if (bundle.tools != null && bundle.tools!.isNotEmpty) {
      await userRoot.collection('meta').doc('tools').set(
        bundle.tools!,
        SetOptions(merge: true),
      );
    }

    if (bundle.expenses.isNotEmpty) {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final CollectionReference<Map<String, dynamic>> expensesRef = userRoot
          .collection('expenses');

      for (final Map<String, dynamic> expenseMap in bundle.expenses) {
        final String id = (expenseMap['id'] as String?)?.trim().isNotEmpty == true
            ? expenseMap['id'] as String
            : '';
        if (id.isEmpty) {
          continue;
        }
        batch.set(expensesRef.doc(id), expenseMap, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  String _monthKey(DateTime date) {
    final String month = date.month < 10 ? '0${date.month}' : '${date.month}';
    return '${date.year}-$month';
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 chars).';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }
}

class _UsageState {
  const _UsageState({
    required this.month,
    required this.used,
    required this.limit,
  });

  final String month;
  final int used;
  final int limit;
}

class _UserBundle {
  const _UserBundle({
    required this.settings,
    required this.tools,
    required this.expenses,
  });

  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? tools;
  final List<Map<String, dynamic>> expenses;

  bool get isEmpty {
    return (settings == null || settings!.isEmpty) &&
        (tools == null || tools!.isEmpty) &&
        expenses.isEmpty;
  }
}

