import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

enum ExpenseFlowFilter { all, expense, income, transfer }

enum ExpenseSortOrder { dateDesc, dateAsc, amountDesc, amountAsc }

const Object _unset = Object();

class ExpenseAdvancedFilter {
  const ExpenseAdvancedFilter({
    this.searchQuery = '',
    this.accountId,
    this.startDate,
    this.endDate,
    this.flow = ExpenseFlowFilter.all,
    this.categoryKey,
    this.customCategoryId,
    this.minAmount,
    this.maxAmount,
    this.sortOrder = ExpenseSortOrder.dateDesc,
  });

  final String searchQuery;
  final String? accountId;
  final DateTime? startDate;
  final DateTime? endDate;
  final ExpenseFlowFilter flow;
  final String? categoryKey;
  final String? customCategoryId;
  final double? minAmount;
  final double? maxAmount;
  final ExpenseSortOrder sortOrder;

  ExpenseAdvancedFilter copyWith({
    String? searchQuery,
    Object? accountId = _unset,
    Object? startDate = _unset,
    Object? endDate = _unset,
    ExpenseFlowFilter? flow,
    Object? categoryKey = _unset,
    Object? customCategoryId = _unset,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    ExpenseSortOrder? sortOrder,
  }) {
    return ExpenseAdvancedFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      accountId: accountId == _unset ? this.accountId : accountId as String?,
      startDate: startDate == _unset ? this.startDate : startDate as DateTime?,
      endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
      flow: flow ?? this.flow,
      categoryKey: categoryKey == _unset
          ? this.categoryKey
          : categoryKey as String?,
      customCategoryId: customCategoryId == _unset
          ? this.customCategoryId
          : customCategoryId as String?,
      minAmount: minAmount == _unset ? this.minAmount : minAmount as double?,
      maxAmount: maxAmount == _unset ? this.maxAmount : maxAmount as double?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.trim().isNotEmpty) count += 1;
    if (accountId != null && accountId!.trim().isNotEmpty) count += 1;
    if (startDate != null || endDate != null) count += 1;
    if (flow != ExpenseFlowFilter.all) count += 1;
    if (categoryKey != null || customCategoryId != null) count += 1;
    if (minAmount != null || maxAmount != null) count += 1;
    if (sortOrder != ExpenseSortOrder.dateDesc) count += 1;
    return count;
  }
}

List<Expense> applyExpenseAdvancedFilter(
  List<Expense> source,
  ExpenseAdvancedFilter filter,
) {
  Iterable<Expense> result = source;
  final String query = filter.searchQuery.trim().toLowerCase();

  if (filter.accountId != null && filter.accountId!.trim().isNotEmpty) {
    result = result.where(
      (Expense expense) => expense.accountId == filter.accountId,
    );
  }

  if (query.isNotEmpty) {
    result = result.where((Expense expense) {
      return expense.note.toLowerCase().contains(query) ||
          expense.category.key.toLowerCase().contains(query) ||
          (expense.customCategoryName ?? '').toLowerCase().contains(query) ||
          expense.accountId.toLowerCase().contains(query);
    });
  }

  if (filter.startDate != null) {
    final DateTime start = DateTime(
      filter.startDate!.year,
      filter.startDate!.month,
      filter.startDate!.day,
    );
    result = result.where((Expense expense) => !expense.date.isBefore(start));
  }

  if (filter.endDate != null) {
    final DateTime end = DateTime(
      filter.endDate!.year,
      filter.endDate!.month,
      filter.endDate!.day,
      23,
      59,
      59,
      999,
    );
    result = result.where((Expense expense) => !expense.date.isAfter(end));
  }

  switch (filter.flow) {
    case ExpenseFlowFilter.all:
      break;
    case ExpenseFlowFilter.expense:
      result = result.where(
        (Expense expense) => expense.amount > 0 && !expense.isTransfer,
      );
      break;
    case ExpenseFlowFilter.income:
      result = result.where(
        (Expense expense) => expense.amount < 0 && !expense.isTransfer,
      );
      break;
    case ExpenseFlowFilter.transfer:
      result = result.where((Expense expense) => expense.isTransfer);
      break;
  }

  if (filter.customCategoryId != null &&
      filter.customCategoryId!.trim().isNotEmpty) {
    result = result.where(
      (Expense expense) => expense.customCategoryId == filter.customCategoryId,
    );
  } else if (filter.categoryKey != null &&
      filter.categoryKey!.trim().isNotEmpty) {
    result = result.where(
      (Expense expense) => expense.category.key == filter.categoryKey,
    );
  }

  if (filter.minAmount != null) {
    result = result.where(
      (Expense expense) => expense.amount.abs() >= filter.minAmount!,
    );
  }
  if (filter.maxAmount != null) {
    result = result.where(
      (Expense expense) => expense.amount.abs() <= filter.maxAmount!,
    );
  }

  final List<Expense> sorted = result.toList(growable: false);
  switch (filter.sortOrder) {
    case ExpenseSortOrder.dateDesc:
      sorted.sort((Expense a, Expense b) => b.date.compareTo(a.date));
      break;
    case ExpenseSortOrder.dateAsc:
      sorted.sort((Expense a, Expense b) => a.date.compareTo(b.date));
      break;
    case ExpenseSortOrder.amountDesc:
      sorted.sort(
        (Expense a, Expense b) => b.amount.abs().compareTo(a.amount.abs()),
      );
      break;
    case ExpenseSortOrder.amountAsc:
      sorted.sort(
        (Expense a, Expense b) => a.amount.abs().compareTo(b.amount.abs()),
      );
      break;
  }

  return sorted;
}

