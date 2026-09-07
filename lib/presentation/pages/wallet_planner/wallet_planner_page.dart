import 'dart:math';

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
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';

class WalletPlannerPage extends StatefulWidget {
  const WalletPlannerPage({super.key});

  @override
  State<WalletPlannerPage> createState() => _WalletPlannerPageState();
}

class _WalletPlannerPageState extends State<WalletPlannerPage> {
  final TextEditingController _incomeController = TextEditingController();
  final TextEditingController _savingsController = TextEditingController();
  final Map<ExpenseCategory, TextEditingController> _categoryControllers =
      <ExpenseCategory, TextEditingController>{};

  bool _initialized = false;
  bool _saving = false;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }

    final SettingsController settings = context.read<SettingsController>();
    _incomeController.text = _formatInitial(settings.monthlyIncome);
    _savingsController.text = _formatInitial(settings.monthlySavingsGoal);

    for (final ExpenseCategory category in ExpenseCategory.values) {
      final double value = settings.categoryMonthlyPlans[category] ?? 0;
      _categoryControllers[category] = TextEditingController(
        text: _formatInitial(value),
      );
    }

    _initialized = true;
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _savingsController.dispose();
    for (final TextEditingController controller
        in _categoryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final ExpenseController expenses = context.watch<ExpenseController>();
    final String currencyCode = settings.currencyCode;

    final double income = _valueOf(_incomeController);
    final double savingsGoal = _valueOf(_savingsController);
    final Map<ExpenseCategory, double> categoryPlan = <ExpenseCategory, double>{
      for (final ExpenseCategory category in ExpenseCategory.values)
        category: _valueOf(_categoryControllers[category]),
    };

    final double plannedExpenses = categoryPlan.values.fold<double>(
      0,
      (double sum, double value) => sum + value,
    );
    final double spendableBudget = max(income - savingsGoal, 0);
    final double plannedRemaining = spendableBudget - plannedExpenses;
    final int daysInMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month + 1,
      0,
    ).day;
    final double dailyAllowance = daysInMonth <= 0
        ? 0
        : spendableBudget / daysInMonth;

    final double realMonthIncome =
        settings.monthlyIncome +
        expenses.monthlyIncomeTransactionsForAccount(
          settings.activeBankAccountId,
        );
    final double realMonthSpent = expenses.monthlySpendingForAccount(
      settings.activeBankAccountId,
    );
    final double realRemaining = max(realMonthIncome - realMonthSpent, 0);
    final double savingsProgress = savingsGoal <= 0
        ? 0
        : (realRemaining / savingsGoal).clamp(0, 1);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsivePageBody(
            top: 8,
            bottom: 12,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const FintechPageAppBar(
                    title: 'Wallet Planner',
                    showBackToHome: true,
                  ),
                  const SizedBox(height: UiTokens.spacingMd),
                  _overviewCard(
                    context,
                    currencyCode: currencyCode,
                    spendableBudget: spendableBudget,
                    plannedExpenses: plannedExpenses,
                    plannedRemaining: plannedRemaining,
                    dailyAllowance: dailyAllowance,
                    realMonthIncome: realMonthIncome,
                    realMonthSpent: realMonthSpent,
                    savingsGoal: savingsGoal,
                    savingsProgress: savingsProgress,
                  ),
                  const SizedBox(height: UiTokens.spacingMd),
                  _incomeGoalCard(context),
                  const SizedBox(height: UiTokens.spacingMd),
                  _categoriesPlanCard(context),
                  const SizedBox(height: UiTokens.spacingMd),
                  AnimatedPrimaryButton(
                    label: _t(
                      'Save Wallet Plan',
                      fr: 'Enregistrer le plan de portefeuille',
                    ),
                    icon: Icons.check_rounded,
                    isLoading: _saving,
                    onPressed: _saving ? null : _savePlan,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overviewCard(
    BuildContext context, {
    required String currencyCode,
    required double spendableBudget,
    required double plannedExpenses,
    required double plannedRemaining,
    required double dailyAllowance,
    required double realMonthIncome,
    required double realMonthSpent,
    required double savingsGoal,
    required double savingsProgress,
  }) {
    final bool healthy = plannedRemaining >= 0;

    return GlassCard(
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Smart plan overview', fr: 'Apercu du plan intelligent'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Set monthly income, savings target, and category limits to keep spending under control.',
              fr: 'Definissez revenu mensuel, objectif epargne et limites par categorie pour garder le controle des depenses.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _metricTile(
                context,
                title: _t('Spendable', fr: 'Depensable'),
                value: CurrencyUtils.formatAmount(
                  spendableBudget,
                  currencyCode,
                ),
                color: AppColors.skyBlue,
              ),
              _metricTile(
                context,
                title: _t('Planned', fr: 'Planifie'),
                value: CurrencyUtils.formatAmount(
                  plannedExpenses,
                  currencyCode,
                ),
                color: AppColors.primaryBlue,
              ),
              _metricTile(
                context,
                title: _t('Remaining', fr: 'Restant'),
                value: CurrencyUtils.formatAmount(
                  plannedRemaining.abs(),
                  currencyCode,
                ),
                color: healthy ? AppColors.incomeGreen : AppColors.expenseRed,
                prefix: healthy ? '+' : '-',
              ),
              _metricTile(
                context,
                title: _t('Daily cap', fr: 'Plafond quotidien'),
                value: CurrencyUtils.formatAmount(dailyAllowance, currencyCode),
                color: AppColors.softBlueGlow,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _t('Real month tracking', fr: 'Suivi reel du mois'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _progressRow(
            context,
            leftLabel:
                '${_t('Income', fr: 'Revenu')}: ${CurrencyUtils.formatAmount(realMonthIncome, currencyCode)}',
            rightLabel:
                '${_t('Spent', fr: 'Depense')}: ${CurrencyUtils.formatAmount(realMonthSpent, currencyCode)}',
            progress: realMonthIncome <= 0
                ? 0
                : (realMonthSpent / realMonthIncome).clamp(0, 1),
            fill: const LinearGradient(
              colors: <Color>[AppColors.primaryBlue, AppColors.gradientBlue2],
            ),
          ),
          if (savingsGoal > 0) ...<Widget>[
            const SizedBox(height: 10),
            _progressRow(
              context,
              leftLabel:
                  '${_t('Savings target', fr: 'Objectif epargne')}: ${CurrencyUtils.formatAmount(savingsGoal, currencyCode)}',
              rightLabel: '${(savingsProgress * 100).toStringAsFixed(0)}%',
              progress: savingsProgress,
              fill: LinearGradient(
                colors: <Color>[
                  AppColors.incomeGreen.withValues(alpha: 0.9),
                  AppColors.skyBlue.withValues(alpha: 0.9),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _incomeGoalCard(BuildContext context) {
    return GlassCard(
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Income and savings goal', fr: 'Revenu et objectif epargne'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 520;
              if (compact) {
                return Column(
                  children: <Widget>[
                    _numberField(
                      controller: _incomeController,
                      hint: _t('Monthly income', fr: 'Revenu mensuel'),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 10),
                    _numberField(
                      controller: _savingsController,
                      hint: _t(
                        'Savings goal for this month',
                        fr: 'Objectif epargne pour ce mois',
                      ),
                      icon: Icons.savings_outlined,
                    ),
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(
                    child: _numberField(
                      controller: _incomeController,
                      hint: _t('Monthly income', fr: 'Revenu mensuel'),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _numberField(
                      controller: _savingsController,
                      hint: _t(
                        'Savings goal for this month',
                        fr: 'Objectif epargne pour ce mois',
                      ),
                      icon: Icons.savings_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _categoriesPlanCard(BuildContext context) {
    final String localeCode = Localizations.localeOf(context).languageCode;
    return GlassCard(
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t(
              'Category monthly limits',
              fr: 'Limites mensuelles par categorie',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Set planned spending per category (Food, Transport, Rent, ...).',
              fr: 'Definissez les depenses prevues par categorie (Alimentation, Transport, Loyer, ...).',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...ExpenseCategory.values.map((ExpenseCategory category) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    child: Icon(
                      _iconForCategory(category),
                      color: AppColors.skyBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Text(
                      category.localizedLabel(localeCode),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _numberField(
                      controller: _categoryControllers[category]!,
                      hint: '0.00',
                      icon: null,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    );
  }

  Widget _metricTile(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    String prefix = '',
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            '$prefix$value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressRow(
    BuildContext context, {
    required String leftLabel,
    required String rightLabel,
    required double progress,
    required Gradient fill,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                leftLabel,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              rightLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: Colors.white.withValues(alpha: 0.10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0, 1),
                child: Container(decoration: BoxDecoration(gradient: fill)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _savePlan() async {
    if (_saving) return;
    final SettingsController settings = context.read<SettingsController>();
    final ExpenseController expenses = context.read<ExpenseController>();
    final ToolsController tools = context.read<ToolsController>();

    final double income = _valueOf(_incomeController);
    final double goal = _valueOf(_savingsController);
    final Map<ExpenseCategory, double> planValues = <ExpenseCategory, double>{
      for (final ExpenseCategory category in ExpenseCategory.values)
        category: _valueOf(_categoryControllers[category]),
    };

    setState(() => _saving = true);
    try {
      await settings.setMonthlyIncome(income);
      await settings.setMonthlySavingsGoal(goal);
      await settings.setCategoryMonthlyPlans(planValues);
      await tools.evaluateSmartSavingPlan(
        totalIncomeForMonth:
            income +
            expenses.monthlyIncomeTransactionsForAccount(
              settings.activeBankAccountId,
            ),
        savingsGoal: goal,
        spentForMonth: expenses.monthlySpendingForAccount(
          settings.activeBankAccountId,
        ),
        currencyCode: settings.currencyCode,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Wallet plan saved successfully.',
              fr: 'Plan de portefeuille enregistre avec succes.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Unable to save. Please try again.',
              fr: 'Enregistrement impossible. Veuillez reessayer.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _valueOf(TextEditingController? controller) {
    final String raw = controller?.text.trim() ?? '';
    return double.tryParse(raw.replaceAll(',', '.')) ?? 0;
  }

  String _formatInitial(double value) {
    if (value <= 0) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
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
}
