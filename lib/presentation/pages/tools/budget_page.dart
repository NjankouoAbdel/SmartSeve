import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';
import 'package:wfer_flousk_firebase/core/widgets/animated_primary_button.dart';
import 'package:wfer_flousk_firebase/core/widgets/fintech_page_app_bar.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/core/widgets/responsive_page_body.dart';
import 'package:wfer_flousk_firebase/domain/entities/budget_goal.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';

/// Ecran dedie a UNE seule chose : definir/gerer les budgets mensuels.
///
/// Avant, "Definir budget" (depuis l'accueil) ouvrait le Centre Outils en
/// entier (guide des 6 outils + budget + paiements planifies + verrou +
/// chatbot + OCR + CSV, tout dans le meme scroll) : un utilisateur qui
/// voulait juste poser une limite de depense se retrouvait avec 5 autres
/// outils sans rapport sous les yeux. Cet ecran ne montre QUE ce qui sert a
/// definir un budget : une explication courte, le bouton pour en ajouter
/// un, et la liste de ceux deja definis. Le Centre Outils (accessible via
/// "Voir tout") reste disponible pour qui veut parcourir tous les outils.
class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  String _t(BuildContext context, String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  String _ta(
    BuildContext context,
    String english,
    Map<String, String> args, {
    String? fr,
  }) {
    return context.l10n.phraseWithArgs(english, args, french: fr);
  }

  @override
  Widget build(BuildContext context) {
    final ToolsController tools = context.watch<ToolsController>();
    final ExpenseController expenses = context.watch<ExpenseController>();
    final SettingsController settings = context.watch<SettingsController>();
    final List<BudgetGoal> budgets = tools.budgets;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsivePageBody(
            top: 8,
            bottom: 8,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FintechPageAppBar(
                    title: _t(context, 'Set Budget', fr: 'Definir budget'),
                    showBackToHome: true,
                  ),
                  const SizedBox(height: UiTokens.spacingMd),
                  _introCard(context),
                  const SizedBox(height: UiTokens.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedPrimaryButton(
                      label: _t(context, 'Add Budget', fr: 'Ajouter budget'),
                      icon: Icons.add_rounded,
                      onPressed: () => _showAddBudgetDialog(context, tools),
                    ),
                  ),
                  const SizedBox(height: UiTokens.spacingLg),
                  if (budgets.isEmpty)
                    _emptyState(context)
                  else ...<Widget>[
                    Text(
                      _t(context, 'Your Budgets', fr: 'Vos budgets'),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: UiTokens.spacingSm),
                    ...budgets.map(
                      (BudgetGoal goal) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: UiTokens.spacingSm,
                        ),
                        child: _budgetTile(
                          context,
                          tools: tools,
                          expenses: expenses,
                          settings: settings,
                          goal: goal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Explique en une phrase ce que fait cet ecran et rappelle que les
  /// alertes sont automatiques (declenchees a chaque depense ajoutee) : pas
  /// besoin d'un bouton "Verifier les alertes" separe, qui n'apportait rien
  /// de plus a l'utilisateur.
  Widget _introCard(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.10),
            ),
            child: const Icon(
              Icons.savings_rounded,
              size: 18,
              color: AppColors.skyBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _t(
                context,
                'Set a monthly spending limit, globally or per category. '
                'You get an automatic alert around 80% and 100% of the '
                'limit — no need to check manually.',
                fr:
                    'Definissez une limite de depense mensuelle, globale ou '
                    'par categorie. Vous recevez une alerte automatique vers '
                    '80% et 100% de la limite — pas besoin de verifier '
                    'manuellement.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t(context, 'No budgets set yet.', fr: 'Aucun budget defini.'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              context,
              'Add one above to start tracking a spending limit.',
              fr: 'Ajoutez-en un ci-dessus pour commencer a suivre une limite.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _budgetTile(
    BuildContext context, {
    required ToolsController tools,
    required ExpenseController expenses,
    required SettingsController settings,
    required BudgetGoal goal,
  }) {
    final double spending = tools.spendingForBudget(
      goal,
      expenses.expensesForAccount(settings.activeBankAccountId),
    );
    final double ratio = goal.monthlyLimit <= 0
        ? 0
        : (spending / goal.monthlyLimit).clamp(0, 1.2);
    final bool overLimit = ratio >= 1;

    return GlassCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  goal.categoryKey == null
                      ? _t(context, 'Global Budget', fr: 'Budget global')
                      : ExpenseCategoryX.fromKey(
                          goal.categoryKey!,
                        ).localizedLabel(settings.localeCode),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${CurrencyUtils.formatAmount(spending, settings.currencyCode)} / ${CurrencyUtils.formatAmount(goal.monthlyLimit, settings.currencyCode)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                onPressed: () => tools.removeBudgetGoal(goal.id),
                tooltip: _t(context, 'Delete', fr: 'Supprimer'),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio > 1 ? 1 : ratio,
              minHeight: 8,
              color: overLimit ? AppColors.expenseRed : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBudgetDialog(
    BuildContext context,
    ToolsController tools,
  ) async {
    final TextEditingController amountController = TextEditingController();
    ExpenseCategory? selectedCategory;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(
            _t(context, 'Add Budget Goal', fr: 'Ajouter un objectif budget'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: _t(
                    context,
                    'Monthly Limit',
                    fr: 'Limite mensuelle',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ExpenseCategory?>(
                isExpanded: true,
                initialValue: selectedCategory,
                decoration: InputDecoration(
                  hintText: _t(context, 'Category', fr: 'Categorie'),
                ),
                items: <DropdownMenuItem<ExpenseCategory?>>[
                  DropdownMenuItem<ExpenseCategory?>(
                    value: null,
                    child: Text(
                      _t(
                        context,
                        'Global (All Categories)',
                        fr: 'Global (Toutes categories)',
                      ),
                    ),
                  ),
                  ...ExpenseCategory.values.map(
                    (ExpenseCategory category) =>
                        DropdownMenuItem<ExpenseCategory?>(
                          value: category,
                          child: Text(
                            category.localizedLabel(
                              Localizations.localeOf(context).languageCode,
                            ),
                          ),
                        ),
                  ),
                ],
                onChanged: (ExpenseCategory? value) {
                  selectedCategory = value;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t(context, 'Cancel', fr: 'Annuler')),
            ),
            ElevatedButton(
              onPressed: () async {
                final double amount =
                    double.tryParse(
                      amountController.text.trim().replaceAll(',', '.'),
                    ) ??
                    0;
                if (amount <= 0) {
                  return;
                }
                await tools.addBudgetGoal(
                  monthlyLimit: amount,
                  category: selectedCategory,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text(_t(context, 'Save', fr: 'Enregistrer')),
            ),
          ],
        );
      },
    );

    amountController.dispose();
  }
}
