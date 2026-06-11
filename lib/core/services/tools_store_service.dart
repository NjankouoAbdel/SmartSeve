import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_data_service.dart';
import 'package:wfer_flousk_firebase/domain/entities/budget_goal.dart';
import 'package:wfer_flousk_firebase/domain/entities/recurring_expense_plan.dart';
import 'package:wfer_flousk_firebase/domain/entities/tool_notice.dart';

class ToolsStoreService {
  ToolsStoreService({required FirebaseDataService firebaseDataService})
    : _firebaseDataService = firebaseDataService;

  final FirebaseDataService _firebaseDataService;
  final List<BudgetGoal> _budgets = <BudgetGoal>[];
  final List<RecurringExpensePlan> _recurringPlans = <RecurringExpensePlan>[];
  final List<ToolNotice> _notices = <ToolNotice>[];

  bool _biometricEnabled = false;
  bool _pinEnabled = false;
  String _pinCode = '';
  String _smartSaving80Month = '';
  String _smartSaving100Month = '';

  Future<void> initialize() async {
    try {
      final Map<String, dynamic> data = await _readToolsData();
      final List<dynamic> budgetsRaw =
          data['budgets'] as List<dynamic>? ?? const <dynamic>[];
      final List<dynamic> recurringRaw =
          data['recurring'] as List<dynamic>? ?? const <dynamic>[];
      final List<dynamic> noticesRaw =
          data['notices'] as List<dynamic>? ?? const <dynamic>[];
      final Map<String, dynamic> settingsRaw = _mapFromAny(data['settings']);

      _budgets
        ..clear()
        ..addAll(
          budgetsRaw
              .whereType<Map>()
              .map((Map raw) => BudgetGoal.fromMap(_stringDynamicMap(raw)))
              .toList(growable: false),
        );
      _recurringPlans
        ..clear()
        ..addAll(
          recurringRaw
              .whereType<Map>()
              .map(
                (Map raw) =>
                    RecurringExpensePlan.fromMap(_stringDynamicMap(raw)),
              )
              .toList(growable: false),
        );
      _notices
        ..clear()
        ..addAll(
          noticesRaw
              .whereType<Map>()
              .map((Map raw) => ToolNotice.fromMap(_stringDynamicMap(raw)))
              .toList(growable: false),
        )
        ..sort(
          (ToolNotice a, ToolNotice b) => b.createdAt.compareTo(a.createdAt),
        );

      _biometricEnabled = settingsRaw['biometric_enabled'] as bool? ?? false;
      _pinEnabled = settingsRaw['pin_enabled'] as bool? ?? false;
      _pinCode = settingsRaw['pin_code'] as String? ?? '';
      _smartSaving80Month =
          settingsRaw['smart_saving_80_month'] as String? ?? '';
      _smartSaving100Month =
          settingsRaw['smart_saving_100_month'] as String? ?? '';
    } catch (_) {
      // Keep cached defaults when cloud tools state is unavailable.
    }
  }

  List<BudgetGoal> loadBudgets() => List<BudgetGoal>.unmodifiable(_budgets);

  Future<void> saveBudgets(List<BudgetGoal> goals) async {
    _budgets
      ..clear()
      ..addAll(goals);
    await _updateDocument(<String, dynamic>{
      'budgets': goals.map((BudgetGoal goal) => goal.toMap()).toList(),
    });
  }

  List<RecurringExpensePlan> loadRecurringPlans() =>
      List<RecurringExpensePlan>.unmodifiable(_recurringPlans);

  Future<void> saveRecurringPlans(List<RecurringExpensePlan> plans) async {
    _recurringPlans
      ..clear()
      ..addAll(plans);
    await _updateDocument(<String, dynamic>{
      'recurring': plans
          .map((RecurringExpensePlan plan) => plan.toMap())
          .toList(),
    });
  }

  List<ToolNotice> loadNotices() {
    final List<ToolNotice> sortedNotices = List<ToolNotice>.from(_notices)
      ..sort((ToolNotice a, ToolNotice b) => b.createdAt.compareTo(a.createdAt));
    return List<ToolNotice>.unmodifiable(sortedNotices);
  }

  Future<void> saveNotices(List<ToolNotice> notices) async {
    _notices
      ..clear()
      ..addAll(notices)
      ..sort((ToolNotice a, ToolNotice b) => b.createdAt.compareTo(a.createdAt));
    await _updateDocument(<String, dynamic>{
      'notices': notices.map((ToolNotice notice) => notice.toMap()).toList(),
    });
  }

  bool get biometricEnabled => _biometricEnabled;

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    await _saveToolSettings(<String, dynamic>{'biometric_enabled': value});
  }

  bool get pinEnabled => _pinEnabled;

  Future<void> setPinEnabled(bool value) async {
    _pinEnabled = value;
    await _saveToolSettings(<String, dynamic>{'pin_enabled': value});
  }

  String get pinCode => _pinCode;

  Future<void> setPinCode(String value) async {
    _pinCode = value;
    await _saveToolSettings(<String, dynamic>{'pin_code': value});
  }

  String get smartSaving80Month => _smartSaving80Month;

  Future<void> setSmartSaving80Month(String value) async {
    _smartSaving80Month = value;
    await _saveToolSettings(<String, dynamic>{'smart_saving_80_month': value});
  }

  String get smartSaving100Month => _smartSaving100Month;

  Future<void> setSmartSaving100Month(String value) async {
    _smartSaving100Month = value;
    await _saveToolSettings(<String, dynamic>{'smart_saving_100_month': value});
  }

  Future<Map<String, dynamic>> _readToolsData() async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firebaseDataService.toolsDocument();
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
    return snapshot.data() ?? <String, dynamic>{};
  }

  Future<void> _updateDocument(Map<String, dynamic> value) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firebaseDataService.toolsDocument();
    await docRef.set(value, SetOptions(merge: true));
  }

  Future<void> _saveToolSettings(Map<String, dynamic> values) async {
    final Map<String, dynamic> mergedSettings = <String, dynamic>{
      'biometric_enabled': _biometricEnabled,
      'pin_enabled': _pinEnabled,
      'pin_code': _pinCode,
      'smart_saving_80_month': _smartSaving80Month,
      'smart_saving_100_month': _smartSaving100Month,
      ...values,
    };

    await _updateDocument(<String, dynamic>{'settings': mergedSettings});
  }

  Map<String, dynamic> _mapFromAny(dynamic value) {
    if (value is! Map) {
      return <String, dynamic>{};
    }

    return <String, dynamic>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries)
        '${entry.key}': entry.value,
    };
  }

  Map<String, dynamic> _stringDynamicMap(Map<dynamic, dynamic> value) {
    return <String, dynamic>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries)
        '${entry.key}': entry.value,
    };
  }
}

