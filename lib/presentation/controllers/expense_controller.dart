import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:wfer_flousk_firebase/core/services/financial_advisor_service.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/domain/usecases/add_expense_usecase.dart';
import 'package:wfer_flousk_firebase/domain/usecases/delete_expense_usecase.dart';
import 'package:wfer_flousk_firebase/domain/usecases/get_expenses_usecase.dart';
import 'package:wfer_flousk_firebase/domain/usecases/update_expense_usecase.dart';

class ExpenseController extends ChangeNotifier {
  ExpenseController({
    required AddExpenseUseCase addExpenseUseCase,
    required GetExpensesUseCase getExpensesUseCase,
    required UpdateExpenseUseCase updateExpenseUseCase,
    required DeleteExpenseUseCase deleteExpenseUseCase,
    FinancialAdvisorService? financialAdvisorService,
  }) : _addExpenseUseCase = addExpenseUseCase,
       _getExpensesUseCase = getExpensesUseCase,
       _updateExpenseUseCase = updateExpenseUseCase,
       _deleteExpenseUseCase = deleteExpenseUseCase,
       _financialAdvisorService = financialAdvisorService;

  final AddExpenseUseCase _addExpenseUseCase;
  final GetExpensesUseCase _getExpensesUseCase;
  final UpdateExpenseUseCase _updateExpenseUseCase;
  final DeleteExpenseUseCase _deleteExpenseUseCase;
  // Optionnel : permet a l'agent anomalies de verifier chaque nouvelle
  // depense (voir addExpense). Nullable pour ne pas casser les tests qui
  // construisent ce controleur sans ce service.
  final FinancialAdvisorService? _financialAdvisorService;

  final List<Expense> _expenses = <Expense>[];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  UnmodifiableListView<Expense> get expenses {
    final List<Expense> sorted = List<Expense>.from(_expenses)
      ..sort((Expense a, Expense b) => b.date.compareTo(a.date));
    return UnmodifiableListView<Expense>(sorted);
  }

  List<Expense> expensesForAccount(String accountId) {
    final List<Expense> filtered =
        _expenses
            .where((Expense expense) => expense.accountId == accountId)
            .toList(growable: false)
          ..sort((Expense a, Expense b) => b.date.compareTo(a.date));
    return filtered;
  }

  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Expense> result = await _getExpensesUseCase.call();
      _expenses
        ..clear()
        ..addAll(result);
    } catch (_) {
      _expenses.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(Expense expense) async {
    await _addExpenseUseCase.call(expense);
    _expenses.add(expense);
    notifyListeners();
    // Agent anomalies : verifie cette depense fraichement enregistree par
    // rapport a l'historique de l'utilisateur. Ne bloque jamais l'ajout
    // (fire-and-forget) et n'echoue jamais bruyamment en cas de probleme.
    unawaited(_financialAdvisorService?.checkForAnomalies(expense));
  }

  Future<void> updateExpense(Expense expense) async {
    await _updateExpenseUseCase.call(expense);
    final int index = _expenses.indexWhere((Expense e) => e.id == expense.id);
    if (index < 0) {
      return;
    }
    _expenses[index] = expense;
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    await _deleteExpenseUseCase.call(id);
    _expenses.removeWhere((Expense expense) => expense.id == id);
    notifyListeners();
  }

  Future<int> addExpensesBulk(List<Expense> incoming) async {
    if (incoming.isEmpty) {
      return 0;
    }

    final Set<String> existingIds = _expenses
        .map((Expense expense) => expense.id)
        .toSet();
    int added = 0;

    for (final Expense expense in incoming) {
      if (existingIds.contains(expense.id)) {
        continue;
      }
      await _addExpenseUseCase.call(expense);
      _expenses.add(expense);
      existingIds.add(expense.id);
      added += 1;
    }

    if (added > 0) {
      notifyListeners();
    }

    return added;
  }

  double get totalBalance {
    return _expenses.fold<double>(0, (double sum, Expense expense) {
      return sum + expense.amount;
    });
  }

  double get totalIncome {
    return _expenses
        .where((Expense expense) => expense.amount < 0 && !expense.isTransfer)
        .fold<double>(
          0,
          (double sum, Expense expense) => sum + expense.amount.abs(),
        );
  }

  double get totalExpensesOnly {
    return _expenses
        .where((Expense expense) => expense.amount > 0 && !expense.isTransfer)
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);
  }

  double get monthlySpending {
    final DateTime now = DateTime.now();
    return _expenses
        .where(
          (Expense expense) =>
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.amount > 0 &&
              !expense.isTransfer,
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);
  }

  double get monthlyIncomeTransactions {
    final DateTime now = DateTime.now();
    return _expenses
        .where(
          (Expense expense) =>
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.amount < 0 &&
              !expense.isTransfer,
        )
        .fold<double>(
          0,
          (double sum, Expense expense) => sum + expense.amount.abs(),
        );
  }

  double get todaySpending {
    final DateTime now = DateTime.now();
    return _expenses
        .where(
          (Expense expense) =>
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.date.day == now.day &&
              expense.amount > 0 &&
              !expense.isTransfer,
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);
  }

  List<Expense> get recentExpenses {
    return expenses.take(8).toList(growable: false);
  }

  Map<ExpenseCategory, double> get spendingByCategory {
    final Map<ExpenseCategory, double> data = <ExpenseCategory, double>{
      for (final ExpenseCategory category in ExpenseCategory.values)
        category: 0,
    };

    for (final Expense expense in _expenses) {
      if (expense.amount <= 0) {
        continue;
      }
      if (expense.isTransfer) {
        continue;
      }
      data[expense.category] = (data[expense.category] ?? 0) + expense.amount;
    }

    return data;
  }

  List<double> get lastSixMonthsSpending {
    final DateTime now = DateTime.now();
    final List<double> values = <double>[];

    for (int i = 5; i >= 0; i--) {
      final DateTime month = DateTime(now.year, now.month - i, 1);
      final double total = _expenses
          .where(
            (Expense expense) =>
                expense.date.year == month.year &&
                expense.date.month == month.month &&
                expense.amount > 0 &&
                !expense.isTransfer,
          )
          .fold<double>(
            0,
            (double sum, Expense expense) => sum + expense.amount,
          );
      values.add(total);
    }

    return values;
  }

  Map<String, double> get weeklyComparison {
    final DateTime now = DateTime.now();
    final int weekday = now.weekday;
    final DateTime startCurrentWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: weekday - 1));
    final DateTime startPreviousWeek = startCurrentWeek.subtract(
      const Duration(days: 7),
    );

    final double currentWeek = _expenses
        .where(
          (Expense expense) =>
              expense.date.isAfter(
                startCurrentWeek.subtract(const Duration(seconds: 1)),
              ) &&
              expense.date.isBefore(
                startCurrentWeek.add(const Duration(days: 7)),
              ) &&
              expense.amount > 0 &&
              !expense.isTransfer,
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);

    final double previousWeek = _expenses
        .where(
          (Expense expense) =>
              expense.date.isAfter(
                startPreviousWeek.subtract(const Duration(seconds: 1)),
              ) &&
              expense.date.isBefore(
                startPreviousWeek.add(const Duration(days: 7)),
              ) &&
              expense.amount > 0 &&
              !expense.isTransfer,
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);

    return <String, double>{
      'Current Week': currentWeek,
      'Previous Week': previousWeek,
    };
  }

  double monthlySpendingForAccount(String accountId) {
    final DateTime now = DateTime.now();
    return _expenses
        .where(
          (Expense expense) =>
              expense.accountId == accountId &&
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.amount > 0 &&
              !expense.isTransfer,
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);
  }

  double monthlyIncomeTransactionsForAccount(String accountId) {
    final DateTime now = DateTime.now();
    return _expenses
        .where(
          (Expense expense) =>
              expense.accountId == accountId &&
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.amount < 0 &&
              !expense.isTransfer,
        )
        .fold<double>(
          0,
          (double sum, Expense expense) => sum + expense.amount.abs(),
        );
  }

  double todaySpendingForAccount(String accountId) {
    final DateTime now = DateTime.now();
    return _expenses
        .where(
          (Expense expense) =>
              expense.accountId == accountId &&
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.date.day == now.day &&
              expense.amount > 0 &&
              !expense.isTransfer,
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);
  }

  Map<String, double> weeklyComparisonForAccount(String accountId) {
    final DateTime now = DateTime.now();
    final int weekday = now.weekday;
    final DateTime startCurrentWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: weekday - 1));
    final DateTime startPreviousWeek = startCurrentWeek.subtract(
      const Duration(days: 7),
    );

    final double currentWeek = _expenses
        .where(
          (Expense expense) =>
              expense.accountId == accountId &&
              expense.date.isAfter(
                startCurrentWeek.subtract(const Duration(seconds: 1)),
              ) &&
              expense.date.isBefore(
                startCurrentWeek.add(const Duration(days: 7)),
              ) &&
              expense.amount > 0 &&
              !expense.isTransfer,
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);

    final double previousWeek = _expenses
        .where(
          (Expense expense) =>
              expense.accountId == accountId &&
              expense.date.isAfter(
                startPreviousWeek.subtract(const Duration(seconds: 1)),
              ) &&
              expense.date.isBefore(
                startPreviousWeek.add(const Duration(days: 7)),
              ) &&
              expense.amount > 0 &&
              !expense.isTransfer,
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);

    return <String, double>{
      'Current Week': currentWeek,
      'Previous Week': previousWeek,
    };
  }
}

