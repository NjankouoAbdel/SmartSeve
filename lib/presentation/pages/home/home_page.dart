import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';
import 'package:wfer_flousk_firebase/core/services/home_widget_service.dart';
import 'package:wfer_flousk_firebase/core/utils/date_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/icon_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/responsive_utils.dart';
import 'package:wfer_flousk_firebase/domain/entities/bank_account.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/accounts/account_selector_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/pro/pro_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/settings/settings_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/tools/tools_center_page.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/app_logo.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.onQuickAddTap,
    super.key,
    this.previewMode = false,
    this.quickActionTrigger,
    this.onQuickActionConsumed,
  });

  final VoidCallback onQuickAddTap;
  final bool previewMode;
  final HomeWidgetQuickActionTrigger? quickActionTrigger;
  final ValueChanged<int>? onQuickActionConsumed;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _animateIn = false;
  int? _handledQuickActionRequestId;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  String _ta(String english, Map<String, String> args, {String? fr}) {
    return context.l10n.phraseWithArgs(english, args, french: fr);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _animateIn = true);
      }
      _consumeWidgetQuickActionIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quickActionTrigger?.requestId !=
        oldWidget.quickActionTrigger?.requestId) {
      _consumeWidgetQuickActionIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseController expenseController = context
        .watch<ExpenseController>();
    final SettingsController settings = context.watch<SettingsController>();

    if (expenseController.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final String activeAccountId = settings.activeBankAccountId;
    final List<Expense> accountExpenses = expenseController.expensesForAccount(
      activeAccountId,
    );

    final double plannedMonthlyIncome = settings.monthlyIncome;
    final double addedMonthlyIncome = expenseController
        .monthlyIncomeTransactionsForAccount(activeAccountId);
    final double monthlyIncome = plannedMonthlyIncome + addedMonthlyIncome;
    final double monthlySpending = expenseController.monthlySpendingForAccount(
      activeAccountId,
    );
    final double totalBalance = monthlyIncome - monthlySpending;

    final Map<String, double> weekly = expenseController
        .weeklyComparisonForAccount(activeAccountId);
    final double currentWeek = weekly['Current Week'] ?? 0;
    final double previousWeek = weekly['Previous Week'] ?? 0;
    final double percentageChange = previousWeek <= 0
        ? 12
        : ((previousWeek - currentWeek) / previousWeek * 100);

    final List<double> sparklinePoints = _buildSparklinePoints(
      currentWeek: currentWeek,
      previousWeek: previousWeek,
    );

    final List<DashboardTransactionPreview> transactions =
        _buildDashboardTransactions(
          expenses: accountExpenses,
          localeCode: settings.localeCode,
          previewMode: widget.previewMode,
        );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: <double>[0, 0.52, 1],
                colors: <Color>[
                  Color(0xFF0D1B2A),
                  Color(0xFF0F2233),
                  Color(0xFF0B0F14),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      const Color(0xFF42A5F5).withValues(alpha: 0.10),
                      const Color(0xFF42A5F5).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveUtils.maxContentWidth(context),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double height = constraints.maxHeight;
                final bool compact = height < 760;
                final bool veryCompact = height < 650;

                final double topPadding = veryCompact ? 10 : 14;
                final double heroOuter = veryCompact ? 80 : (compact ? 86 : 92);
                final double heroIcon = veryCompact ? 60 : (compact ? 66 : 72);
                final double balanceHeight = veryCompact
                    ? 132
                    : (compact ? 142 : 150);
                final double actionsHeight = veryCompact ? 74 : 78;
                final double sectionGap = veryCompact ? 12 : 18;
                final double transactionHeight =
                    (height * (veryCompact ? 0.32 : 0.36)).clamp(210.0, 360.0);

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topPadding, 20, 10),
                    child: Column(
                      children: <Widget>[
                        _AnimatedStagger(
                          animate: _animateIn,
                          index: 0,
                          child: _topBar(context),
                        ),
                        SizedBox(height: veryCompact ? 8 : 12),
                        _AnimatedStagger(
                          animate: _animateIn,
                          index: 1,
                          child: _accountSwitcher(context, settings),
                        ),
                        SizedBox(height: veryCompact ? 10 : 14),
                        _heroArea(
                          context,
                          outerSize: heroOuter,
                          iconSize: heroIcon,
                          compact: compact,
                          fullName: settings.userFullName,
                        ),
                        SizedBox(height: sectionGap),
                        _AnimatedStagger(
                          animate: _animateIn,
                          index: 2,
                          child: _balanceCard(
                            context,
                            totalBalance: totalBalance,
                            percentageChange: percentageChange,
                            currencyCode: settings.currencyCode,
                            sparklinePoints: sparklinePoints,
                            cardHeight: balanceHeight,
                            compact: compact,
                          ),
                        ),
                        SizedBox(height: veryCompact ? 10 : 16),
                        _AnimatedStagger(
                          animate: _animateIn,
                          index: 3,
                          child: _quickActions(
                            context,
                            settings,
                            tileHeight: actionsHeight,
                            compact: compact,
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        _AnimatedStagger(
                          animate: _animateIn,
                          index: 4,
                          child: _recentTransactions(
                            context,
                            currencyCode: settings.currencyCode,
                            localeCode: settings.localeCode,
                            transactions: transactions,
                            listHeight: transactionHeight,
                            compact: compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _consumeWidgetQuickActionIfNeeded() {
    final HomeWidgetQuickActionTrigger? trigger = widget.quickActionTrigger;
    if (trigger == null) {
      return;
    }
    if (_handledQuickActionRequestId == trigger.requestId) {
      return;
    }
    _handledQuickActionRequestId = trigger.requestId;
    widget.onQuickActionConsumed?.call(trigger.requestId);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final SettingsController settings = context.read<SettingsController>();
      switch (trigger.action) {
        case HomeWidgetQuickAction.openApp:
          break;
        case HomeWidgetQuickAction.addExpense:
          widget.onQuickAddTap();
          break;
        case HomeWidgetQuickAction.addIncome:
          await _showAddIncomeDialog(context, settings);
          break;
        case HomeWidgetQuickAction.addTransfer:
          if (settings.bankAccounts.length < 2) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _t(
                    'Add at least two accounts to transfer funds.',
                    fr: 'Ajoutez au moins deux comptes pour transferer des fonds.',
                  ),
                ),
              ),
            );
            return;
          }
          await _showTransferDialog(context, settings);
          break;
      }
    });
  }

  Widget _topBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          _notificationsButton(context),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'SMART SAVE',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.90),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                onPressed: _openAccountSelector,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 21,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
                tooltip: _t('Switch wallet', fr: 'Changer de portefeuille'),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(AppRouter.slideFade(const SettingsPage()));
                },
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  Icons.settings_outlined,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                tooltip: _t('Settings', fr: 'Parametres'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notificationsButton(BuildContext context) {
    return Consumer<ToolsController>(
      builder:
          (
            BuildContext context,
            ToolsController toolsController,
            Widget? child,
          ) {
            final int unread = toolsController.unreadNoticeCount;
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF142A3F),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        Navigator.of(context).push(
                          AppRouter.slideFade(
                            const ToolsCenterPage(initialTab: 1),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.notifications_active_outlined,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.80),
                      ),
                    ),
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
    );
  }

  Widget _accountSwitcher(BuildContext context, SettingsController settings) {
    final BankAccount activeAccount = settings.activeBankAccount;
    final bool canTransfer = settings.bankAccounts.length > 1;
    return SizedBox(
      height: 52,
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _openAccountSelector,
              onLongPress: () =>
                  _showEditAccountDialog(context, settings, activeAccount),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF13293D),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      AppIconUtils.fromCodePoint(
                        activeAccount.iconCodePoint,
                        fallback: Icons.account_balance_wallet_rounded,
                      ),
                      size: 18,
                      color: Color(activeAccount.colorValue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            settings.displayBankAccountName(activeAccount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            settings.displayBankAccountInstitution(
                              activeAccount,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.64),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (canTransfer) ...<Widget>[
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showTransferDialog(context, settings),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF13293D),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFF42A5F5),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showAddAccountDialog(context, settings),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF13293D),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFF42A5F5)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAccountSelector() async {
    await Navigator.of(
      context,
    ).push(AppRouter.slideFade(const AccountSelectorPage(switchMode: true)));
  }

  List<IconData> get _accountIconOptions => <IconData>[
    Icons.account_balance_wallet_rounded,
    Icons.credit_card_rounded,
    Icons.savings_rounded,
    Icons.account_balance_rounded,
    Icons.currency_exchange_rounded,
    Icons.payments_rounded,
    Icons.work_rounded,
    Icons.star_rounded,
  ];

  List<int> get _accountColorOptions => <int>[
    0xFF42A5F5,
    0xFF1E88E5,
    0xFF26A69A,
    0xFF7E57C2,
    0xFFEF5350,
    0xFFFFA726,
    0xFF66BB6A,
    0xFF90CAF9,
  ];

  Future<void> _showAddAccountDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    String name = '';
    String institution = '';
    IconData selectedIcon = Icons.account_balance_wallet_rounded;
    int selectedColorValue = 0xFF42A5F5;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  title: Text(
                    _t('Add New Bank Account', fr: 'Ajouter un nouveau compte'),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(
                          onChanged: (String value) => name = value,
                          decoration: InputDecoration(
                            hintText: _t(
                              'Card / Wallet name',
                              fr: 'Nom de la carte / portefeuille',
                            ),
                            prefixIcon: Icon(Icons.credit_card_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          onChanged: (String value) => institution = value,
                          decoration: InputDecoration(
                            hintText: _t(
                              'Institution (Revolut, HelloBank...)',
                              fr: 'Institution (Revolut, HelloBank...)',
                            ),
                            prefixIcon: Icon(Icons.account_balance_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _iconPickerRow(
                          selected: selectedIcon,
                          onSelect: (IconData icon) {
                            setDialogState(() => selectedIcon = icon);
                          },
                        ),
                        const SizedBox(height: 10),
                        _colorPickerRow(
                          selectedColorValue: selectedColorValue,
                          onSelect: (int colorValue) {
                            setDialogState(
                              () => selectedColorValue = colorValue,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(_t('Cancel', fr: 'Annuler')),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (name.trim().isEmpty) {
                          return;
                        }
                        final bool added = await settings.addBankAccount(
                          name: name.trim(),
                          institution: institution.trim(),
                          iconCodePoint: selectedIcon.codePoint,
                          colorValue: selectedColorValue,
                        );
                        if (!added) {
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          if (!mounted) {
                            return;
                          }
                          await _showWalletLimitProGate(context);
                          return;
                        }
                        if (!dialogContext.mounted) {
                          return;
                        }
                        Navigator.of(dialogContext).pop();
                      },
                      child: Text(_t('Add', fr: 'Ajouter')),
                    ),
                  ],
                );
              },
        );
      },
    );
  }

  Future<void> _showEditAccountDialog(
    BuildContext context,
    SettingsController settings,
    BankAccount account,
  ) async {
    String name = settings.displayBankAccountName(account);
    String institution = settings.displayBankAccountInstitution(account);
    IconData selectedIcon = AppIconUtils.fromCodePoint(
      account.iconCodePoint,
      fallback: Icons.account_balance_wallet_rounded,
    );
    int selectedColorValue = account.colorValue;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  title: Text(_t('Edit Account', fr: 'Modifier compte')),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(
                          initialValue: name,
                          onChanged: (String value) => name = value,
                          decoration: InputDecoration(
                            hintText: _t('Account name', fr: 'Nom du compte'),
                            prefixIcon: Icon(Icons.credit_card_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          initialValue: institution,
                          onChanged: (String value) => institution = value,
                          decoration: InputDecoration(
                            hintText: _t('Institution', fr: 'Institution'),
                            prefixIcon: Icon(Icons.account_balance_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _iconPickerRow(
                          selected: selectedIcon,
                          onSelect: (IconData icon) {
                            setDialogState(() => selectedIcon = icon);
                          },
                        ),
                        const SizedBox(height: 10),
                        _colorPickerRow(
                          selectedColorValue: selectedColorValue,
                          onSelect: (int colorValue) {
                            setDialogState(
                              () => selectedColorValue = colorValue,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    if (settings.bankAccounts.length > 1)
                      TextButton(
                        onPressed: () async {
                          await settings.removeBankAccount(account.id);
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(_t('Delete', fr: 'Supprimer')),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(_t('Cancel', fr: 'Annuler')),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (name.trim().isEmpty) {
                          return;
                        }
                        await settings.updateBankAccount(
                          BankAccount(
                            id: account.id,
                            name: name.trim(),
                            institution: institution.trim().isEmpty
                                ? settings.localizedBankLabel
                                : institution.trim(),
                            createdAt: account.createdAt,
                            iconCodePoint: selectedIcon.codePoint,
                            colorValue: selectedColorValue,
                          ),
                        );
                        if (!dialogContext.mounted) {
                          return;
                        }
                        Navigator.of(dialogContext).pop();
                      },
                      child: Text(_t('Save', fr: 'Enregistrer')),
                    ),
                  ],
                );
              },
        );
      },
    );
  }

  Future<void> _showTransferDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    final List<BankAccount> accounts = settings.bankAccounts;
    if (accounts.length < 2) {
      return;
    }

    String fromAccountId = settings.activeBankAccountId;
    String toAccountId = accounts
        .firstWhere((BankAccount a) => a.id != fromAccountId)
        .id;
    String amountInput = '';
    String noteInput = '';

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  title: Text(
                    _t(
                      'Transfer Between Accounts',
                      fr: 'Transferer entre comptes',
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          initialValue: fromAccountId,
                          decoration: InputDecoration(
                            hintText: _t(
                              'From account',
                              fr: 'Depuis le compte',
                            ),
                            prefixIcon: Icon(Icons.call_made_rounded),
                          ),
                          items: accounts
                              .map(
                                (BankAccount account) =>
                                    DropdownMenuItem<String>(
                                      value: account.id,
                                      child: Text(
                                        settings.displayBankAccountName(
                                          account,
                                        ),
                                      ),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (String? value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              fromAccountId = value;
                              if (toAccountId == fromAccountId) {
                                toAccountId = accounts
                                    .firstWhere(
                                      (BankAccount account) =>
                                          account.id != value,
                                    )
                                    .id;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: toAccountId,
                          decoration: InputDecoration(
                            hintText: _t('To account', fr: 'Vers le compte'),
                            prefixIcon: Icon(Icons.call_received_rounded),
                          ),
                          items: accounts
                              .where(
                                (BankAccount account) =>
                                    account.id != fromAccountId,
                              )
                              .map(
                                (BankAccount account) =>
                                    DropdownMenuItem<String>(
                                      value: account.id,
                                      child: Text(
                                        settings.displayBankAccountName(
                                          account,
                                        ),
                                      ),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (String? value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() => toAccountId = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (String value) => amountInput = value,
                          decoration: InputDecoration(
                            hintText: _t('Amount', fr: 'Montant'),
                            prefixIcon: Icon(Icons.payments_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          onChanged: (String value) => noteInput = value,
                          decoration: InputDecoration(
                            hintText: _t(
                              'Note (optional)',
                              fr: 'Note (optionnelle)',
                            ),
                            prefixIcon: Icon(Icons.edit_note_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(_t('Cancel', fr: 'Annuler')),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final double amount =
                            double.tryParse(
                              amountInput.trim().replaceAll(',', '.'),
                            ) ??
                            0;
                        if (amount <= 0 || fromAccountId == toAccountId) {
                          return;
                        }

                        final ExpenseController expenseController = context
                            .read<ExpenseController>();
                        final ToolsController toolsController = context
                            .read<ToolsController>();

                        final BankAccount fromAccount = accounts.firstWhere(
                          (BankAccount account) => account.id == fromAccountId,
                        );
                        final BankAccount toAccount = accounts.firstWhere(
                          (BankAccount account) => account.id == toAccountId,
                        );

                        final String transferId = const Uuid().v4();
                        final String noteBase = noteInput.trim();
                        final String toAccountName = settings
                            .displayBankAccountName(toAccount);
                        final String fromAccountName = settings
                            .displayBankAccountName(fromAccount);
                        final String sourceNote = noteBase.isEmpty
                            ? _ta(
                                'Transfer to {target}',
                                <String, String>{'target': toAccountName},
                                fr: 'Transfert vers {target}',
                              )
                            : '$noteBase -> $toAccountName';
                        final String targetNote = noteBase.isEmpty
                            ? _ta(
                                'Transfer from {source}',
                                <String, String>{'source': fromAccountName},
                                fr: 'Transfert depuis {source}',
                              )
                            : '$noteBase <- $fromAccountName';

                        final List<Expense> transferEntries = <Expense>[
                          Expense(
                            id: const Uuid().v4(),
                            amount: amount,
                            category: ExpenseCategory.other,
                            date: DateTime.now(),
                            note: sourceNote,
                            currencyCode: settings.currencyCode,
                            accountId: fromAccount.id,
                            isTransfer: true,
                            transferGroupId: transferId,
                          ),
                          Expense(
                            id: const Uuid().v4(),
                            amount: -amount,
                            category: ExpenseCategory.other,
                            date: DateTime.now(),
                            note: targetNote,
                            currencyCode: settings.currencyCode,
                            accountId: toAccount.id,
                            isTransfer: true,
                            transferGroupId: transferId,
                          ),
                        ];

                        await expenseController.addExpensesBulk(
                          transferEntries,
                        );
                        await toolsController.evaluateBudgets(
                          expenses: expenseController.expensesForAccount(
                            settings.activeBankAccountId,
                          ),
                          currencyCode: settings.currencyCode,
                        );

                        if (!dialogContext.mounted) {
                          return;
                        }
                        Navigator.of(dialogContext).pop();
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _ta(
                                'Transferred {amount} {currency} between accounts.',
                                <String, String>{
                                  'amount': amount.toStringAsFixed(2),
                                  'currency': settings.currencyCode,
                                },
                                fr: 'Transfert de {amount} {currency} entre comptes.',
                              ),
                            ),
                          ),
                        );
                      },
                      child: Text(_t('Transfer', fr: 'Transferer')),
                    ),
                  ],
                );
              },
        );
      },
    );
  }

  Widget _iconPickerRow({
    required IconData selected,
    required ValueChanged<IconData> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _accountIconOptions
          .map((IconData icon) {
            final bool isSelected = icon.codePoint == selected.codePoint;
            return GestureDetector(
              onTap: () => onSelect(icon),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF42A5F5).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF42A5F5)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _colorPickerRow({
    required int selectedColorValue,
    required ValueChanged<int> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _accountColorOptions
          .map((int value) {
            final bool isSelected = value == selectedColorValue;
            return GestureDetector(
              onTap: () => onSelect(value),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _heroArea(
    BuildContext context, {
    required double outerSize,
    required double iconSize,
    required bool compact,
    required String fullName,
  }) {
    return Column(
      children: <Widget>[
        AnimatedOpacity(
          opacity: _animateIn ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: _animateIn ? 1 : 0.88,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Container(
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF142A3F),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.20),
                    blurRadius: 25,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: AppLogo(size: iconSize, heroTag: null),
            ),
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
          child: Column(
            children: <Widget>[
              Text(
                fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.96),
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _t(
                  'Track your spending and stay in control',
                  fr: 'Suivez vos depenses et gardez le controle',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: compact ? 11 : 12,
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _balanceCard(
    BuildContext context, {
    required double totalBalance,
    required double percentageChange,
    required String currencyCode,
    required List<double> sparklinePoints,
    required double cardHeight,
    required bool compact,
  }) {
    return SizedBox(
      width: double.infinity,
      child: PremiumCard(
        borderRadius: 26,
        padding: EdgeInsets.all(compact ? 16 : 20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0D47A1), Color(0xFF1565C0)],
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: CustomPaint(painter: _BalanceWavePainter()),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _t('Total Balance', fr: 'Solde total'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.arrow_upward_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${percentageChange >= 0 ? '+' : ''}${percentageChange.abs().toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${NumberFormat('#,##0.00').format(totalBalance)} $currencyCode',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: compact ? 28 : 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: compact ? 10 : 14),
                Row(
                  children: <Widget>[
                    Text(
                      _t('Updated just now', fr: 'Mis a jour a l instant'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                    const Spacer(),
                    _MiniSparkline(
                      points: sparklinePoints,
                      width: compact ? 78 : 90,
                      height: compact ? 24 : 28,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(
    BuildContext context,
    SettingsController settings, {
    required double tileHeight,
    required bool compact,
  }) {
    final List<Widget> tiles = <Widget>[
      ActionTile(
        icon: Icons.add_circle_rounded,
        label: _t('Add Expense', fr: 'Ajouter depense'),
        onTap: widget.onQuickAddTap,
        height: tileHeight,
      ),
      ActionTile(
        icon: Icons.trending_up_rounded,
        label: _t('Add Income', fr: 'Ajouter revenu'),
        onTap: () => _showAddIncomeDialog(context, settings),
        height: tileHeight,
      ),
      ActionTile(
        icon: Icons.document_scanner_rounded,
        label: _t('Scan Receipt', fr: 'Scanner recu'),
        onTap: () => _scanReceiptFromHome(context),
        height: tileHeight,
      ),
      ActionTile(
        icon: Icons.pie_chart_rounded,
        label: _t('Set Budget', fr: 'Definir budget'),
        onTap: () {
          Navigator.of(
            context,
          ).push(AppRouter.slideFade(const ToolsCenterPage(initialTab: 0)));
        },
        height: tileHeight,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              _t('Quick Actions', fr: 'Actions rapides'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  AppRouter.slideFade(const ToolsCenterPage(initialTab: 0)),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(52, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _t('See all', fr: 'Voir tout'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: compact ? 12 : 13,
                  color: const Color(0xFF64B5F6),
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(
                    0xFF64B5F6,
                  ).withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth < 360) {
              final double itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiles
                    .map(
                      (Widget tile) => SizedBox(width: itemWidth, child: tile),
                    )
                    .toList(growable: false),
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: tiles[0]),
                const SizedBox(width: 10),
                Expanded(child: tiles[1]),
                const SizedBox(width: 10),
                Expanded(child: tiles[2]),
                const SizedBox(width: 10),
                Expanded(child: tiles[3]),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _recentTransactions(
    BuildContext context, {
    required List<DashboardTransactionPreview> transactions,
    required String currencyCode,
    required String localeCode,
    required double listHeight,
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _t('Recent Transactions', fr: 'Transactions recentes'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        SizedBox(
          height: listHeight,
          child: PremiumCard(
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: transactions.isEmpty
                ? _emptyTransactions(context)
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: max(4, transactions.length),
                    separatorBuilder: (_, int index) {
                      if (index >= transactions.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(left: 72),
                        child: Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      );
                    },
                    itemBuilder: (BuildContext context, int index) {
                      if (index >= transactions.length) {
                        return const SizedBox(height: 8);
                      }
                      return _AnimatedStagger(
                        animate: _animateIn,
                        index: 4 + index,
                        child: TransactionRow(
                          transaction: transactions[index],
                          currencyCode: currencyCode,
                          localeCode: localeCode,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _emptyTransactions(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF142A3F),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF42A5F5),
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t('No transactions yet', fr: 'Aucune transaction pour le moment'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              'Add your first expense to see insights',
              fr: 'Ajoutez votre premiere depense pour voir des insights',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFFAAB4C3)),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: widget.onQuickAddTap,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF42A5F5),
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(_t('Add Expense', fr: 'Ajouter depense')),
          ),
        ],
      ),
    );
  }

  List<DashboardTransactionPreview> _buildDashboardTransactions({
    required List<Expense> expenses,
    required String localeCode,
    required bool previewMode,
  }) {
    if (previewMode) {
      return DashboardTransactionPreview.dummy();
    }

    final List<Expense> sorted = expenses.toList(growable: false)
      ..sort((Expense a, Expense b) => b.date.compareTo(a.date));

    return sorted
        .take(12)
        .map(
          (Expense e) => DashboardTransactionPreview.fromExpense(e, localeCode),
        )
        .toList(growable: false);
  }

  List<double> _buildSparklinePoints({
    required double currentWeek,
    required double previousWeek,
  }) {
    final List<double> base = <double>[
      max(previousWeek * 0.78, 30),
      max(previousWeek * 0.85, 45),
      max(previousWeek * 0.95, 60),
      max(currentWeek * 0.88, 50),
      max(currentWeek, 65),
      max(currentWeek * 1.05, 70),
    ];

    if (base.every((double v) => v <= 0)) {
      return const <double>[45, 62, 56, 70, 75, 84];
    }
    return base;
  }

  Future<void> _showAddIncomeDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    String amountInput = '';
    String noteInput = '';

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_t('Add Income', fr: 'Ajouter revenu')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                onChanged: (String value) {
                  amountInput = value;
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: _t('Income amount', fr: 'Montant du revenu'),
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                onChanged: (String value) {
                  noteInput = value;
                },
                decoration: InputDecoration(
                  hintText: _t(
                    'Source (Salary, Bonus...)',
                    fr: 'Source (Salaire, Prime...)',
                  ),
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t('Cancel', fr: 'Annuler')),
            ),
            ElevatedButton(
              onPressed: () async {
                final double value =
                    double.tryParse(amountInput.trim().replaceAll(',', '.')) ??
                    0;
                if (value <= 0) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _t(
                            'Please enter a valid income amount.',
                            fr: 'Veuillez entrer un montant de revenu valide.',
                          ),
                        ),
                      ),
                    );
                  }
                  return;
                }

                final ExpenseController expenses = context
                    .read<ExpenseController>();
                final ToolsController tools = context.read<ToolsController>();
                final Expense incomeExpense = Expense(
                  id: const Uuid().v4(),
                  amount: -value,
                  category: ExpenseCategory.other,
                  date: DateTime.now(),
                  note: noteInput.trim().isEmpty
                      ? _t('Income', fr: 'Revenu')
                      : noteInput.trim(),
                  currencyCode: settings.currencyCode,
                  accountId: settings.activeBankAccountId,
                );
                await expenses.addExpense(incomeExpense);
                await tools.evaluateSmartSavingPlan(
                  totalIncomeForMonth:
                      settings.monthlyIncome +
                      expenses.monthlyIncomeTransactionsForAccount(
                        settings.activeBankAccountId,
                      ),
                  savingsGoal: settings.monthlySavingsGoal,
                  spentForMonth: expenses.monthlySpendingForAccount(
                    settings.activeBankAccountId,
                  ),
                  currencyCode: settings.currencyCode,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _t(
                          'Income added successfully.',
                          fr: 'Revenu ajoute avec succes.',
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Text(_t('Save', fr: 'Enregistrer')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _scanReceiptFromHome(BuildContext context) async {
    final ToolsController tools = context.read<ToolsController>();
    final ExpenseController expenses = context.read<ExpenseController>();
    final SettingsController settings = context.read<SettingsController>();

    if (!settings.isPro) {
      await _showScanProGate(context);
      return;
    }

    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: <Widget>[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t(
                      'Opening camera scanner...',
                      fr: 'Ouverture du scanner camera...',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    final OcrScanResult? result = await tools.scanReceipt(ImageSource.camera);

    if (!context.mounted) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }

    if (result == null) {
      final String message =
          tools.lastOcrError ??
          _t(
            'Scan canceled. Allow permission and try again.',
            fr: 'Scan annule. Autorisez la permission et reessayez.',
          );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    await _showScannedExpenseDialog(
      context: context,
      result: result,
      expenseController: expenses,
      settings: settings,
      tools: tools,
    );
  }

  Future<void> _showScanProGate(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF13293D),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF42A5F5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _t('Scan Receipt is Pro', fr: 'Le scan de recu est Pro'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _t(
                  'Unlock Pro to scan receipts automatically and create expenses faster.',
                  fr: 'Debloquez Pro pour scanner les recus automatiquement et creer des depenses plus vite.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFAAB4C3),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).push(AppRouter.slideFade(const ProPage()));
                    });
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(_t('Upgrade to Pro', fr: 'Passer a Pro')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showWalletLimitProGate(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF13293D),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF42A5F5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _t('More Wallets = Pro', fr: 'Plus de portefeuilles = Pro'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _t(
                  'Free plan supports up to 2 wallets. Upgrade to Pro to add unlimited wallets.',
                  fr: 'Le plan gratuit prend en charge jusqu a 2 portefeuilles. Passez a Pro pour en ajouter en illimite.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFAAB4C3),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).push(AppRouter.slideFade(const ProPage()));
                    });
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(_t('Upgrade to Pro', fr: 'Passer a Pro')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showScannedExpenseDialog({
    required BuildContext context,
    required OcrScanResult result,
    required ExpenseController expenseController,
    required SettingsController settings,
    required ToolsController tools,
  }) async {
    ExpenseCategory selectedCategory = ExpenseCategory.other;
    String amountInput = result.amount?.toStringAsFixed(2) ?? '';
    String noteInput = result.suggestedNote;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _t('Scan Receipt Result', fr: 'Resultat du scan de recu'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  initialValue: amountInput,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (String value) {
                    amountInput = value;
                  },
                  decoration: InputDecoration(
                    hintText: _t('Amount', fr: 'Montant'),
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: selectedCategory,
                  items: ExpenseCategory.values
                      .map(
                        (ExpenseCategory category) =>
                            DropdownMenuItem<ExpenseCategory>(
                              value: category,
                              child: Text(
                                category.localizedLabel(settings.localeCode),
                              ),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (ExpenseCategory? value) {
                    if (value != null) {
                      selectedCategory = value;
                    }
                  },
                  decoration: InputDecoration(
                    hintText: _t('Category', fr: 'Categorie'),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: noteInput,
                  onChanged: (String value) {
                    noteInput = value;
                  },
                  decoration: InputDecoration(
                    hintText: _t('Note', fr: 'Note'),
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t('Cancel', fr: 'Annuler')),
            ),
            ElevatedButton(
              onPressed: () async {
                final double amount =
                    double.tryParse(amountInput.trim().replaceAll(',', '.')) ??
                    0;
                if (amount <= 0) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _t(
                            'Please enter a valid amount.',
                            fr: 'Veuillez entrer un montant valide.',
                          ),
                        ),
                      ),
                    );
                  }
                  return;
                }

                final Expense expense = Expense(
                  id: const Uuid().v4(),
                  amount: amount,
                  category: selectedCategory,
                  date: result.date ?? DateTime.now(),
                  note: noteInput.trim().isEmpty
                      ? _t('Scanned receipt', fr: 'Recu scanne')
                      : noteInput.trim(),
                  currencyCode: settings.currencyCode,
                  accountId: settings.activeBankAccountId,
                );

                await expenseController.addExpense(expense);
                await tools.evaluateBudgets(
                  expenses: expenseController.expensesForAccount(
                    settings.activeBankAccountId,
                  ),
                  currencyCode: settings.currencyCode,
                );
                await tools.evaluateSmartSavingPlan(
                  totalIncomeForMonth:
                      settings.monthlyIncome +
                      expenseController.monthlyIncomeTransactionsForAccount(
                        settings.activeBankAccountId,
                      ),
                  savingsGoal: settings.monthlySavingsGoal,
                  spentForMonth: expenseController.monthlySpendingForAccount(
                    settings.activeBankAccountId,
                  ),
                  currencyCode: settings.currencyCode,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _t(
                          'Expense added from scanned receipt.',
                          fr: 'Depense ajoutee depuis le recu scanne.',
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Text(_t('Save', fr: 'Enregistrer')),
            ),
          ],
        );
      },
    );
  }
}

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 22,
    this.gradient,
    this.color = const Color(0xFF13293D),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Gradient? gradient;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class ActionTile extends StatefulWidget {
  const ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.height,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          height: widget.height,
          child: PremiumCard(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF142A3F),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: const Color(0xFF42A5F5),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 14,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.l10n.phrase(widget.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.0,
                        color: Colors.white.withValues(alpha: 0.90),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    required this.transaction,
    required this.currencyCode,
    required this.localeCode,
    super.key,
  });

  final DashboardTransactionPreview transaction;
  final String currencyCode;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = transaction.type == DashboardTransactionType.income;
    final Color amountColor = transaction.isTransfer
        ? const Color(0xFF42A5F5)
        : (isIncome ? const Color(0xFF4CAF50) : const Color(0xFFFF5252));
    final String amountText =
        '${isIncome ? '+' : '-'} ${NumberFormat('#,##0.00').format(transaction.amount.abs())} $currencyCode';

    return SizedBox(
      height: 66,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF142A3F),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(
                _iconForTransaction(transaction),
                color: _colorForTransaction(transaction),
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    transaction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(context, transaction.date, localeCode),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: const Color(0xFFAAB4C3),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      amountText,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: amountColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.phrase(transaction.paymentMethod),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: const Color(0xFFAAB4C3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForTransaction(DashboardTransactionPreview preview) {
    if (preview.customCategoryIconCodePoint != null) {
      return AppIconUtils.fromCodePoint(
        preview.customCategoryIconCodePoint,
        fallback: _iconForCategory(preview.category),
      );
    }
    return _iconForCategory(preview.category);
  }

  Color _colorForTransaction(DashboardTransactionPreview preview) {
    if (preview.customCategoryColorValue != null) {
      return Color(preview.customCategoryColorValue!);
    }
    return _colorForCategory(preview.category);
  }

  String _subtitle(BuildContext context, DateTime date, String localeCode) {
    final DateTime now = DateTime.now();
    final bool isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final String day = isToday
        ? context.l10n.phrase('Today', french: 'Aujourd hui')
        : DateUtilsX.short(date, localeCode: localeCode);
    final String time = DateFormat('HH:mm').format(date);
    return '$day - $time';
  }

  IconData _iconForCategory(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_bus_filled_rounded;
      case ExpenseCategory.rent:
        return Icons.home_work_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_long_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  Color _colorForCategory(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return const Color(0xFF42A5F5);
      case ExpenseCategory.transport:
        return const Color(0xFF1E88E5);
      case ExpenseCategory.rent:
        return const Color(0xFF1565C0);
      case ExpenseCategory.shopping:
        return const Color(0xFF64B5F6);
      case ExpenseCategory.bills:
        return const Color(0xFF90CAF9);
      case ExpenseCategory.other:
        return const Color(0xFF42A5F5);
    }
  }
}

class _AnimatedStagger extends StatelessWidget {
  const _AnimatedStagger({
    required this.child,
    required this.index,
    required this.animate,
  });

  final Widget child;
  final int index;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: animate ? 1 : 0),
      duration: Duration(milliseconds: 250 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({
    required this.points,
    this.width = 90,
    this.height = 28,
  });

  final List<double> points;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double maxY = (points.reduce(max) * 1.2).clamp(1, 999999);
    return SizedBox(
      width: width,
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: List<FlSpot>.generate(
                points.length,
                (int i) => FlSpot(i.toDouble(), points[i]),
              ),
              isCurved: true,
              color: Colors.white.withValues(alpha: 0.90),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 280),
      ),
    );
  }
}

class _BalanceWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);

    final Path path1 = Path()
      ..moveTo(-20, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.20,
        size.height * 0.56,
        size.width * 0.46,
        size.height * 0.70,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.84,
        size.width + 20,
        size.height * 0.60,
      );

    final Path path2 = Path()
      ..moveTo(-20, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.26,
        size.height * 0.74,
        size.width * 0.58,
        size.height * 0.90,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 1.0,
        size.width + 20,
        size.height * 0.82,
      );

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum DashboardTransactionType { expense, income }

class DashboardTransactionPreview {
  const DashboardTransactionPreview({
    required this.title,
    required this.date,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.type,
    this.customCategoryIconCodePoint,
    this.customCategoryColorValue,
    this.isTransfer = false,
  });

  final String title;
  final DateTime date;
  final double amount;
  final ExpenseCategory category;
  final String paymentMethod;
  final DashboardTransactionType type;
  final int? customCategoryIconCodePoint;
  final int? customCategoryColorValue;
  final bool isTransfer;

  factory DashboardTransactionPreview.fromExpense(
    Expense expense,
    String localeCode,
  ) {
    final String note = expense.note.trim();
    final String title = note.isEmpty
        ? expense.categoryLabel(localeCode)
        : note;
    final bool isIncome = expense.amount < 0;

    return DashboardTransactionPreview(
      title: title,
      date: expense.date,
      amount: expense.amount.abs(),
      category: expense.category,
      paymentMethod: note.toLowerCase().contains('cash')
          ? AppLocalizations.phraseForLocale(
              localeCode,
              'Cash',
              french: 'Especes',
            )
          : AppLocalizations.phraseForLocale(
              localeCode,
              'Card',
              french: 'Carte',
            ),
      type: isIncome
          ? DashboardTransactionType.income
          : DashboardTransactionType.expense,
      customCategoryIconCodePoint: expense.customCategoryIconCodePoint,
      customCategoryColorValue: expense.customCategoryColorValue,
      isTransfer: expense.isTransfer,
    );
  }

  static List<DashboardTransactionPreview> dummy() {
    final DateTime now = DateTime.now();
    return <DashboardTransactionPreview>[
      DashboardTransactionPreview(
        title: 'Nike Store',
        date: now.subtract(const Duration(hours: 1, minutes: 14)),
        amount: 45.0,
        category: ExpenseCategory.shopping,
        paymentMethod: 'Card',
        type: DashboardTransactionType.expense,
        customCategoryIconCodePoint: null,
        customCategoryColorValue: null,
        isTransfer: false,
      ),
      DashboardTransactionPreview(
        title: 'Groceries',
        date: now.subtract(const Duration(hours: 3, minutes: 20)),
        amount: 80.0,
        category: ExpenseCategory.food,
        paymentMethod: 'Cash',
        type: DashboardTransactionType.expense,
        customCategoryIconCodePoint: null,
        customCategoryColorValue: null,
        isTransfer: false,
      ),
      DashboardTransactionPreview(
        title: 'Salary',
        date: now.subtract(const Duration(hours: 8, minutes: 3)),
        amount: 120.0,
        category: ExpenseCategory.other,
        paymentMethod: 'Card',
        type: DashboardTransactionType.income,
        customCategoryIconCodePoint: null,
        customCategoryColorValue: null,
        isTransfer: false,
      ),
      DashboardTransactionPreview(
        title: 'Electric Bill',
        date: now.subtract(const Duration(days: 1, hours: 2)),
        amount: 60.0,
        category: ExpenseCategory.bills,
        paymentMethod: 'Card',
        type: DashboardTransactionType.expense,
        customCategoryIconCodePoint: null,
        customCategoryColorValue: null,
        isTransfer: false,
      ),
    ];
  }
}

