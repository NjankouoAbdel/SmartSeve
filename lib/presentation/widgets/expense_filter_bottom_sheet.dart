import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/utils/date_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/expense_filtering.dart';
import 'package:wfer_flousk_firebase/domain/entities/bank_account.dart';
import 'package:wfer_flousk_firebase/domain/entities/custom_category.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';

class ExpenseFilterBottomSheet extends StatefulWidget {
  const ExpenseFilterBottomSheet({
    required this.initialFilter,
    required this.accounts,
    required this.customCategories,
    required this.localeCode,
    super.key,
  });

  final ExpenseAdvancedFilter initialFilter;
  final List<BankAccount> accounts;
  final List<CustomCategory> customCategories;
  final String localeCode;

  @override
  State<ExpenseFilterBottomSheet> createState() =>
      _ExpenseFilterBottomSheetState();
}

class _ExpenseFilterBottomSheetState extends State<ExpenseFilterBottomSheet> {
  late final TextEditingController _searchController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  String? _selectedAccountId;
  DateTime? _startDate;
  DateTime? _endDate;
  ExpenseFlowFilter _flow = ExpenseFlowFilter.all;
  String _categoryToken = '';
  ExpenseSortOrder _sortOrder = ExpenseSortOrder.dateDesc;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  @override
  void initState() {
    super.initState();
    final ExpenseAdvancedFilter initial = widget.initialFilter;
    _searchController = TextEditingController(text: initial.searchQuery);
    _minController = TextEditingController(
      text: initial.minAmount?.toStringAsFixed(2) ?? '',
    );
    _maxController = TextEditingController(
      text: initial.maxAmount?.toStringAsFixed(2) ?? '',
    );
    _selectedAccountId = initial.accountId;
    _startDate = initial.startDate;
    _endDate = initial.endDate;
    _flow = initial.flow;
    _sortOrder = initial.sortOrder;
    if (initial.customCategoryId != null &&
        initial.customCategoryId!.trim().isNotEmpty) {
      _categoryToken = 'custom:${initial.customCategoryId}';
    } else if (initial.categoryKey != null &&
        initial.categoryKey!.trim().isNotEmpty) {
      _categoryToken = 'cat:${initial.categoryKey}';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                Theme.of(context).dialogTheme.backgroundColor ??
                Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _t('Advanced Filters', fr: 'Filtres avances'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _t(
                      'Search note/category/account',
                      fr: 'Rechercher note/categorie/compte',
                    ),
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.accounts.length > 1)
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedAccountId,
                    decoration: InputDecoration(
                      hintText: _t('Account', fr: 'Compte'),
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    items: <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(_t('All accounts', fr: 'Tous les comptes')),
                      ),
                      ...widget.accounts.map(
                        (BankAccount account) => DropdownMenuItem<String?>(
                          value: account.id,
                          child: Text(settings.displayBankAccountName(account)),
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      setState(() => _selectedAccountId = value);
                    },
                  ),
                if (widget.accounts.length > 1) const SizedBox(height: 10),
                DropdownButtonFormField<ExpenseFlowFilter>(
                  initialValue: _flow,
                  decoration: InputDecoration(
                    hintText: _t('Type', fr: 'Type'),
                    prefixIcon: Icon(Icons.compare_arrows_rounded),
                  ),
                  items: <DropdownMenuItem<ExpenseFlowFilter>>[
                    DropdownMenuItem<ExpenseFlowFilter>(
                      value: ExpenseFlowFilter.all,
                      child: Text(_t('All', fr: 'Tout')),
                    ),
                    DropdownMenuItem<ExpenseFlowFilter>(
                      value: ExpenseFlowFilter.expense,
                      child: Text(_t('Expenses', fr: 'Depenses')),
                    ),
                    DropdownMenuItem<ExpenseFlowFilter>(
                      value: ExpenseFlowFilter.income,
                      child: Text(_t('Income', fr: 'Revenu')),
                    ),
                    DropdownMenuItem<ExpenseFlowFilter>(
                      value: ExpenseFlowFilter.transfer,
                      child: Text(_t('Transfers', fr: 'Transferts')),
                    ),
                  ],
                  onChanged: (ExpenseFlowFilter? value) {
                    if (value != null) {
                      setState(() => _flow = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _categoryToken,
                  decoration: InputDecoration(
                    hintText: _t('Category', fr: 'Categorie'),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: '',
                      child: Text(
                        _t('All categories', fr: 'Toutes les categories'),
                      ),
                    ),
                    ...ExpenseCategory.values.map(
                      (ExpenseCategory category) => DropdownMenuItem<String>(
                        value: 'cat:${category.key}',
                        child: Text(category.localizedLabel(widget.localeCode)),
                      ),
                    ),
                    ...widget.customCategories.map(
                      (CustomCategory customCategory) =>
                          DropdownMenuItem<String>(
                            value: 'custom:${customCategory.id}',
                            child: Text(customCategory.name),
                          ),
                    ),
                  ],
                  onChanged: (String? value) {
                    setState(() => _categoryToken = value ?? '');
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _minController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: _t('Min amount', fr: 'Montant min'),
                          prefixIcon: Icon(Icons.south_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _maxController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: _t('Max amount', fr: 'Montant max'),
                          prefixIcon: Icon(Icons.north_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ExpenseSortOrder>(
                  initialValue: _sortOrder,
                  decoration: InputDecoration(
                    hintText: _t('Sort by', fr: 'Trier par'),
                    prefixIcon: Icon(Icons.sort_rounded),
                  ),
                  items: <DropdownMenuItem<ExpenseSortOrder>>[
                    DropdownMenuItem<ExpenseSortOrder>(
                      value: ExpenseSortOrder.dateDesc,
                      child: Text(
                        _t(
                          'Date (newest first)',
                          fr: 'Date (plus recent d abord)',
                        ),
                      ),
                    ),
                    DropdownMenuItem<ExpenseSortOrder>(
                      value: ExpenseSortOrder.dateAsc,
                      child: Text(
                        _t(
                          'Date (oldest first)',
                          fr: 'Date (plus ancien d abord)',
                        ),
                      ),
                    ),
                    DropdownMenuItem<ExpenseSortOrder>(
                      value: ExpenseSortOrder.amountDesc,
                      child: Text(
                        _t(
                          'Amount (highest first)',
                          fr: 'Montant (plus eleve d abord)',
                        ),
                      ),
                    ),
                    DropdownMenuItem<ExpenseSortOrder>(
                      value: ExpenseSortOrder.amountAsc,
                      child: Text(
                        _t(
                          'Amount (lowest first)',
                          fr: 'Montant (plus faible d abord)',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (ExpenseSortOrder? value) {
                    if (value != null) {
                      setState(() => _sortOrder = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _dateTile(
                  icon: Icons.date_range_rounded,
                  title: _t('Start date', fr: 'Date de debut'),
                  value: _startDate,
                  onClear: _startDate == null
                      ? null
                      : () => setState(() => _startDate = null),
                  onTap: () => _pickDate(isStart: true),
                ),
                _dateTile(
                  icon: Icons.event_rounded,
                  title: _t('End date', fr: 'Date de fin'),
                  value: _endDate,
                  onClear: _endDate == null
                      ? null
                      : () => setState(() => _endDate = null),
                  onTap: () => _pickDate(isStart: false),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearAll,
                        child: Text(_t('Clear', fr: 'Effacer')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _apply,
                        child: Text(_t('Apply', fr: 'Appliquer')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTile({
    required IconData icon,
    required String title,
    required DateTime? value,
    required VoidCallback? onClear,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        value == null
            ? _t('Any', fr: 'N importe')
            : DateUtilsX.short(value, localeCode: widget.localeCode),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final DateTime firstDate = isStart
        ? DateTime(2018)
        : (_startDate ?? DateTime(2018));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  void _clearAll() {
    setState(() {
      _searchController.clear();
      _minController.clear();
      _maxController.clear();
      _selectedAccountId = null;
      _startDate = null;
      _endDate = null;
      _flow = ExpenseFlowFilter.all;
      _categoryToken = '';
      _sortOrder = ExpenseSortOrder.dateDesc;
    });
  }

  void _apply() {
    final double? minAmount = _parseAmount(_minController.text);
    final double? maxAmount = _parseAmount(_maxController.text);

    String? categoryKey;
    String? customCategoryId;
    if (_categoryToken.startsWith('cat:')) {
      categoryKey = _categoryToken.substring(4);
    } else if (_categoryToken.startsWith('custom:')) {
      customCategoryId = _categoryToken.substring(7);
    }

    Navigator.of(context).pop(
      ExpenseAdvancedFilter(
        searchQuery: _searchController.text.trim(),
        accountId: _selectedAccountId,
        startDate: _startDate,
        endDate: _endDate,
        flow: _flow,
        categoryKey: categoryKey,
        customCategoryId: customCategoryId,
        minAmount: minAmount,
        maxAmount: maxAmount,
        sortOrder: _sortOrder,
      ),
    );
  }

  double? _parseAmount(String raw) {
    final String normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    final double? value = double.tryParse(normalized);
    if (value == null || value < 0) {
      return null;
    }
    return value;
  }
}

