import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/utils/icon_utils.dart';
import 'package:wfer_flousk_firebase/core/widgets/fintech_page_app_bar.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/core/widgets/responsive_page_body.dart';
import 'package:wfer_flousk_firebase/domain/entities/bank_account.dart';
import 'package:wfer_flousk_firebase/domain/entities/custom_category.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/pro/pro_page.dart';

class WalletManagerPage extends StatefulWidget {
  const WalletManagerPage({super.key});

  @override
  State<WalletManagerPage> createState() => _WalletManagerPageState();
}

class _WalletManagerPageState extends State<WalletManagerPage> {
  static const List<IconData> _iconOptions = <IconData>[
    Icons.account_balance_wallet_rounded,
    Icons.credit_card_rounded,
    Icons.account_balance_rounded,
    Icons.savings_rounded,
    Icons.payments_rounded,
    Icons.shopping_bag_rounded,
    Icons.fastfood_rounded,
    Icons.directions_bus_filled_rounded,
    Icons.bolt_rounded,
    Icons.label_rounded,
  ];

  static const List<int> _colorOptions = <int>[
    0xFF42A5F5,
    0xFF1E88E5,
    0xFF7E57C2,
    0xFF26A69A,
    0xFF66BB6A,
    0xFFFFA726,
    0xFFEF5350,
    0xFF90CAF9,
  ];

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
          child: DefaultTabController(
            length: 2,
            child: ResponsivePageBody(
              top: 8,
              bottom: 10,
              child: Column(
                children: <Widget>[
                  const FintechPageAppBar(
                    title: 'Wallets & Categories',
                    showBackToHome: true,
                  ),
                  const SizedBox(height: UiTokens.spacingSm),
                  TabBar(
                    tabs: <Widget>[
                      Tab(text: _t('Accounts', fr: 'Comptes')),
                      Tab(text: _t('Categories', fr: 'Categories')),
                    ],
                  ),
                  const SizedBox(height: UiTokens.spacingSm),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _accountsTab(context, settings, expenses),
                        _categoriesTab(context, settings),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountsTab(
    BuildContext context,
    SettingsController settings,
    ExpenseController expenses,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        GlassCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: settings.canAddMoreWallets
                    ? () => _showAddOrEditAccountDialog(
                        context,
                        settings: settings,
                        account: null,
                      )
                    : () => _showWalletLimitProGate(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(_t('Add Account', fr: 'Ajouter compte')),
              ),
              OutlinedButton.icon(
                onPressed: settings.bankAccounts.length < 2
                    ? null
                    : () => _showTransferDialog(
                        context,
                        settings: settings,
                        expenses: expenses,
                      ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(_t('Transfer', fr: 'Transferer')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...settings.bankAccounts.map((BankAccount account) {
          final bool active = account.id == settings.activeBankAccountId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(account.colorValue).withValues(alpha: 0.2),
                    ),
                    child: Icon(
                      AppIconUtils.fromCodePoint(
                        account.iconCodePoint,
                        fallback: Icons.account_balance_wallet_rounded,
                      ),
                      color: Color(account.colorValue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          settings.displayBankAccountName(account),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          settings.displayBankAccountInstitution(account),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  IconButton(
                    onPressed: () => settings.setActiveBankAccount(account.id),
                    tooltip: _t('Set active', fr: 'Definir actif'),
                    icon: const Icon(Icons.radio_button_checked_rounded),
                  ),
                  IconButton(
                    onPressed: () => _showAddOrEditAccountDialog(
                      context,
                      settings: settings,
                      account: account,
                    ),
                    tooltip: _t('Edit', fr: 'Modifier'),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    onPressed: settings.bankAccounts.length <= 1
                        ? null
                        : () => settings.removeBankAccount(account.id),
                    tooltip: _t('Delete', fr: 'Supprimer'),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _categoriesTab(BuildContext context, SettingsController settings) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        GlassCard(
          child: OutlinedButton.icon(
            onPressed: () => _showAddOrEditCategoryDialog(
              context,
              settings: settings,
              category: null,
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              _t('Add Custom Category', fr: 'Ajouter categorie perso'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (settings.customCategories.isEmpty)
          GlassCard(
            child: Text(
              _t(
                'No custom categories yet. Add your own labels and colors.',
                fr: 'Aucune categorie perso pour le moment. Ajoutez vos libelles et couleurs.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...settings.customCategories.map((CustomCategory category) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Color(
                          category.colorValue,
                        ).withValues(alpha: 0.22),
                      ),
                      child: Icon(
                        AppIconUtils.fromCodePoint(
                          category.iconCodePoint,
                          fallback: Icons.label_rounded,
                        ),
                        color: Color(category.colorValue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showAddOrEditCategoryDialog(
                        context,
                        settings: settings,
                        category: category,
                      ),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      onPressed: () =>
                          settings.removeCustomCategory(category.id),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _showAddOrEditAccountDialog(
    BuildContext context, {
    required SettingsController settings,
    required BankAccount? account,
  }) async {
    String name = account == null
        ? ''
        : settings.displayBankAccountName(account);
    String institution = account == null
        ? ''
        : settings.displayBankAccountInstitution(account);
    IconData icon = account == null
        ? Icons.account_balance_wallet_rounded
        : AppIconUtils.fromCodePoint(
            account.iconCodePoint,
            fallback: Icons.account_balance_wallet_rounded,
          );
    int colorValue = account?.colorValue ?? 0xFF42A5F5;

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
                    account == null
                        ? _t('Add Account', fr: 'Ajouter compte')
                        : _t('Edit Account', fr: 'Modifier compte'),
                  ),
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
                        _iconPicker(
                          selected: icon,
                          onSelect: (IconData value) {
                            setDialogState(() => icon = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        _colorPicker(
                          selectedColorValue: colorValue,
                          onSelect: (int value) {
                            setDialogState(() => colorValue = value);
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
                        if (account == null) {
                          final bool added = await settings.addBankAccount(
                            name: name.trim(),
                            institution: institution.trim(),
                            iconCodePoint: icon.codePoint,
                            colorValue: colorValue,
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
                        } else {
                          await settings.updateBankAccount(
                            BankAccount(
                              id: account.id,
                              name: name.trim(),
                              institution: institution.trim().isEmpty
                                  ? settings.localizedBankLabel
                                  : institution.trim(),
                              createdAt: account.createdAt,
                              iconCodePoint: icon.codePoint,
                              colorValue: colorValue,
                            ),
                          );
                        }
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

  Future<void> _showWalletLimitProGate(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Container(
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
                      Expanded(
                        child: Text(
                          _t(
                            'More Wallets = Pro',
                            fr: 'Plus de portefeuilles = Pro',
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddOrEditCategoryDialog(
    BuildContext context, {
    required SettingsController settings,
    required CustomCategory? category,
  }) async {
    String name = category?.name ?? '';
    IconData icon = category == null
        ? Icons.label_rounded
        : AppIconUtils.fromCodePoint(
            category.iconCodePoint,
            fallback: Icons.label_rounded,
          );
    int colorValue = category?.colorValue ?? 0xFF64B5F6;

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
                    category == null
                        ? _t('Add Category', fr: 'Ajouter categorie')
                        : _t('Edit Category', fr: 'Modifier categorie'),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(
                          initialValue: name,
                          onChanged: (String value) => name = value,
                          decoration: InputDecoration(
                            hintText: _t(
                              'Category name',
                              fr: 'Nom de categorie',
                            ),
                            prefixIcon: Icon(Icons.label_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _iconPicker(
                          selected: icon,
                          onSelect: (IconData value) {
                            setDialogState(() => icon = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        _colorPicker(
                          selectedColorValue: colorValue,
                          onSelect: (int value) {
                            setDialogState(() => colorValue = value);
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
                        if (category == null) {
                          await settings.addCustomCategory(
                            name: name.trim(),
                            iconCodePoint: icon.codePoint,
                            colorValue: colorValue,
                          );
                        } else {
                          await settings.updateCustomCategory(
                            CustomCategory(
                              id: category.id,
                              name: name.trim(),
                              iconCodePoint: icon.codePoint,
                              colorValue: colorValue,
                              createdAt: category.createdAt,
                            ),
                          );
                        }
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
    BuildContext context, {
    required SettingsController settings,
    required ExpenseController expenses,
  }) async {
    final List<BankAccount> accounts = settings.bankAccounts;
    if (accounts.length < 2) {
      return;
    }

    String from = settings.activeBankAccountId;
    String to = accounts
        .firstWhere((BankAccount account) => account.id != from)
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
                  title: Text(_t('Transfer', fr: 'Transferer')),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          initialValue: from,
                          decoration: InputDecoration(
                            hintText: _t('From', fr: 'Depuis'),
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
                              from = value;
                              if (to == from) {
                                to = accounts
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
                          initialValue: to,
                          decoration: InputDecoration(
                            hintText: _t('To', fr: 'Vers'),
                          ),
                          items: accounts
                              .where(
                                (BankAccount account) => account.id != from,
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
                            setDialogState(() => to = value);
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
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          onChanged: (String value) => noteInput = value,
                          decoration: InputDecoration(
                            hintText: _t('Note', fr: 'Note'),
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
                            double.tryParse(amountInput.replaceAll(',', '.')) ??
                            0;
                        if (amount <= 0 || from == to) {
                          return;
                        }

                        final BankAccount fromAccount = accounts.firstWhere(
                          (BankAccount account) => account.id == from,
                        );
                        final BankAccount toAccount = accounts.firstWhere(
                          (BankAccount account) => account.id == to,
                        );
                        final String toAccountName = settings
                            .displayBankAccountName(toAccount);
                        final String fromAccountName = settings
                            .displayBankAccountName(fromAccount);
                        final String transferId = const Uuid().v4();
                        final String text = noteInput.trim();

                        await expenses.addExpensesBulk(<Expense>[
                          Expense(
                            id: const Uuid().v4(),
                            amount: amount,
                            category: ExpenseCategory.other,
                            date: DateTime.now(),
                            note: text.isEmpty
                                ? _ta(
                                    'Transfer to {target}',
                                    <String, String>{'target': toAccountName},
                                    fr: 'Transfert vers {target}',
                                  )
                                : '$text -> $toAccountName',
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
                            note: text.isEmpty
                                ? _ta(
                                    'Transfer from {source}',
                                    <String, String>{'source': fromAccountName},
                                    fr: 'Transfert depuis {source}',
                                  )
                                : '$text <- $fromAccountName',
                            currencyCode: settings.currencyCode,
                            accountId: toAccount.id,
                            isTransfer: true,
                            transferGroupId: transferId,
                          ),
                        ]);

                        if (context.mounted) {
                          await context.read<ToolsController>().evaluateBudgets(
                            expenses: expenses.expensesForAccount(
                              settings.activeBankAccountId,
                            ),
                            currencyCode: settings.currencyCode,
                          );
                        }
                        if (!dialogContext.mounted) {
                          return;
                        }
                        Navigator.of(dialogContext).pop();
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

  Widget _iconPicker({
    required IconData selected,
    required ValueChanged<IconData> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _iconOptions
          .map((IconData icon) {
            final bool isSelected = icon.codePoint == selected.codePoint;
            return GestureDetector(
              onTap: () => onSelect(icon),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? const Color(0xFF42A5F5).withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF42A5F5)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _colorPicker({
    required int selectedColorValue,
    required ValueChanged<int> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colorOptions
          .map((int value) {
            final bool selected = value == selectedColorValue;
            return GestureDetector(
              onTap: () => onSelect(value),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
