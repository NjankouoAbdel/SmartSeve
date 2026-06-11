import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/date_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/expense_filtering.dart';
import 'package:wfer_flousk_firebase/core/utils/icon_utils.dart';
import 'package:wfer_flousk_firebase/core/widgets/fintech_page_app_bar.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/responsive_page_body.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/add_expense/add_expense_page.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/expense_filter_bottom_sheet.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

enum TransactionPeriod { today, weekly, monthly, all, custom }

class _TransactionsPageState extends State<TransactionsPage> {
  TransactionPeriod _period = TransactionPeriod.monthly;
  final TextEditingController _searchController = TextEditingController();
  ExpenseAdvancedFilter _advancedFilter = const ExpenseAdvancedFilter();
  bool _filtersInitialized = false;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filtersInitialized) {
      return;
    }
    final String activeAccountId = context
        .read<SettingsController>()
        .activeBankAccountId;
    _advancedFilter = _advancedFilter.copyWith(accountId: activeAccountId);
    _searchController.text = _advancedFilter.searchQuery;
    _filtersInitialized = true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseController expenseController = context
        .watch<ExpenseController>();
    final SettingsController settings = context.watch<SettingsController>();
    final List<Expense> filtered = _applyFilters(
      expenseController.expenses.toList(),
    );

    return ResponsivePageBody(
      top: 8,
      bottom: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const FintechPageAppBar(title: 'Transactions', showBackToHome: true),
          const SizedBox(height: UiTokens.spacingSm),
          _searchBar(context),
          const SizedBox(height: UiTokens.spacingSm),
          _filterRow(context),
          const SizedBox(height: UiTokens.spacingSm),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                if (index >= filtered.length) {
                  return const SizedBox.shrink();
                }

                return _transactionTile(
                  context,
                  filtered[index],
                  settings.currencyCode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final int activeCount = _effectiveFilterCount();
    return TextField(
      controller: _searchController,
      onChanged: (String value) {
        setState(() {
          _advancedFilter = _advancedFilter.copyWith(searchQuery: value.trim());
        });
      },
      decoration: InputDecoration(
        hintText: _t('Search transactions', fr: 'Rechercher des transactions'),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIconConstraints: const BoxConstraints(minWidth: 96),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_advancedFilter.searchQuery.trim().isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _advancedFilter = _advancedFilter.copyWith(searchQuery: '');
                  });
                },
                icon: const Icon(Icons.clear_rounded),
              ),
            IconButton(
              onPressed: () => _openAdvancedFilters(context),
              icon: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  const Icon(Icons.tune_rounded),
                  if (activeCount > 0)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text(
                          '$activeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterRow(BuildContext context) {
    final String customLabel =
        (_advancedFilter.startDate != null || _advancedFilter.endDate != null)
        ? '${_advancedFilter.startDate == null ? '...' : DateUtilsX.short(_advancedFilter.startDate!, localeCode: Localizations.localeOf(context).languageCode)} -> ${_advancedFilter.endDate == null ? '...' : DateUtilsX.short(_advancedFilter.endDate!, localeCode: Localizations.localeOf(context).languageCode)}'
        : _t('Custom Range', fr: 'Periode personnalisee');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _periodChip(context, _t('Today', fr: 'Aujourd hui'), TransactionPeriod.today),
        _periodChip(context, _t('Week', fr: 'Semaine'), TransactionPeriod.weekly),
        _periodChip(context, _t('Month', fr: 'Mois'), TransactionPeriod.monthly),
        _periodChip(context, _t('All', fr: 'Tout'), TransactionPeriod.all),
        if (_period == TransactionPeriod.custom)
          _periodChip(context, customLabel, TransactionPeriod.custom),
      ],
    );
  }

  Widget _periodChip(
    BuildContext context,
    String label,
    TransactionPeriod value,
  ) {
    final bool selected = _period == value;
    return SizedBox(
      height: 38,
      child: InkWell(
        onTap: () => setState(() => _period = value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: selected
                ? const LinearGradient(
                    colors: <Color>[
                      AppColors.primaryBlue,
                      AppColors.gradientBlue2,
                    ],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.softGrayText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _transactionTile(
    BuildContext context,
    Expense expense,
    String currencyCode,
  ) {
    final bool isIncome = expense.amount < 0;
    final Color amountColor = expense.isTransfer
        ? AppColors.skyBlue
        : (isIncome ? AppColors.incomeGreen : AppColors.expenseRed);

    return GlassCard(
      borderRadius: 18,
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: <Color>[AppColors.primaryBlue, AppColors.gradientBlue2],
              ),
            ),
            child: Icon(
              _iconForExpense(expense),
              color:
                  expense.isCustomCategory &&
                      expense.customCategoryColorValue != null
                  ? Color(expense.customCategoryColorValue!)
                  : Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  expense.note.trim().isNotEmpty
                      ? expense.note.trim()
                      : expense.categoryLabel(
                          Localizations.localeOf(context).languageCode,
                        ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  DateUtilsX.short(
                    expense.date,
                    localeCode: Localizations.localeOf(context).languageCode,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${isIncome ? '+' : '-'}${CurrencyUtils.formatAmount(expense.amount.abs(), currencyCode)}',
                maxLines: 1,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'edit') {
                _onEditExpense(expense);
                return;
              }
              if (value == 'delete') {
                _onDeleteExpense(expense);
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(_t('Edit', fr: 'Modifier')),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: Text(_t('Delete', fr: 'Supprimer')),
                    ),
                  ),
                ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }

  List<Expense> _applyFilters(List<Expense> source) {
    final (DateTime? startDate, DateTime? endDate) = _periodRange();
    final ExpenseAdvancedFilter effectiveFilter = _advancedFilter.copyWith(
      startDate: startDate,
      endDate: endDate,
    );
    return applyExpenseAdvancedFilter(source, effectiveFilter);
  }

  (DateTime?, DateTime?) _periodRange() {
    final DateTime now = DateTime.now();
    switch (_period) {
      case TransactionPeriod.today:
        final DateTime start = DateTime(now.year, now.month, now.day);
        return (start, start);
      case TransactionPeriod.weekly:
        final DateTime start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final DateTime end = start.add(const Duration(days: 6));
        return (start, end);
      case TransactionPeriod.monthly:
        final DateTime start = DateTime(now.year, now.month, 1);
        final DateTime end = DateTime(now.year, now.month + 1, 0);
        return (start, end);
      case TransactionPeriod.all:
        return (null, null);
      case TransactionPeriod.custom:
        return (_advancedFilter.startDate, _advancedFilter.endDate);
    }
  }

  int _effectiveFilterCount() {
    int count = _advancedFilter.activeFilterCount;
    if (_period != TransactionPeriod.monthly) {
      count += 1;
    }
    return count;
  }

  Future<void> _openAdvancedFilters(BuildContext context) async {
    final SettingsController settings = context.read<SettingsController>();
    final ExpenseAdvancedFilter initial = _period == TransactionPeriod.custom
        ? _advancedFilter
        : _advancedFilter.copyWith(startDate: null, endDate: null);
    final ExpenseAdvancedFilter? updated =
        await showModalBottomSheet<ExpenseAdvancedFilter>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext sheetContext) {
            return ExpenseFilterBottomSheet(
              initialFilter: initial,
              accounts: settings.bankAccounts,
              customCategories: settings.customCategories,
              localeCode: settings.localeCode,
            );
          },
        );

    if (updated == null) {
      return;
    }
    setState(() {
      _advancedFilter = updated;
      if (updated.startDate != null || updated.endDate != null) {
        _period = TransactionPeriod.custom;
      } else if (_period == TransactionPeriod.custom) {
        _period = TransactionPeriod.all;
      }
      _searchController.text = _advancedFilter.searchQuery;
    });
  }

  IconData _iconForCategory(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_bus_filled_rounded;
      case ExpenseCategory.rent:
        return Icons.apartment_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_long_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  IconData _iconForExpense(Expense expense) {
    if (expense.isCustomCategory &&
        expense.customCategoryIconCodePoint != null) {
      return AppIconUtils.fromCodePoint(
        expense.customCategoryIconCodePoint,
        fallback: _iconForCategory(expense.category),
      );
    }
    return _iconForCategory(expense.category);
  }

  Future<void> _onEditExpense(Expense expense) async {
    final ToolsController toolsController = context.read<ToolsController>();
    final ExpenseController expenseController = context
        .read<ExpenseController>();
    final SettingsController settings = context.read<SettingsController>();

    await Navigator.of(context).push(
      AppRouter.slideFade(
        AddExpensePage(
          isStandalone: true,
          initialExpense: expense,
          onSaved: () {},
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await toolsController.evaluateBudgets(
      expenses: expenseController.expensesForAccount(
        settings.activeBankAccountId,
      ),
      currencyCode: settings.currencyCode,
    );
  }

  Future<void> _onDeleteExpense(Expense expense) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_t('Delete expense', fr: 'Supprimer la depense')),
          content: Text(
            _t(
              'This action cannot be undone. Continue?',
              fr: 'Cette action est irreversible. Continuer ?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_t('Cancel', fr: 'Annuler')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_t('Delete', fr: 'Supprimer')),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    final ExpenseController expenseController = context
        .read<ExpenseController>();
    final SettingsController settings = context.read<SettingsController>();
    final ToolsController toolsController = context.read<ToolsController>();
    try {
      await expenseController.deleteExpense(expense.id);
      await toolsController.evaluateBudgets(
        expenses: expenseController.expensesForAccount(
          settings.activeBankAccountId,
        ),
        currencyCode: settings.currencyCode,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(_t('Expense deleted.', fr: 'Depense supprimee.'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Cloud delete failed. Check Firebase Auth/Firestore rules.',
              fr: 'Suppression cloud echouee. Verifiez Auth/Firestore.',
            ),
          ),
        ),
      );
      debugPrint('Delete failed: $error');
    }
  }
}

