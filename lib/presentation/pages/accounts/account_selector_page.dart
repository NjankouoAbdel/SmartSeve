import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_constants.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/services/home_widget_service.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/icon_utils.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/domain/entities/bank_account.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/shell/main_shell_page.dart';

class AccountSelectorPage extends StatefulWidget {
  const AccountSelectorPage({
    super.key,
    this.initialQuickAction,
    this.switchMode = false,
  });

  final HomeWidgetQuickAction? initialQuickAction;
  final bool switchMode;

  @override
  State<AccountSelectorPage> createState() => _AccountSelectorPageState();
}

class _AccountSelectorPageState extends State<AccountSelectorPage> {
  bool _navigating = false;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  String _ta(String english, Map<String, String> args, {String? fr}) {
    return context.l10n.phraseWithArgs(english, args, french: fr);
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final ExpenseController expenses = context.watch<ExpenseController>();

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _header(context),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  itemCount: settings.bankAccounts.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final BankAccount account = settings.bankAccounts[index];
                    return _accountCard(
                      context: context,
                      settings: settings,
                      expenses: expenses,
                      account: account,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: <Widget>[
          if (widget.switchMode)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: widget.switchMode
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  widget.switchMode
                      ? _t('Switch Wallet', fr: 'Changer de portefeuille')
                      : _t(
                          'Select Your Wallet',
                          fr: 'Selectionnez votre portefeuille',
                        ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _t(
                    'Choose an account to continue',
                    fr: 'Choisissez un compte pour continuer',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _accountCard({
    required BuildContext context,
    required SettingsController settings,
    required ExpenseController expenses,
    required BankAccount account,
  }) {
    final bool selected = account.id == settings.activeBankAccountId;
    final _AccountStats stats = _buildStats(
      expenseController: expenses,
      accountId: account.id,
    );
    final Color brand = Color(account.colorValue);
    final Color darkBrand = _darken(brand, 0.28);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _navigating ? null : () => _selectAccount(settings, account.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              darkBrand.withValues(alpha: 0.95),
              brand.withValues(alpha: 0.82),
            ],
          ),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.20),
            width: selected ? 1.4 : 1.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  child: Icon(
                    AppIconUtils.fromCodePoint(
                      account.iconCodePoint,
                      fallback: Icons.account_balance_wallet_rounded,
                    ),
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        settings.displayBankAccountName(account),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        settings.displayBankAccountInstitution(account),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _t('ACTIVE', fr: 'ACTIF'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              CurrencyUtils.formatAmount(
                stats.netBalance,
                settings.currencyCode,
              ),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _t('Current net balance', fr: 'Solde net actuel'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                _metric(
                  _t('Monthly spend', fr: 'Depense mensuelle'),
                  stats.monthlySpend,
                  settings.currencyCode,
                ),
                const SizedBox(width: 8),
                _metric(
                  _t('Monthly income', fr: 'Revenu mensuel'),
                  stats.monthlyIncome,
                  settings.currencyCode,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _ta(
                'Reference: {ref} • {count} transactions',
                <String, String>{
                  'ref': _referenceLabel(settings, account),
                  'count': '${stats.transactionCount}',
                },
                fr: 'Reference : {ref} • {count} transactions',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, double value, String currencyCode) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFDCE7F8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyUtils.formatAmount(value, currencyCode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAccount(
    SettingsController settings,
    String accountId,
  ) async {
    if (_navigating) {
      return;
    }
    setState(() => _navigating = true);
    await settings.setActiveBankAccount(accountId);
    if (!mounted) {
      return;
    }
    if (widget.switchMode) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushReplacement(
      AppRouter.slideFade(
        MainShellPage(initialQuickAction: widget.initialQuickAction),
      ),
    );
  }

  _AccountStats _buildStats({
    required ExpenseController expenseController,
    required String accountId,
  }) {
    final List<Expense> accountExpenses = expenseController.expensesForAccount(
      accountId,
    );
    final DateTime now = DateTime.now();
    final double netBalance = accountExpenses.fold<double>(
      0,
      (double sum, Expense expense) => sum - expense.amount,
    );
    final double monthlySpend = accountExpenses
        .where(
          (Expense expense) =>
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.amount > 0 &&
              !expense.isTransfer,
        )
        .fold<double>(0, (double sum, Expense expense) => sum + expense.amount);
    final double monthlyIncome = accountExpenses
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
    return _AccountStats(
      netBalance: netBalance,
      monthlySpend: monthlySpend,
      monthlyIncome: monthlyIncome,
      transactionCount: accountExpenses.length,
    );
  }

  String _shortReference(String accountId) {
    final String normalized = accountId.trim().toUpperCase();
    if (normalized.length <= 8) {
      return normalized;
    }
    return normalized.substring(normalized.length - 8);
  }

  String _referenceLabel(SettingsController settings, BankAccount account) {
    if (account.id == AppConstants.defaultBankAccountId) {
      return settings.displayBankAccountName(account);
    }
    return _shortReference(account.id);
  }

  Color _darken(Color color, double amount) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final double lightness = max(0, hsl.lightness - amount);
    return hsl.withLightness(lightness).toColor();
  }
}

class _AccountStats {
  const _AccountStats({
    required this.netBalance,
    required this.monthlySpend,
    required this.monthlyIncome,
    required this.transactionCount,
  });

  final double netBalance;
  final double monthlySpend;
  final double monthlyIncome;
  final int transactionCount;
}

