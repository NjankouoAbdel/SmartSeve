import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/date_utils.dart';
import 'package:wfer_flousk_firebase/core/widgets/animated_primary_button.dart';
import 'package:wfer_flousk_firebase/core/widgets/fintech_page_app_bar.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/core/widgets/responsive_page_body.dart';
import 'package:wfer_flousk_firebase/domain/entities/budget_goal.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/domain/entities/recurring_expense_plan.dart';
import 'package:wfer_flousk_firebase/domain/entities/tool_notice.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/pro/pro_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/tools/finance_chatbot_page.dart';

class ToolsCenterPage extends StatefulWidget {
  const ToolsCenterPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ToolsCenterPage> createState() => _ToolsCenterPageState();
}

class _ToolsCenterPageState extends State<ToolsCenterPage> {
  final TextEditingController _pinController = TextEditingController();

  bool _busyCsv = false;
  bool _busyOcr = false;
  bool _busyStatementOcr = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ToolsController tools = context.watch<ToolsController>();
    final ExpenseController expenses = context.watch<ExpenseController>();
    final SettingsController settings = context.watch<SettingsController>();

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: DefaultTabController(
            length: 2,
            initialIndex: widget.initialTab.clamp(0, 1).toInt(),
            child: ResponsivePageBody(
              top: 8,
              bottom: 8,
              child: Column(
                children: <Widget>[
                  FintechPageAppBar(
                    title: _tr(
                      context,
                      'Smart Tools Center',
                      'Centre Outils Intelligent',
                    ),
                    showBackToHome: true,
                  ),
                  const SizedBox(height: UiTokens.spacingXs),
                  if (tools.unreadNoticeCount > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: tools.markAllNoticesRead,
                        child: Text(
                          _tr(context, 'Mark all read', 'Marquer tout lu'),
                        ),
                      ),
                    ),
                  TabBar(
                    tabs: <Widget>[
                      Tab(text: _tr(context, 'Tools', 'Outils')),
                      Tab(text: _tr(context, 'Notifications', 'Notifications')),
                    ],
                  ),
                  const SizedBox(height: UiTokens.spacingXs),
                  Expanded(
                    child: tools.isLocked
                        ? _buildLockedView(context, tools)
                        : TabBarView(
                            children: <Widget>[
                              _buildToolsList(
                                context,
                                tools,
                                expenses,
                                settings,
                              ),
                              _buildNotificationsList(context, tools),
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

  Widget _buildLockedView(BuildContext context, ToolsController tools) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _tr(
                context,
                'Security Lock Enabled',
                'Verrou de securite active',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _tr(
                context,
                'Unlock with biometrics or PIN to access tools.',
                'Debloquez avec biometrie ou PIN pour acceder aux outils.',
              ),
            ),
            const SizedBox(height: 14),
            if (tools.biometricEnabled)
              AnimatedPrimaryButton(
                label: _tr(
                  context,
                  'Unlock with Biometrics',
                  'Debloquer avec biometrie',
                ),
                icon: Icons.fingerprint_rounded,
                onPressed: () async {
                  final bool ok = await tools.unlockWithBiometric();
                  if (!context.mounted) {
                    return;
                  }
                  if (!ok) {
                    _showSnack(
                      _tr(
                        context,
                        'Biometric authentication failed.',
                        'Authentification biometrie echouee.',
                      ),
                    );
                  }
                },
              ),
            if (tools.pinEnabled) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                decoration: InputDecoration(
                  hintText: _tr(context, 'PIN', 'PIN'),
                  prefixIcon: const Icon(Icons.pin_rounded),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
              ),
              AnimatedPrimaryButton(
                label: _tr(context, 'Unlock with PIN', 'Debloquer avec PIN'),
                icon: Icons.lock_open_rounded,
                onPressed: () {
                  final bool ok = tools.unlockWithPin(
                    _pinController.text.trim(),
                  );
                  if (!ok) {
                    _showSnack(_tr(context, 'Invalid PIN.', 'PIN invalide.'));
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToolsList(
    BuildContext context,
    ToolsController tools,
    ExpenseController expenses,
    SettingsController settings,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      children: <Widget>[
        _toolsGuideSection(context, tools),
        const SizedBox(height: 14),
        _budgetCard(context, tools, expenses, settings),
        const SizedBox(height: 12),
        _recurringCard(context, tools, expenses, settings),
        const SizedBox(height: 12),
        _securityCard(context, tools),
        const SizedBox(height: 12),
        _chatbotCard(context, tools, settings),
        const SizedBox(height: 12),
        _ocrCard(context, tools, expenses, settings),
        const SizedBox(height: 12),
        _csvCard(context, tools, expenses, settings),
      ],
    );
  }

  Widget _toolsGuideSection(BuildContext context, ToolsController tools) {
    final List<_ToolGuideItem> items = <_ToolGuideItem>[
      _ToolGuideItem(
        icon: Icons.savings_rounded,
        title: _tr(
          context,
          'Budget Goals + Alerts',
          'Objectifs budget + alertes',
        ),
        summary: _tr(
          context,
          'Set limits and get alerts at 80% and 100%.',
          'Definissez des limites et recevez des alertes a 80% et 100%.',
        ),
        example: _tr(
          context,
          'Example: Food budget 300. Alert appears near 240.',
          'Exemple : Budget nourriture 300. Alerte vers 240.',
        ),
        color: const Color(0xFF3F8CFF),
      ),
      _ToolGuideItem(
        icon: Icons.repeat_rounded,
        title: _tr(context, 'Planned Payments', 'Paiements planifies'),
        summary: _tr(
          context,
          'Create one-time or recurring expenses.',
          'Creez des depenses uniques ou recurrentes.',
        ),
        example: _tr(
          context,
          'Example: Rent 500 on day 5 every month.',
          'Exemple : Loyer 500 le jour 5 chaque mois.',
        ),
        color: const Color(0xFF26A69A),
      ),
      _ToolGuideItem(
        icon: Icons.security_rounded,
        title: _tr(context, 'Biometric / PIN Lock', 'Verrou biometrie / PIN'),
        summary: _tr(
          context,
          'Protect tools using fingerprint or PIN.',
          'Protegez les outils avec empreinte ou PIN.',
        ),
        example: _tr(
          context,
          'Example: enable biometric and set a 4-digit PIN.',
          'Exemple : activez la biometrie et un PIN a 4 chiffres.',
        ),
        color: const Color(0xFF8D6E63),
      ),
      _ToolGuideItem(
        icon: Icons.smart_toy_rounded,
        title: _tr(context, 'Finance Chatbot', 'Chatbot financier'),
        summary: _tr(
          context,
          'Ask smart questions about spending, budget and savings.',
          'Posez des questions intelligentes sur depenses, budget et epargne.',
        ),
        example: _tr(
          context,
          'Example: "Can I spend 50?" or "How much did I spend this month?".',
          'Exemple : "Puis-je depenser 50 ?" ou "Combien ai-je depense ce mois ?".',
        ),
        color: const Color(0xFF5C6BC0),
      ),
      _ToolGuideItem(
        icon: Icons.document_scanner_outlined,
        title: _tr(context, 'OCR Receipt Scanner', 'Scanner OCR recu'),
        summary: _tr(
          context,
          'Scan receipts and convert them to expenses.',
          'Scannez les recus et convertissez-les en depenses.',
        ),
        example: _tr(
          context,
          'Example: scan restaurant ticket then confirm amount.',
          'Exemple : scannez un ticket resto puis confirmez le montant.',
        ),
        color: const Color(0xFFAB47BC),
      ),
      _ToolGuideItem(
        icon: Icons.table_chart_outlined,
        title: _tr(context, 'CSV Import / Export', 'Import / Export CSV'),
        summary: _tr(
          context,
          'Import or export transactions with spreadsheet format.',
          'Importez ou exportez les transactions en format tableur.',
        ),
        example: _tr(
          context,
          'Example: export monthly report or import CSV file.',
          'Exemple : exportez le rapport mensuel ou importez un fichier CSV.',
        ),
        color: const Color(0xFF66BB6A),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GlassCard(
          borderRadius: UiTokens.radiusLg,
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF12314F).withValues(alpha: 0.95),
                  const Color(0xFF1D4B70).withValues(alpha: 0.85),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _tr(context, 'Tools Guide', 'Guide des outils'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _tr(
                    context,
                    'Start here: secure access, set budgets, automate plans, then use chatbot, OCR and CSV.',
                    'Commencez ici : securite, budgets, plans automatiques puis chatbot, OCR et CSV.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _guideChip(
                      context,
                      Icons.savings_rounded,
                      _ta(context, 'Budgets: {count}', <String, String>{
                        'count': '${tools.budgets.length}',
                      }, 'Budgets : {count}'),
                    ),
                    _guideChip(
                      context,
                      Icons.repeat_rounded,
                      _ta(context, 'Plans: {count}', <String, String>{
                        'count': '${tools.recurringPlans.length}',
                      }, 'Plans : {count}'),
                    ),
                    _guideChip(
                      context,
                      Icons.notifications_active_outlined,
                      _ta(context, 'Unread: {count}', <String, String>{
                        'count': '${tools.unreadNoticeCount}',
                      }, 'Non lus : {count}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              return _toolGuideCard(context, items[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _guideChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolGuideCard(BuildContext context, _ToolGuideItem item) {
    return Container(
      width: 252,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withValues(alpha: 0.20),
              border: Border.all(color: item.color.withValues(alpha: 0.45)),
            ),
            child: Icon(item.icon, size: 18, color: item.color),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            item.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.22,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              item.example,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFCFD8E3),
                fontSize: 11.5,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetCard(
    BuildContext context,
    ToolsController tools,
    ExpenseController expenses,
    SettingsController settings,
  ) {
    final String threshold = _percentage(0.8).toStringAsFixed(0);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title(context, '1) Budget Goals + Alerts', Icons.savings_rounded),
          const SizedBox(height: 8),
          Text(
            _ta(
              context,
              'Set monthly budgets globally or per category. Alerts trigger around {threshold}% and 100%.',
              <String, String>{'threshold': threshold},
              'Definissez des budgets mensuels globaux ou par categorie. Les alertes se declenchent vers {threshold}% et 100%.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _showAddBudgetDialog(context, tools),
                icon: const Icon(Icons.add_rounded),
                label: Text(_tr(context, 'Add Budget', 'Ajouter budget')),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await tools.evaluateBudgets(
                    expenses: expenses.expensesForAccount(
                      settings.activeBankAccountId,
                    ),
                    currencyCode: settings.currencyCode,
                  );
                  if (!context.mounted) return;
                  _showSnack(
                    _tr(
                      context,
                      'Budget check completed.',
                      'Verification budget terminee.',
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(_tr(context, 'Check Alerts', 'Verifier alertes')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tools.budgets.isEmpty)
            Text(_tr(context, 'No budgets set yet.', 'Aucun budget defini.'))
          else
            ...tools.budgets.map((BudgetGoal goal) {
              final double spending = tools.spendingForBudget(
                goal,
                expenses.expensesForAccount(settings.activeBankAccountId),
              );
              final double ratio = goal.monthlyLimit <= 0
                  ? 0
                  : (spending / goal.monthlyLimit).clamp(0, 1.2);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            goal.categoryKey == null
                                ? _tr(context, 'Global Budget', 'Budget global')
                                : ExpenseCategoryX.fromKey(
                                    goal.categoryKey!,
                                  ).localizedLabel(settings.localeCode),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '${CurrencyUtils.formatAmount(spending, settings.currencyCode)} / ${CurrencyUtils.formatAmount(goal.monthlyLimit, settings.currencyCode)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        IconButton(
                          onPressed: () => tools.removeBudgetGoal(goal.id),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
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

  Widget _recurringCard(
    BuildContext context,
    ToolsController tools,
    ExpenseController expenses,
    SettingsController settings,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title(context, '2) Planned Payments', Icons.repeat_rounded),
          const SizedBox(height: 8),
          Text(
            _tr(
              context,
              'Create one-time or recurring plans (monthly, weekly, yearly) and process them when due.',
              'Creez des plans uniques ou recurrents (mensuel, hebdomadaire, annuel) et traitez-les a echeance.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () =>
                    _showAddRecurringDialog(context, tools, settings),
                icon: const Icon(Icons.add_rounded),
                label: Text(_tr(context, 'Add Plan', 'Ajouter plan')),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final int count = await tools.processRecurringExpenses(
                    expenseController: expenses,
                    currencyCode: settings.currencyCode,
                    accountId: settings.activeBankAccountId,
                    silentIfEmpty: false,
                  );
                  await tools.evaluateBudgets(
                    expenses: expenses.expensesForAccount(
                      settings.activeBankAccountId,
                    ),
                    currencyCode: settings.currencyCode,
                  );
                  if (!context.mounted) return;
                  _showSnack(
                    _ta(
                      context,
                      'Processed recurring items: {count}',
                      <String, String>{'count': count.toString()},
                      'Elements recurrents traites : {count}',
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(_tr(context, 'Process Now', 'Traiter maintenant')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tools.recurringPlans.isEmpty)
            Text(
              _tr(
                context,
                'No planned payments yet.',
                'Aucun paiement planifie pour le moment.',
              ),
            )
          else
            ...tools.recurringPlans.map((RecurringExpensePlan plan) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${ExpenseCategoryX.fromKey(plan.categoryKey).localizedLabel(settings.localeCode)} - ${CurrencyUtils.formatAmount(plan.amount, plan.currencyCode)}',
                ),
                subtitle: Text(_planSubtitle(plan, settings.localeCode)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Switch(
                      value: plan.isActive,
                      onChanged: (bool value) {
                        tools.toggleRecurring(plan.id, value);
                      },
                    ),
                    IconButton(
                      onPressed: () => tools.removeRecurring(plan.id),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _securityCard(BuildContext context, ToolsController tools) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title(context, '3) Biometric / PIN Lock', Icons.security_rounded),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: tools.biometricEnabled,
            onChanged: tools.biometricSupported
                ? (bool value) => tools.setBiometricEnabled(value)
                : null,
            title: Text(_tr(context, 'Biometric Lock', 'Verrou biometrie')),
            subtitle: Text(
              tools.biometricSupported
                  ? _tr(
                      context,
                      'Use fingerprint/face to protect tools.',
                      'Utilisez empreinte/visage pour proteger les outils.',
                    )
                  : _tr(
                      context,
                      'Biometric is not supported on this device.',
                      'La biometrie n est pas prise en charge sur cet appareil.',
                    ),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _pinController,
            decoration: InputDecoration(
              hintText: _tr(
                context,
                'Set PIN (4-6 digits)',
                'Definir PIN (4-6 chiffres)',
              ),
              prefixIcon: Icon(Icons.pin_rounded),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: () async {
                  final String pin = _pinController.text.trim();
                  if (pin.length < 4) {
                    _showSnack(
                      _tr(
                        context,
                        'PIN must be at least 4 digits.',
                        'Le PIN doit contenir au moins 4 chiffres.',
                      ),
                    );
                    return;
                  }
                  await tools.setPinCode(pin);
                  if (!context.mounted) return;
                  _showSnack(_tr(context, 'PIN enabled.', 'PIN active.'));
                },
                child: Text(_tr(context, 'Save PIN', 'Enregistrer PIN')),
              ),
              OutlinedButton(
                onPressed: () async {
                  await tools.disablePin();
                  if (!context.mounted) return;
                  _pinController.clear();
                  _showSnack(_tr(context, 'PIN disabled.', 'PIN desactive.'));
                },
                child: Text(_tr(context, 'Disable PIN', 'Desactiver PIN')),
              ),
              OutlinedButton(
                onPressed: tools.lockNow,
                child: Text(_tr(context, 'Lock Now', 'Verrouiller')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chatbotCard(
    BuildContext context,
    ToolsController tools,
    SettingsController settings,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title(context, '4) Finance Chatbot', Icons.smart_toy_rounded),
          const SizedBox(height: 8),
          Text(
            _tr(
              context,
              'Ask instant questions about your spending, balance, budget and savings based on your current data.',
              'Posez des questions instantanees sur depenses, solde, budget et epargne selon vos donnees actuelles.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(AppRouter.slideFade(const FinanceChatbotPage()));
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(_tr(context, 'Open Chatbot', 'Ouvrir chatbot')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _ta(
              context,
              'Current setup: {plans} plans, {budgets} budgets, currency {currency}.',
              <String, String>{
                'plans': '${tools.recurringPlans.length}',
                'budgets': '${tools.budgets.length}',
                'currency': settings.currencyCode,
              },
              'Configuration actuelle : {plans} plans, {budgets} budgets, devise {currency}.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _ocrCard(
    BuildContext context,
    ToolsController tools,
    ExpenseController expenses,
    SettingsController settings,
  ) {
    final bool isPro = settings.isPro;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _title(
                  context,
                  '5) OCR Receipt Scanner',
                  Icons.document_scanner_outlined,
                ),
              ),
              if (!isPro)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _busyOcr
                    ? null
                    : () => _runOcr(
                        context: context,
                        tools: tools,
                        source: ImageSource.camera,
                        expenses: expenses,
                        settings: settings,
                      ),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(_tr(context, 'Scan Camera', 'Scanner camera')),
              ),
              OutlinedButton.icon(
                onPressed: _busyOcr
                    ? null
                    : () => _runOcr(
                        context: context,
                        tools: tools,
                        source: ImageSource.gallery,
                        expenses: expenses,
                        settings: settings,
                      ),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_tr(context, 'Scan Gallery', 'Scanner galerie')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _tr(
              context,
              'Or scan a whole bank statement (several transactions at once):',
              'Ou scannez un relevé bancaire entier (plusieurs transactions d\'un coup) :',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _busyStatementOcr
                    ? null
                    : () => _runStatementOcr(
                        context: context,
                        tools: tools,
                        source: ImageSource.camera,
                        expenses: expenses,
                        settings: settings,
                      ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(
                  _tr(context, 'Scan Statement', 'Scanner un relevé'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busyStatementOcr
                    ? null
                    : () => _runStatementOcr(
                        context: context,
                        tools: tools,
                        source: ImageSource.gallery,
                        expenses: expenses,
                        settings: settings,
                      ),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _tr(context, 'Statement from Gallery', 'Relevé depuis galerie'),
                ),
              ),
            ],
          ),
          if (tools.lastOcrResult != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _ta(
                context,
                'Last OCR: amount={amount} | date={date}',
                <String, String>{
                  'amount':
                      tools.lastOcrResult!.amount?.toStringAsFixed(2) ?? '-',
                  'date': tools.lastOcrResult!.date == null
                      ? '-'
                      : DateUtilsX.short(
                          tools.lastOcrResult!.date!,
                          localeCode: settings.localeCode,
                        ),
                },
                'Dernier OCR : montant={amount} | date={date}',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _csvCard(
    BuildContext context,
    ToolsController tools,
    ExpenseController expenses,
    SettingsController settings,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title(context, '6) CSV Import / Export', Icons.table_chart_outlined),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _busyCsv
                    ? null
                    : () async {
                        setState(() => _busyCsv = true);
                        try {
                          final String? path = await tools.exportCsv(
                            expenses.expensesForAccount(
                              settings.activeBankAccountId,
                            ),
                          );
                          if (!context.mounted) return;
                          if (path == null) {
                            _showSnack(
                              _tr(
                                context,
                                'CSV export failed.',
                                'Echec export CSV.',
                              ),
                            );
                            return;
                          }
                          _showSnack(
                            _tr(context, 'CSV exported.', 'CSV exporte.'),
                          );
                          await SharePlus.instance.share(
                            ShareParams(files: <XFile>[XFile(path)]),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          _showSnack(
                            _tr(
                              context,
                              'Unable to complete the request.',
                              'Impossible de terminer la demande.',
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _busyCsv = false);
                        }
                      },
                icon: const Icon(Icons.file_download_outlined),
                label: Text(_tr(context, 'Export CSV', 'Exporter CSV')),
              ),
              OutlinedButton.icon(
                onPressed: _busyCsv
                    ? null
                    : () async {
                        setState(() => _busyCsv = true);
                        try {
                          final (List<Expense> imported, String? error) =
                              await tools.importCsv(settings.currencyCode);
                          if (!context.mounted) return;
                          if (error != null) {
                            _showSnack(error);
                            return;
                          }
                          final int count = await expenses.addExpensesBulk(
                            imported,
                          );
                          await tools.evaluateBudgets(
                            expenses: expenses.expensesForAccount(
                              settings.activeBankAccountId,
                            ),
                            currencyCode: settings.currencyCode,
                          );
                          if (!context.mounted) return;
                          _showSnack(
                            _ta(
                              context,
                              'Imported and merged: {count} expense(s).',
                              <String, String>{'count': count.toString()},
                              'Importe et fusionne : {count} depense(s).',
                            ),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          _showSnack(
                            _tr(
                              context,
                              'Unable to complete the request.',
                              'Impossible de terminer la demande.',
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _busyCsv = false);
                        }
                      },
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(_tr(context, 'Import CSV', 'Importer CSV')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(BuildContext context, ToolsController tools) {
    if (tools.notices.isEmpty) {
      return Center(
        child: Text(
          _tr(
            context,
            'No notifications yet.',
            'Aucune notification pour le moment.',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: tools.notices.length,
      itemBuilder: (BuildContext context, int index) {
        final ToolNotice notice = tools.notices[index];
        final String localizedTitle = _localizeNoticeText(notice.title);
        final String localizedMessage = _localizeNoticeText(notice.message);
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              localizedTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: notice.isRead ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 4),
                Text(localizedMessage),
                const SizedBox(height: 4),
                Text(
                  DateUtilsX.short(
                    notice.createdAt,
                    localeCode: Localizations.localeOf(context).languageCode,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: notice.isRead
                ? null
                : TextButton(
                    onPressed: () => tools.markNoticeRead(notice.id),
                    child: Text(_tr(context, 'Read', 'Lu')),
                  ),
          ),
        );
      },
    );
  }

  Widget _title(BuildContext context, String text, IconData icon) {
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF8CC5FF)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.l10n.phrase(text),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  double _percentage(double value) {
    return (value * 100).clamp(0, 1000);
  }

  String _planCadenceLabel(PlannedCadence cadence) {
    switch (cadence) {
      case PlannedCadence.oneTime:
        return _tr(context, 'One-time', 'Une seule fois');
      case PlannedCadence.monthly:
        return _tr(context, 'Monthly', 'Mensuel');
      case PlannedCadence.weekly:
        return _tr(context, 'Weekly', 'Hebdomadaire');
      case PlannedCadence.yearly:
        return _tr(context, 'Yearly', 'Annuel');
    }
  }

  String _planSubtitle(RecurringExpensePlan plan, String localeCode) {
    final String normalizedLocale = AppLocalizations.normalizeLanguageCode(
      localeCode,
    );
    final String schedule = switch (plan.cadence) {
      PlannedCadence.oneTime => AppLocalizations.phraseWithArgsForLocale(
        normalizedLocale,
        'One-time on {date}',
        <String, String>{
          'date': DateUtilsX.short(
            plan.startDate,
            localeCode: normalizedLocale,
          ),
        },
        french: 'Une seule fois le {date}',
      ),
      PlannedCadence.monthly => AppLocalizations.phraseWithArgsForLocale(
        normalizedLocale,
        'Monthly on day {day}',
        <String, String>{'day': plan.dayOfMonth.toString()},
        french: 'Mensuel le jour {day}',
      ),
      PlannedCadence.weekly => AppLocalizations.phraseWithArgsForLocale(
        normalizedLocale,
        'Weekly each {weekday}',
        <String, String>{
          'weekday': _weekdayLabel(plan.weekDay, normalizedLocale),
        },
        french: 'Hebdomadaire chaque {weekday}',
      ),
      PlannedCadence.yearly => AppLocalizations.phraseWithArgsForLocale(
        normalizedLocale,
        'Yearly on {month} {day}',
        <String, String>{
          'month': _monthLabel(plan.monthOfYear, normalizedLocale),
          'day': plan.dayOfMonth.toString(),
        },
        french: 'Annuel le {day} {month}',
      ),
    };
    final String endDateText = plan.endDate == null
        ? ''
        : AppLocalizations.phraseWithArgsForLocale(
            normalizedLocale,
            ' • Ends {endDate}',
            <String, String>{
              'endDate': DateUtilsX.short(
                plan.endDate!,
                localeCode: normalizedLocale,
              ),
            },
            french: ' • Fin {endDate}',
          );
    final String lastAppliedText = plan.lastAppliedAt == null
        ? '-'
        : DateUtilsX.short(plan.lastAppliedAt!, localeCode: normalizedLocale);
    return AppLocalizations.phraseWithArgsForLocale(
      normalizedLocale,
      '{schedule}{endDateText}. Last applied: {lastAppliedText}',
      <String, String>{
        'schedule': schedule,
        'endDateText': endDateText,
        'lastAppliedText': lastAppliedText,
      },
      french: '{schedule}{endDateText}. Derniere execution: {lastAppliedText}',
    );
  }

  String _weekdayLabel(int weekday, String localeCode) {
    final int index = weekday.clamp(1, 7) - 1;
    final DateTime date = DateTime.utc(2024, 1, 1 + index);
    try {
      return DateFormat('EEEE', localeCode).format(date);
    } catch (_) {}

    const List<String> fallback = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return fallback[index];
  }

  String _monthLabel(int month, String localeCode) {
    final int clampedMonth = month.clamp(1, 12);
    try {
      return DateFormat(
        'MMMM',
        localeCode,
      ).format(DateTime.utc(2024, clampedMonth, 1));
    } catch (_) {}

    const List<String> fallback = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return fallback[clampedMonth - 1];
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
            _tr(context, 'Add Budget Goal', 'Ajouter un objectif budget'),
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
                  hintText: _tr(context, 'Monthly Limit', 'Limite mensuelle'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ExpenseCategory?>(
                isExpanded: true,
                initialValue: selectedCategory,
                decoration: InputDecoration(
                  hintText: _tr(context, 'Category', 'Categorie'),
                ),
                items: <DropdownMenuItem<ExpenseCategory?>>[
                  DropdownMenuItem<ExpenseCategory?>(
                    value: null,
                    child: Text(
                      _tr(
                        context,
                        'Global (All Categories)',
                        'Global (Toutes categories)',
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
              child: Text(_tr(context, 'Cancel', 'Annuler')),
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
              child: Text(_tr(context, 'Save', 'Enregistrer')),
            ),
          ],
        );
      },
    );

    amountController.dispose();
  }

  Future<void> _showAddRecurringDialog(
    BuildContext context,
    ToolsController tools,
    SettingsController settings,
  ) async {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    ExpenseCategory selectedCategory = ExpenseCategory.other;
    PlannedCadence selectedCadence = PlannedCadence.monthly;
    DateTime anchorDate = DateTime.now();
    DateTime? endDate;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                Future<void> pickAnchorDate() async {
                  final DateTime? picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: anchorDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() => anchorDate = picked);
                  }
                }

                Future<void> pickEndDate() async {
                  final DateTime? picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: endDate ?? anchorDate,
                    firstDate: anchorDate,
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() => endDate = picked);
                  }
                }

                return AlertDialog(
                  scrollable: true,
                  title: Text(
                    _tr(
                      context,
                      'Add Planned Payment',
                      'Ajouter un paiement planifie',
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: _tr(context, 'Amount', 'Montant'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ExpenseCategory>(
                          isExpanded: true,
                          initialValue: selectedCategory,
                          items: ExpenseCategory.values
                              .map(
                                (ExpenseCategory category) =>
                                    DropdownMenuItem<ExpenseCategory>(
                                      value: category,
                                      child: Text(
                                        category.localizedLabel(
                                          settings.localeCode,
                                        ),
                                      ),
                                    ),
                              )
                              .toList(),
                          onChanged: (ExpenseCategory? value) {
                            if (value != null) {
                              selectedCategory = value;
                            }
                          },
                          decoration: InputDecoration(
                            hintText: _tr(context, 'Category', 'Categorie'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<PlannedCadence>(
                          isExpanded: true,
                          initialValue: selectedCadence,
                          items: PlannedCadence.values
                              .map(
                                (PlannedCadence cadence) =>
                                    DropdownMenuItem<PlannedCadence>(
                                      value: cadence,
                                      child: Text(_planCadenceLabel(cadence)),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (PlannedCadence? value) {
                            if (value != null) {
                              setDialogState(() => selectedCadence = value);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: _tr(context, 'Cadence', 'Frequence'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_rounded),
                          title: Text(
                            selectedCadence == PlannedCadence.oneTime
                                ? _tr(context, 'Due date', 'Date due')
                                : _tr(context, 'Start date', 'Date debut'),
                          ),
                          subtitle: Text(
                            DateUtilsX.short(
                              anchorDate,
                              localeCode: settings.localeCode,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: pickAnchorDate,
                        ),
                        if (selectedCadence != PlannedCadence.oneTime)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.flag_outlined),
                            title: Text(_tr(context, 'End date', 'Date fin')),
                            subtitle: Text(
                              endDate == null
                                  ? _tr(context, 'No end date', 'Sans date fin')
                                  : DateUtilsX.short(
                                      endDate!,
                                      localeCode: settings.localeCode,
                                    ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (endDate != null)
                                  IconButton(
                                    onPressed: () {
                                      setDialogState(() => endDate = null);
                                    },
                                    icon: const Icon(Icons.clear_rounded),
                                  ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            onTap: pickEndDate,
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteController,
                          decoration: InputDecoration(
                            hintText: _tr(context, 'Note', 'Note'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(_tr(context, 'Cancel', 'Annuler')),
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

                        await tools.addRecurringPlan(
                          amount: amount,
                          category: selectedCategory,
                          cadence: selectedCadence,
                          anchorDate: anchorDate,
                          note: noteController.text.trim().isEmpty
                              ? _ta(
                                  context,
                                  'Planned {category}',
                                  <String, String>{
                                    'category': selectedCategory.localizedLabel(
                                      settings.localeCode,
                                    ),
                                  },
                                  'Planifie : {category}',
                                )
                              : noteController.text.trim(),
                          currencyCode: settings.currencyCode,
                          endDate: selectedCadence == PlannedCadence.oneTime
                              ? null
                              : endDate,
                        );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      child: Text(_tr(context, 'Save', 'Enregistrer')),
                    ),
                  ],
                );
              },
        );
      },
    );

    amountController.dispose();
    noteController.dispose();
  }

  Future<void> _runOcr({
    required BuildContext context,
    required ToolsController tools,
    required ImageSource source,
    required ExpenseController expenses,
    required SettingsController settings,
  }) async {
    if (!settings.isPro) {
      await _showOcrProGate(context);
      return;
    }

    setState(() => _busyOcr = true);
    OcrScanResult? scanResult;
    try {
      scanResult = await tools.scanReceipt(source);
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(
        _tr(context, 'OCR failed or canceled.', 'OCR echoue ou annule.'),
      );
      return;
    } finally {
      if (mounted) setState(() => _busyOcr = false);
    }
    if (!context.mounted) return;

    final OcrScanResult? result = scanResult;
    if (result == null) {
      final String? errorMessage = tools.lastOcrError;
      _showSnack(
        errorMessage ??
            _tr(context, 'OCR failed or canceled.', 'OCR echoue ou annule.'),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }

    ExpenseCategory selectedCategory = ExpenseCategory.other;
    final TextEditingController noteController = TextEditingController(
      text: result.suggestedNote,
    );
    final TextEditingController amountController = TextEditingController(
      text: result.amount?.toStringAsFixed(2) ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(_tr(context, 'OCR Result', 'Resultat OCR')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: _tr(context, 'Amount', 'Montant'),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ExpenseCategory>(
                  isExpanded: true,
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
                      .toList(),
                  onChanged: (ExpenseCategory? value) {
                    if (value != null) {
                      selectedCategory = value;
                    }
                  },
                  decoration: InputDecoration(
                    hintText: _tr(context, 'Category', 'Categorie'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    hintText: _tr(context, 'Note', 'Note'),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tr(context, 'Cancel', 'Annuler')),
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

                final OcrScanResult edited = OcrScanResult(
                  rawText: result.rawText,
                  amount: amount,
                  date: result.date,
                  suggestedNote: noteController.text.trim().isEmpty
                      ? result.suggestedNote
                      : noteController.text.trim(),
                );

                final bool saved = await tools.addExpenseFromOcr(
                  result: edited,
                  category: selectedCategory,
                  expenseController: expenses,
                  currencyCode: settings.currencyCode,
                  accountId: settings.activeBankAccountId,
                );
                if (saved) {
                  await tools.evaluateBudgets(
                    expenses: expenses.expensesForAccount(
                      settings.activeBankAccountId,
                    ),
                    currencyCode: settings.currencyCode,
                  );
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (!context.mounted) return;
                _showSnack(
                  saved
                      ? _tr(
                          context,
                          'Expense added from OCR.',
                          'Depense ajoutee depuis OCR.',
                        )
                      : _tr(
                          context,
                          'Invalid OCR amount.',
                          'Montant OCR invalide.',
                        ),
                );
              },
              child: Text(_tr(context, 'Save Expense', 'Enregistrer depense')),
            ),
          ],
        );
      },
    );

    noteController.dispose();
    amountController.dispose();
  }

  Future<void> _runStatementOcr({
    required BuildContext context,
    required ToolsController tools,
    required ImageSource source,
    required ExpenseController expenses,
    required SettingsController settings,
  }) async {
    if (!settings.isPro) {
      await _showOcrProGate(context);
      return;
    }

    setState(() => _busyStatementOcr = true);
    BankStatementScanResult? scanResult;
    try {
      scanResult = await tools.scanBankStatement(source);
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(
        _tr(
          context,
          'Statement scan failed or canceled.',
          'Scan du relevé echoue ou annule.',
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _busyStatementOcr = false);
    }
    if (!context.mounted) return;

    final BankStatementScanResult? result = scanResult;
    if (result == null) {
      final String? errorMessage = tools.lastStatementScanError;
      _showSnack(
        errorMessage ??
            _tr(
              context,
              'Statement scan failed or canceled.',
              'Scan du relevé echoue ou annule.',
            ),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }

    // Chaque transaction reste un objet mutable (voir ScannedTransaction):
    // les champs amount/description/suggestedCategory/included sont modifies
    // directement par les controles ci-dessous, pas besoin de reconstruire
    // toute la liste a chaque frappe.
    final List<ScannedTransaction> transactions = result.transactions;
    final List<TextEditingController> amountControllers = transactions
        .map(
          (ScannedTransaction t) =>
              TextEditingController(text: t.amount.toStringAsFixed(2)),
        )
        .toList(growable: false);
    final List<TextEditingController> noteControllers = transactions
        .map((ScannedTransaction t) => TextEditingController(text: t.description))
        .toList(growable: false);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          // Nomme volontairement "builderContext" (et non "context") pour ne
          // PAS masquer le `context` de la page qui englobe ce dialogue: le
          // controle `context.mounted` plus bas, apres la fermeture du
          // dialogue, doit verifier que la PAGE est toujours montee, pas ce
          // dialogue qu'on vient justement de fermer.
          builder: (BuildContext builderContext, StateSetter setDialogState) {
            final int includedCount = transactions
                .where((ScannedTransaction t) => t.included)
                .length;
            return AlertDialog(
              title: Text(
                _ta(
                  builderContext,
                  'Review {count} transaction(s)',
                  <String, String>{'count': transactions.length.toString()},
                  'Verifier {count} transaction(s)',
                ),
              ),
              content: SizedBox(
                width: 480,
                height: 420,
                child: ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 20),
                  itemBuilder: (BuildContext context, int index) {
                    final ScannedTransaction t = transactions[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Checkbox(
                          value: t.included,
                          onChanged: (bool? value) {
                            setDialogState(() => t.included = value ?? false);
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Expanded(
                                    child: TextField(
                                      controller: amountControllers[index],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: _tr(
                                          context,
                                          'Amount',
                                          'Montant',
                                        ),
                                      ),
                                      onChanged: (String value) {
                                        final double? parsed = double.tryParse(
                                          value.replaceAll(',', '.'),
                                        );
                                        if (parsed != null) {
                                          t.amount = parsed;
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    t.date == null
                                        ? '-'
                                        : DateUtilsX.short(
                                            t.date!,
                                            localeCode: settings.localeCode,
                                          ),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: noteControllers[index],
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: _tr(context, 'Note', 'Note'),
                                ),
                                onChanged: (String value) =>
                                    t.description = value,
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<ExpenseCategory>(
                                isExpanded: true,
                                initialValue: t.suggestedCategory,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: _tr(
                                    context,
                                    'Category',
                                    'Categorie',
                                  ),
                                ),
                                items: ExpenseCategory.values
                                    .map(
                                      (ExpenseCategory c) =>
                                          DropdownMenuItem<ExpenseCategory>(
                                            value: c,
                                            child: Text(
                                              c.localizedLabel(
                                                settings.localeCode,
                                              ),
                                            ),
                                          ),
                                    )
                                    .toList(),
                                onChanged: (ExpenseCategory? value) {
                                  if (value != null) {
                                    t.suggestedCategory = value;
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(_tr(builderContext, 'Cancel', 'Annuler')),
                ),
                ElevatedButton(
                  onPressed: includedCount == 0
                      ? null
                      : () async {
                          final int added = await tools
                              .addExpensesFromBankStatement(
                                transactions: transactions,
                                expenseController: expenses,
                                currencyCode: settings.currencyCode,
                                accountId: settings.activeBankAccountId,
                              );
                          await tools.evaluateBudgets(
                            expenses: expenses.expensesForAccount(
                              settings.activeBankAccountId,
                            ),
                            currencyCode: settings.currencyCode,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (!context.mounted) return;
                          _showSnack(
                            _ta(
                              context,
                              '{count} transaction(s) imported.',
                              <String, String>{'count': added.toString()},
                              '{count} transaction(s) importee(s).',
                            ),
                          );
                        },
                  child: Text(
                    _ta(
                      builderContext,
                      'Import {count}',
                      <String, String>{'count': includedCount.toString()},
                      'Importer {count}',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    for (final TextEditingController c in amountControllers) {
      c.dispose();
    }
    for (final TextEditingController c in noteControllers) {
      c.dispose();
    }
  }

  Future<void> _showOcrProGate(BuildContext context) async {
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
                          _tr(
                            context,
                            'Scan Receipt is Pro',
                            'Scan facture est Pro',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                    _tr(
                      context,
                      'Upgrade to Pro to unlock OCR receipt scanner.',
                      'Passez Pro pour activer le scanner OCR.',
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
                      label: Text(
                        _tr(context, 'Upgrade to Pro', 'Passer a Pro'),
                      ),
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

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _tr(BuildContext context, String en, String fr) {
    return context.l10n.phrase(en, french: fr);
  }

  String _ta(
    BuildContext context,
    String en,
    Map<String, String> args,
    String fr,
  ) {
    return context.l10n.phraseWithArgs(en, args, french: fr);
  }

  String _localizeNoticeText(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return text;
    }

    final String direct = context.l10n.phrase(trimmed);
    if (direct != trimmed) {
      return direct;
    }

    final RegExp usageReached = RegExp(r'^Usage Reached (\d+)%$');
    final Match? usageMatch = usageReached.firstMatch(trimmed);
    if (usageMatch != null) {
      return context.l10n.phraseWithArgs(
        'Usage Reached {percent}%',
        <String, String>{'percent': usageMatch.group(1)!},
        french: 'Utilisation atteinte a {percent}%',
      );
    }

    final RegExp recurringAdded = RegExp(
      r'^(\d+) recurring expense\(s\) added automatically\.$',
    );
    final Match? recurringMatch = recurringAdded.firstMatch(trimmed);
    if (recurringMatch != null) {
      return context.l10n.phraseWithArgs(
        '{count} recurring expense(s) added automatically.',
        <String, String>{'count': recurringMatch.group(1)!},
        french: '{count} depense(s) recurrente(s) ajoutee(s) automatiquement.',
      );
    }

    final RegExp spentThisMonth = RegExp(r'^Spent (.+) this month\.$');
    final Match? spentMatch = spentThisMonth.firstMatch(trimmed);
    if (spentMatch != null) {
      return context.l10n.phraseWithArgs(
        'Spent {amount} this month.',
        <String, String>{'amount': spentMatch.group(1)!},
        french: 'Depense {amount} ce mois-ci.',
      );
    }

    final RegExp budgetAddedFor = RegExp(r'^Budget added for (.+)\.$');
    final Match? budgetAddedMatch = budgetAddedFor.firstMatch(trimmed);
    if (budgetAddedMatch != null) {
      return context.l10n.phraseWithArgs(
        'Budget added for {category}.',
        <String, String>{'category': budgetAddedMatch.group(1)!},
        french: 'Budget ajoute pour {category}.',
      );
    }

    final RegExp usedSpendable = RegExp(
      r'^You used (.+) of (.+) spendable budget\.$',
    );
    final Match? usedSpendableMatch = usedSpendable.firstMatch(trimmed);
    if (usedSpendableMatch != null) {
      return context.l10n.phraseWithArgs(
        'You used {spent} of {limit} spendable budget.',
        <String, String>{
          'spent': usedSpendableMatch.group(1)!,
          'limit': usedSpendableMatch.group(2)!,
        },
        french: 'Vous avez utilise {spent} sur {limit} de budget depensable.',
      );
    }

    final RegExp syncedCloud = RegExp(
      r'^(\d+) expense\(s\) synced to cloud\.$',
    );
    final Match? syncedCloudMatch = syncedCloud.firstMatch(trimmed);
    if (syncedCloudMatch != null) {
      return context.l10n.phraseWithArgs(
        '{count} expense(s) synced to cloud.',
        <String, String>{'count': syncedCloudMatch.group(1)!},
        french: '{count} depense(s) synchronisee(s) vers le cloud.',
      );
    }

    final RegExp loadedCsv = RegExp(r'^(\d+) expense\(s\) loaded from CSV\.$');
    final Match? loadedCsvMatch = loadedCsv.firstMatch(trimmed);
    if (loadedCsvMatch != null) {
      return context.l10n.phraseWithArgs(
        '{count} expense(s) loaded from CSV.',
        <String, String>{'count': loadedCsvMatch.group(1)!},
        french: '{count} depense(s) chargee(s) depuis CSV.',
      );
    }

    final RegExp mergedCloud = RegExp(
      r'^(\d+) new expense\(s\) merged from cloud\.$',
    );
    final Match? mergedCloudMatch = mergedCloud.firstMatch(trimmed);
    if (mergedCloudMatch != null) {
      return context.l10n.phraseWithArgs(
        '{count} new expense(s) merged from cloud.',
        <String, String>{'count': mergedCloudMatch.group(1)!},
        french: '{count} nouvelle(s) depense(s) fusionnee(s) depuis le cloud.',
      );
    }

    final RegExp categoryCadence = RegExp(r'^(.+) planned as (.+) schedule\.$');
    final Match? categoryCadenceMatch = categoryCadence.firstMatch(trimmed);
    if (categoryCadenceMatch != null) {
      return context.l10n.phraseWithArgs(
        '{category} planned as {cadence} schedule.',
        <String, String>{
          'category': categoryCadenceMatch.group(1)!,
          'cadence': categoryCadenceMatch.group(2)!,
        },
        french: '{category} planifie en frequence {cadence}.',
      );
    }

    final RegExp targetReached = RegExp(r'^(.+) reached (\d+)%$');
    final Match? targetReachedMatch = targetReached.firstMatch(trimmed);
    if (targetReachedMatch != null) {
      return context.l10n
          .phraseWithArgs('{target} reached {percent}%', <String, String>{
            'target': targetReachedMatch.group(1)!,
            'percent': targetReachedMatch.group(2)!,
          }, french: '{target} atteint a {percent}%');
    }

    return text;
  }
}

class _ToolGuideItem {
  const _ToolGuideItem({
    required this.icon,
    required this.title,
    required this.summary,
    required this.example,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String summary;
  final String example;
  final Color color;
}
