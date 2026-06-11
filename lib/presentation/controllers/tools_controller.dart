import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';
import 'package:wfer_flousk_firebase/core/services/csv_service.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_toolkit_service.dart';
import 'package:wfer_flousk_firebase/core/services/local_notification_service.dart';
import 'package:wfer_flousk_firebase/core/services/ocr_service.dart';
import 'package:wfer_flousk_firebase/core/services/security_service.dart';
import 'package:wfer_flousk_firebase/core/services/tools_store_service.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';
import 'package:wfer_flousk_firebase/domain/entities/budget_goal.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/domain/entities/recurring_expense_plan.dart';
import 'package:wfer_flousk_firebase/domain/entities/tool_notice.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';

class ToolsController extends ChangeNotifier {
  ToolsController({
    required ToolsStoreService storeService,
    required LocalNotificationService localNotificationService,
    required FirebaseToolkitService firebaseToolkitService,
    required CsvService csvService,
    required OcrService ocrService,
    required SecurityService securityService,
    Uuid? uuid,
  }) : _storeService = storeService,
       _localNotificationService = localNotificationService,
       _firebaseToolkitService = firebaseToolkitService,
       _csvService = csvService,
       _ocrService = ocrService,
       _securityService = securityService,
       _uuid = uuid ?? const Uuid();

  final ToolsStoreService _storeService;
  final LocalNotificationService _localNotificationService;
  final FirebaseToolkitService _firebaseToolkitService;
  final CsvService _csvService;
  final OcrService _ocrService;
  final SecurityService _securityService;
  final Uuid _uuid;

  static const double _budgetAlert80 = 0.8;
  static const double _budgetAlert100 = 1.0;

  final List<BudgetGoal> _budgets = <BudgetGoal>[];
  final List<RecurringExpensePlan> _recurringPlans = <RecurringExpensePlan>[];
  final List<ToolNotice> _notices = <ToolNotice>[];

  bool _isLoading = false;
  bool _authBusy = false;
  bool _biometricEnabled = false;
  bool _pinEnabled = false;
  String _pinCode = '';
  bool _biometricSupported = false;
  bool _locked = false;

  String? _lastCloudError;
  OcrScanResult? _lastOcrResult;
  String? _lastOcrError;
  UsageOverview _usageOverview = const UsageOverview(
    used: 0,
    limit: 180,
    isPro: false,
    remaining: 180,
  );

  String _localeCode = 'en';

  bool get isLoading => _isLoading;
  bool get authBusy => _authBusy;
  bool get biometricEnabled => _biometricEnabled;
  bool get pinEnabled => _pinEnabled;
  bool get biometricSupported => _biometricSupported;
  bool get isLocked => _locked;
  String get pinCode => _pinCode;

  bool get cloudAvailable => _firebaseToolkitService.isAvailable;
  String? get cloudInitError => _firebaseToolkitService.initError;
  String? get userEmail => _firebaseToolkitService.currentUserEmail;
  bool get crashMonitoringEnabled =>
      _firebaseToolkitService.isCrashReportingEnabled;

  String? get lastCloudError => _lastCloudError;
  OcrScanResult? get lastOcrResult => _lastOcrResult;
  String? get lastOcrError => _lastOcrError;
  UsageOverview get usageOverview => _usageOverview;

  List<BudgetGoal> get budgets => List<BudgetGoal>.unmodifiable(_budgets);
  List<RecurringExpensePlan> get recurringPlans =>
      List<RecurringExpensePlan>.unmodifiable(_recurringPlans);
  List<ToolNotice> get notices => List<ToolNotice>.unmodifiable(_notices);

  int get unreadNoticeCount =>
      _notices.where((ToolNotice notice) => !notice.isRead).length;

  void setLocaleCode(String localeCode) {
    _localeCode = AppLocalizations.normalizeLanguageCode(localeCode);
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _budgets
        ..clear()
        ..addAll(_storeService.loadBudgets());
      _recurringPlans
        ..clear()
        ..addAll(_storeService.loadRecurringPlans());
      _notices
        ..clear()
        ..addAll(_storeService.loadNotices());

      _biometricEnabled = _storeService.biometricEnabled;
      _pinEnabled = _storeService.pinEnabled;
      _pinCode = _storeService.pinCode;

      _locked = _biometricEnabled || _pinEnabled;

      await _localNotificationService.initialize();
      _biometricSupported = await _securityService.canUseBiometrics();

      await _firebaseToolkitService.initialize();
      if (_firebaseToolkitService.isAvailable) {
        _usageOverview = await _firebaseToolkitService.getUsageOverview(
          isProLocal: false,
        );
      }
    } catch (error) {
      _lastCloudError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> runCrashTest() async {
    await _firebaseToolkitService.crashTest();
    await _pushNotice(
      title: _t('Crash Test Sent', fr: 'Test crash envoye'),
      message: _t(
        'Non-fatal error recorded for monitoring.',
        fr: 'Erreur non fatale enregistree pour le monitoring.',
      ),
      tool: 'crash_monitoring',
      localNotify: false,
    );
  }

  Future<void> addBudgetGoal({
    required double monthlyLimit,
    ExpenseCategory? category,
  }) async {
    final BudgetGoal goal = BudgetGoal(
      id: _uuid.v4(),
      monthlyLimit: monthlyLimit,
      categoryKey: category?.key,
      last80AlertMonth: null,
      last100AlertMonth: null,
    );

    _budgets.add(goal);
    await _storeService.saveBudgets(_budgets);
    await _pushNotice(
      title: _t('Budget Added', fr: 'Budget ajoute'),
      message: category == null
          ? _t(
              'Global monthly budget has been added.',
              fr: 'Un budget mensuel global a ete ajoute.',
            )
          : _ta('Budget added for {category}.', <String, String>{
              'category': category.localizedLabel(_localeCode),
            }, fr: 'Budget ajoute pour {category}.'),
      tool: 'budget',
      localNotify: false,
    );
    notifyListeners();
  }

  Future<void> removeBudgetGoal(String id) async {
    _budgets.removeWhere((BudgetGoal goal) => goal.id == id);
    await _storeService.saveBudgets(_budgets);
    notifyListeners();
  }

  double spendingForBudget(BudgetGoal goal, List<Expense> expenses) {
    final DateTime now = DateTime.now();
    return expenses
        .where(
          (Expense expense) =>
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.amount > 0 &&
              (goal.categoryKey == null ||
                  expense.category.key == goal.categoryKey),
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);
  }

  Future<void> evaluateBudgets({
    required List<Expense> expenses,
    required String currencyCode,
  }) async {
    final String monthKey = _monthKey(DateTime.now());
    bool changed = false;

    for (int index = 0; index < _budgets.length; index++) {
      final BudgetGoal goal = _budgets[index];
      final double spending = spendingForBudget(goal, expenses);
      if (goal.monthlyLimit <= 0) {
        continue;
      }

      final double ratio = spending / goal.monthlyLimit;
      BudgetGoal updated = goal;

      if (ratio >= _budgetAlert80 && goal.last80AlertMonth != monthKey) {
        final String targetName = goal.categoryKey == null
            ? _t('Global budget', fr: 'Budget global')
            : _ta('{category} budget', <String, String>{
                'category': ExpenseCategoryX.fromKey(
                  goal.categoryKey!,
                ).localizedLabel(_localeCode),
              }, fr: 'Budget {category}');
        await _pushNotice(
          title: _ta('{target} reached 80%', <String, String>{
            'target': targetName,
          }, fr: '{target} atteint a 80%'),
          message: _ta('Spent {amount} this month.', <String, String>{
            'amount': CurrencyUtils.formatAmount(spending, currencyCode),
          }, fr: 'Depense {amount} ce mois-ci.'),
          tool: 'budget',
          localNotify: true,
        );
        updated = updated.copyWith(last80AlertMonth: monthKey);
      }

      if (ratio >= _budgetAlert100 && goal.last100AlertMonth != monthKey) {
        final String targetName = goal.categoryKey == null
            ? _t('Global budget', fr: 'Budget global')
            : _ta('{category} budget', <String, String>{
                'category': ExpenseCategoryX.fromKey(
                  goal.categoryKey!,
                ).localizedLabel(_localeCode),
              }, fr: 'Budget {category}');
        await _pushNotice(
          title: _ta('{target} reached 100%', <String, String>{
            'target': targetName,
          }, fr: '{target} atteint a 100%'),
          message: _ta('Spent {amount} this month.', <String, String>{
            'amount': CurrencyUtils.formatAmount(spending, currencyCode),
          }, fr: 'Depense {amount} ce mois-ci.'),
          tool: 'budget',
          localNotify: true,
        );
        updated = updated.copyWith(last100AlertMonth: monthKey);
      }

      if (updated != goal) {
        _budgets[index] = updated;
        changed = true;
      }
    }

    if (changed) {
      await _storeService.saveBudgets(_budgets);
      notifyListeners();
    }
  }

  Future<void> evaluateSmartSavingPlan({
    required double totalIncomeForMonth,
    required double savingsGoal,
    required double spentForMonth,
    required String currencyCode,
  }) async {
    if (totalIncomeForMonth <= 0 || savingsGoal <= 0) {
      return;
    }

    final double spendableLimit = max(totalIncomeForMonth - savingsGoal, 0);
    if (spendableLimit <= 0) {
      return;
    }

    final String monthKey = _monthKey(DateTime.now());
    bool shouldNotify = false;

    if (spentForMonth >= spendableLimit * 0.8 &&
        _storeService.smartSaving80Month != monthKey) {
      await _pushNotice(
        title: _t(
          'Smart Saving Alert (80%)',
          fr: 'Alerte epargne intelligente (80%)',
        ),
        message: _ta(
          'You used {spent} of {limit} spendable budget.',
          <String, String>{
            'spent': CurrencyUtils.formatAmount(spentForMonth, currencyCode),
            'limit': CurrencyUtils.formatAmount(spendableLimit, currencyCode),
          },
          fr: 'Vous avez utilise {spent} sur {limit} de budget depensable.',
        ),
        tool: 'smart_saving',
        localNotify: true,
      );
      await _storeService.setSmartSaving80Month(monthKey);
      shouldNotify = true;
    }

    if (spentForMonth >= spendableLimit &&
        _storeService.smartSaving100Month != monthKey) {
      await _pushNotice(
        title: _t(
          'Smart Saving Limit Reached',
          fr: 'Limite epargne intelligente atteinte',
        ),
        message: _t(
          'Spendable budget reached. Keep expenses low to protect your savings goal.',
          fr: 'Le budget depensable est atteint. Gardez les depenses basses pour proteger votre objectif d epargne.',
        ),
        tool: 'smart_saving',
        localNotify: true,
      );
      await _storeService.setSmartSaving100Month(monthKey);
      shouldNotify = true;
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  Future<void> addRecurringPlan({
    required double amount,
    required ExpenseCategory category,
    required PlannedCadence cadence,
    required DateTime anchorDate,
    required String note,
    required String currencyCode,
    DateTime? endDate,
  }) async {
    final DateTime normalizedAnchor = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
    );
    final DateTime? normalizedEndDate = endDate == null
        ? null
        : DateTime(endDate.year, endDate.month, endDate.day);
    final RecurringExpensePlan plan = RecurringExpensePlan(
      id: _uuid.v4(),
      amount: amount,
      categoryKey: category.key,
      note: note,
      currencyCode: currencyCode,
      dayOfMonth: normalizedAnchor.day,
      startDate: normalizedAnchor,
      lastAppliedAt: null,
      isActive: true,
      cadence: cadence,
      weekDay: normalizedAnchor.weekday,
      monthOfYear: normalizedAnchor.month,
      endDate: normalizedEndDate,
    );

    _recurringPlans.add(plan);
    await _storeService.saveRecurringPlans(_recurringPlans);
    await _pushNotice(
      title: _t('Recurring Expense Added', fr: 'Depense recurrente ajoutee'),
      message: _ta(
        '{category} planned as {cadence} schedule.',
        <String, String>{
          'category': category.localizedLabel(_localeCode),
          'cadence': _cadenceLabel(cadence),
        },
        fr: '{category} planifie en frequence {cadence}.',
      ),
      tool: 'recurring',
      localNotify: false,
    );
    notifyListeners();
  }

  Future<void> toggleRecurring(String id, bool active) async {
    final int index = _recurringPlans.indexWhere(
      (RecurringExpensePlan plan) => plan.id == id,
    );
    if (index < 0) {
      return;
    }

    _recurringPlans[index] = _recurringPlans[index].copyWith(isActive: active);
    await _storeService.saveRecurringPlans(_recurringPlans);
    notifyListeners();
  }

  Future<void> removeRecurring(String id) async {
    _recurringPlans.removeWhere((RecurringExpensePlan plan) => plan.id == id);
    await _storeService.saveRecurringPlans(_recurringPlans);
    notifyListeners();
  }

  Future<int> processRecurringExpenses({
    required ExpenseController expenseController,
    required String currencyCode,
    String accountId = 'main',
    bool silentIfEmpty = true,
  }) async {
    final DateTime now = DateTime.now();
    final List<Expense> generated = <Expense>[];

    for (int i = 0; i < _recurringPlans.length; i++) {
      final RecurringExpensePlan plan = _recurringPlans[i];
      if (!plan.isActive) {
        continue;
      }

      DateTime cursor = _nextDueDate(plan);
      DateTime? latestApplied;
      RecurringExpensePlan updatedPlan = plan;
      final DateTime nowDateOnly = DateTime(now.year, now.month, now.day);
      final DateTime? endDate = plan.endDate == null
          ? null
          : DateTime(
              plan.endDate!.year,
              plan.endDate!.month,
              plan.endDate!.day,
            );

      while (!cursor.isAfter(nowDateOnly)) {
        if (endDate != null && cursor.isAfter(endDate)) {
          break;
        }

        generated.add(
          Expense(
            id: _uuid.v4(),
            amount: plan.amount,
            category: ExpenseCategoryX.fromKey(plan.categoryKey),
            date: cursor,
            note: plan.note,
            currencyCode: plan.currencyCode,
            accountId: accountId,
          ),
        );

        latestApplied = cursor;
        if (plan.cadence == PlannedCadence.oneTime) {
          updatedPlan = updatedPlan.copyWith(
            lastAppliedAt: latestApplied,
            isActive: false,
          );
          break;
        }
        cursor = _nextByCadence(plan, cursor);
      }

      if (latestApplied != null) {
        _recurringPlans[i] = updatedPlan.copyWith(
          lastAppliedAt: latestApplied,
          currencyCode: currencyCode,
        );
      }
    }

    if (generated.isNotEmpty) {
      await expenseController.addExpensesBulk(generated);
      await _storeService.saveRecurringPlans(_recurringPlans);
      await _pushNotice(
        title: _t(
          'Recurring Expenses Applied',
          fr: 'Depenses recurrentes appliquees',
        ),
        message: _ta(
          '{count} recurring expense(s) added automatically.',
          <String, String>{'count': generated.length.toString()},
          fr: '{count} depense(s) recurrente(s) ajoutee(s) automatiquement.',
        ),
        tool: 'recurring',
        localNotify: true,
      );
      notifyListeners();
    } else if (!silentIfEmpty) {
      await _pushNotice(
        title: _t(
          'Recurring Check Completed',
          fr: 'Verification recurrente terminee',
        ),
        message: _t(
          'No recurring expenses were due today.',
          fr: 'Aucune depense recurrente n etait due aujourd hui.',
        ),
        tool: 'recurring',
        localNotify: false,
      );
    }

    return generated.length;
  }

  DateTime _nextDueDate(RecurringExpensePlan plan) {
    final DateTime start = DateTime(
      plan.startDate.year,
      plan.startDate.month,
      plan.startDate.day,
    );
    if (plan.lastAppliedAt != null) {
      final DateTime last = DateTime(
        plan.lastAppliedAt!.year,
        plan.lastAppliedAt!.month,
        plan.lastAppliedAt!.day,
      );
      return _nextByCadence(plan, last);
    }

    switch (plan.cadence) {
      case PlannedCadence.oneTime:
        return start;
      case PlannedCadence.monthly:
        final DateTime first = _safeDate(
          start.year,
          start.month,
          plan.dayOfMonth,
        );
        if (first.isBefore(start)) {
          final DateTime nextMonth = DateTime(first.year, first.month + 1, 1);
          return _safeDate(nextMonth.year, nextMonth.month, plan.dayOfMonth);
        }
        return first;
      case PlannedCadence.weekly:
        return _nextWeekdayOnOrAfter(start, plan.weekDay);
      case PlannedCadence.yearly:
        final DateTime first = _safeDate(
          start.year,
          plan.monthOfYear,
          plan.dayOfMonth,
        );
        if (first.isBefore(start)) {
          return _safeDate(start.year + 1, plan.monthOfYear, plan.dayOfMonth);
        }
        return first;
    }
  }

  DateTime _nextByCadence(RecurringExpensePlan plan, DateTime from) {
    switch (plan.cadence) {
      case PlannedCadence.oneTime:
        return DateTime(9999, 12, 31);
      case PlannedCadence.monthly:
        final DateTime nextMonth = DateTime(from.year, from.month + 1, 1);
        return _safeDate(nextMonth.year, nextMonth.month, plan.dayOfMonth);
      case PlannedCadence.weekly:
        return DateTime(from.year, from.month, from.day + 7);
      case PlannedCadence.yearly:
        return _safeDate(from.year + 1, plan.monthOfYear, plan.dayOfMonth);
    }
  }

  DateTime _nextWeekdayOnOrAfter(DateTime date, int targetWeekday) {
    final int normalizedTarget = targetWeekday.clamp(1, 7);
    final int delta = (normalizedTarget - date.weekday + 7) % 7;
    return DateTime(date.year, date.month, date.day + delta);
  }

  DateTime _safeDate(int year, int month, int day) {
    final int maxDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, min(day, maxDay));
  }

  Future<String?> signUp(String email, String password) async {
    _authBusy = true;
    notifyListeners();

    final String? error = await _firebaseToolkitService.signUp(
      email: email.trim(),
      password: password,
    );

    _authBusy = false;
    if (error == null) {
      await _firebaseToolkitService.setSubscriptionStatus(isPro: false);
      _usageOverview = await _firebaseToolkitService.getUsageOverview(
        isProLocal: false,
      );
      await _pushNotice(
        title: _t('Cloud Account Created', fr: 'Compte cloud cree'),
        message: _t(
          'Your account is ready for cloud sync.',
          fr: 'Votre compte est pret pour la synchronisation cloud.',
        ),
        tool: 'cloud_sync',
        localNotify: false,
      );
    } else {
      _lastCloudError = error;
    }

    notifyListeners();
    return error;
  }

  Future<String?> signIn(String email, String password) async {
    _authBusy = true;
    notifyListeners();

    final String? error = await _firebaseToolkitService.signIn(
      email: email.trim(),
      password: password,
    );

    _authBusy = false;
    if (error == null) {
      _usageOverview = await _firebaseToolkitService.getUsageOverview(
        isProLocal: false,
      );
      await _pushNotice(
        title: _t('Logged In', fr: 'Connecte'),
        message: _t(
          'Cloud sync is now available.',
          fr: 'La synchronisation cloud est maintenant disponible.',
        ),
        tool: 'cloud_sync',
        localNotify: false,
      );
    } else {
      _lastCloudError = error;
    }

    notifyListeners();
    return error;
  }

  Future<void> signOut() async {
    await _firebaseToolkitService.signOut();
    _usageOverview = const UsageOverview(
      used: 0,
      limit: 180,
      isPro: false,
      remaining: 180,
    );
    await _pushNotice(
      title: _t('Logged Out', fr: 'Deconnecte'),
      message: _t(
        'You have been logged out from cloud sync.',
        fr: 'Vous avez ete deconnecte de la synchronisation cloud.',
      ),
      tool: 'cloud_sync',
      localNotify: false,
    );
    notifyListeners();
  }

  Future<String?> uploadCloud(List<Expense> expenses) async {
    final String? error = await _firebaseToolkitService.uploadExpenses(
      expenses,
    );
    if (error == null) {
      await _pushNotice(
        title: _t('Cloud Upload Complete', fr: 'Envoi cloud termine'),
        message: _ta(
          '{count} expense(s) synced to cloud.',
          <String, String>{'count': expenses.length.toString()},
          fr: '{count} depense(s) synchronisee(s) vers le cloud.',
        ),
        tool: 'cloud_sync',
        localNotify: false,
      );
    } else {
      _lastCloudError = error;
    }
    notifyListeners();
    return error;
  }

  Future<UsageOverview> refreshUsage({required bool isProLocal}) async {
    _usageOverview = await _firebaseToolkitService.getUsageOverview(
      isProLocal: isProLocal,
    );
    notifyListeners();
    return _usageOverview;
  }

  Future<UsageConsumeResult> consumeUsage({required bool isProLocal}) async {
    final UsageConsumeResult result = await _firebaseToolkitService
        .tryConsumeUsage(amount: 1, isProLocal: isProLocal);
    _usageOverview = result.overview;

    if (result.allowed) {
      final int used = result.overview.used;
      final int limit = result.overview.limit;
      if (!result.overview.isPro && limit > 0) {
        final double ratio = used / limit;
        if (ratio >= 0.8 && ratio < 1.0) {
          await _pushNotice(
            title: _ta('Usage Reached {percent}%', <String, String>{
              'percent': ((ratio) * 100).toStringAsFixed(0),
            }, fr: 'Utilisation atteinte a {percent}%'),
            message: _t(
              'You are close to monthly free limit. Upgrade to Pro.',
              fr: 'Vous etes proche de la limite gratuite mensuelle. Passez a Pro.',
            ),
            tool: 'cloud_usage',
            localNotify: false,
          );
        }
      }
    } else {
      await _pushNotice(
        title: _t(
          'Monthly Free Limit Reached',
          fr: 'Limite gratuite mensuelle atteinte',
        ),
        message:
            result.message ??
            _t(
              'Upgrade to Pro to continue.',
              fr: 'Passez a Pro pour continuer.',
            ),
        tool: 'cloud_usage',
        localNotify: true,
      );
    }

    notifyListeners();
    return result;
  }

  Future<String?> downloadAndMergeCloud({
    required ExpenseController expenseController,
    required String fallbackCurrency,
  }) async {
    final (List<Expense> cloudExpenses, String? error) =
        await _firebaseToolkitService.downloadExpenses();
    if (error != null) {
      _lastCloudError = error;
      notifyListeners();
      return error;
    }

    final List<Expense> normalized = cloudExpenses
        .map(
          (Expense expense) => Expense(
            id: expense.id,
            amount: expense.amount,
            category: expense.category,
            date: expense.date,
            note: expense.note,
            currencyCode: expense.currencyCode.isEmpty
                ? fallbackCurrency
                : expense.currencyCode,
            accountId: expense.accountId,
          ),
        )
        .toList(growable: false);

    final int inserted = await expenseController.addExpensesBulk(normalized);

    await _pushNotice(
      title: _t('Cloud Download Complete', fr: 'Telechargement cloud termine'),
      message: _ta(
        '{count} new expense(s) merged from cloud.',
        <String, String>{'count': inserted.toString()},
        fr: '{count} nouvelle(s) depense(s) fusionnee(s) depuis le cloud.',
      ),
      tool: 'cloud_sync',
      localNotify: false,
    );

    notifyListeners();
    return null;
  }

  Future<String?> exportCsv(List<Expense> expenses) async {
    try {
      final String path = await _csvService.exportExpenses(expenses);
      await _pushNotice(
        title: _t('CSV Exported', fr: 'CSV exporte'),
        message: _t(
          'CSV file created successfully.',
          fr: 'Fichier CSV cree avec succes.',
        ),
        tool: 'csv',
        localNotify: false,
      );
      return path;
    } catch (error) {
      return error.toString();
    }
  }

  Future<(List<Expense>, String?)> importCsv(String fallbackCurrency) async {
    try {
      final List<Expense> expenses = await _csvService.importExpenses(
        fallbackCurrency: fallbackCurrency,
      );
      if (expenses.isNotEmpty) {
        await _pushNotice(
          title: _t('CSV Imported', fr: 'CSV importe'),
          message: _ta(
            '{count} expense(s) loaded from CSV.',
            <String, String>{'count': expenses.length.toString()},
            fr: '{count} depense(s) chargee(s) depuis CSV.',
          ),
          tool: 'csv',
          localNotify: false,
        );
      }
      return (expenses, null);
    } catch (error) {
      return (<Expense>[], error.toString());
    }
  }

  Future<OcrScanResult?> scanReceipt(ImageSource source) async {
    _lastOcrError = null;
    try {
      final OcrScanResult? result = await _ocrService.scanReceipt(source);
      _lastOcrResult = result;
      if (result != null) {
        await _pushNotice(
          title: _t('Receipt Scanned', fr: 'Recu scanne'),
          message: _t(
            'OCR completed. Review the extracted values.',
            fr: 'OCR termine. Verifiez les valeurs extraites.',
          ),
          tool: 'ocr',
          localNotify: false,
        );
      }
      notifyListeners();
      return result;
    } on OcrServiceException catch (error) {
      _lastOcrResult = null;
      _lastOcrError = error.message;
      notifyListeners();
      return null;
    } catch (_) {
      _lastOcrResult = null;
      _lastOcrError = _t(
        'Receipt scan failed. Please try again.',
        fr: 'Echec du scan du recu. Veuillez reessayer.',
      );
      notifyListeners();
      return null;
    }
  }

  Future<bool> addExpenseFromOcr({
    required OcrScanResult result,
    required ExpenseCategory category,
    required ExpenseController expenseController,
    required String currencyCode,
    String accountId = 'main',
  }) async {
    if (result.amount == null || result.amount! <= 0) {
      return false;
    }

    final Expense expense = Expense(
      id: _uuid.v4(),
      amount: result.amount!,
      category: category,
      date: result.date ?? DateTime.now(),
      note: result.suggestedNote,
      currencyCode: currencyCode,
      accountId: accountId,
    );

    await expenseController.addExpense(expense);
    await _pushNotice(
      title: _t('OCR Expense Added', fr: 'Depense OCR ajoutee'),
      message: _t(
        'Scanned receipt has been saved as an expense.',
        fr: 'Le recu scanne a ete enregistre comme depense.',
      ),
      tool: 'ocr',
      localNotify: false,
    );
    return true;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled && !_biometricSupported) {
      return;
    }
    _biometricEnabled = enabled;
    await _storeService.setBiometricEnabled(enabled);
    if (enabled) {
      _locked = true;
    } else if (!_pinEnabled) {
      _locked = false;
    }
    notifyListeners();
  }

  Future<void> setPinCode(String pin) async {
    _pinCode = pin;
    _pinEnabled = pin.isNotEmpty;
    await _storeService.setPinCode(pin);
    await _storeService.setPinEnabled(_pinEnabled);
    if (_pinEnabled) {
      _locked = true;
    }
    notifyListeners();
  }

  Future<void> disablePin() async {
    _pinCode = '';
    _pinEnabled = false;
    await _storeService.setPinCode('');
    await _storeService.setPinEnabled(false);
    if (!_biometricEnabled) {
      _locked = false;
    }
    notifyListeners();
  }

  void lockNow() {
    if (_biometricEnabled || _pinEnabled) {
      _locked = true;
      notifyListeners();
    }
  }

  Future<bool> unlockWithBiometric() async {
    if (!_biometricEnabled) {
      return false;
    }

    final bool ok = await _securityService.authenticate();
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  bool unlockWithPin(String pin) {
    final bool ok = _pinEnabled && pin == _pinCode;
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  Future<void> markAllNoticesRead() async {
    for (int i = 0; i < _notices.length; i++) {
      _notices[i] = _notices[i].copyWith(isRead: true);
    }
    await _storeService.saveNotices(_notices);
    notifyListeners();
  }

  Future<void> markNoticeRead(String id) async {
    final int idx = _notices.indexWhere((ToolNotice notice) => notice.id == id);
    if (idx < 0) {
      return;
    }

    _notices[idx] = _notices[idx].copyWith(isRead: true);
    await _storeService.saveNotices(_notices);
    notifyListeners();
  }

  Future<void> _pushNotice({
    required String title,
    required String message,
    required String tool,
    required bool localNotify,
  }) async {
    final ToolNotice notice = ToolNotice(
      id: _uuid.v4(),
      title: title,
      message: message,
      tool: tool,
      createdAt: DateTime.now(),
      isRead: false,
    );

    _notices.insert(0, notice);
    if (_notices.length > 120) {
      _notices.removeRange(120, _notices.length);
    }

    await _storeService.saveNotices(_notices);

    if (localNotify) {
      final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotificationService.show(
        id: notificationId,
        title: title,
        body: message,
      );
    }
  }

  String _monthKey(DateTime date) {
    final String month = date.month < 10 ? '0${date.month}' : '${date.month}';
    return '${date.year}-$month';
  }

  String _cadenceLabel(PlannedCadence cadence) {
    switch (cadence) {
      case PlannedCadence.oneTime:
        return _t('One-time', fr: 'Une seule fois');
      case PlannedCadence.monthly:
        return _t('Monthly', fr: 'Mensuel');
      case PlannedCadence.weekly:
        return _t('Weekly', fr: 'Hebdomadaire');
      case PlannedCadence.yearly:
        return _t('Yearly', fr: 'Annuel');
    }
  }

  String _t(String english, {String? fr}) {
    return AppLocalizations.phraseForLocale(_localeCode, english, french: fr);
  }

  String _ta(String english, Map<String, String> args, {String? fr}) {
    return AppLocalizations.phraseWithArgsForLocale(
      _localeCode,
      english,
      args,
      french: fr,
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }
}

