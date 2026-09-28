import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/models/advisor_message.dart';
import 'package:wfer_flousk_firebase/core/services/finance_chatbot_service.dart';
import 'package:wfer_flousk_firebase/core/services/financial_advisor_service.dart';
import 'package:wfer_flousk_firebase/core/widgets/fintech_page_app_bar.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/core/widgets/responsive_page_body.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';

class FinanceChatbotPage extends StatefulWidget {
  const FinanceChatbotPage({super.key});

  @override
  State<FinanceChatbotPage> createState() => _FinanceChatbotPageState();
}

class _FinanceChatbotPageState extends State<FinanceChatbotPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FinanceChatbotService _chatbot = const FinanceChatbotService();
  final List<_ChatMessage> _messages = <_ChatMessage>[];

  bool _isReplying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistoryOrWelcome();
    });
  }

  /// A CHAQUE ouverture de cet ecran, on repart d'une conversation neuve
  /// (juste le message de bienvenue), plutot que de recharger les anciens
  /// messages depuis Firestore: l'utilisateur trouvait que revoir toujours
  /// les memes vieux messages donnait une impression d'ecran surcharge.
  /// (L'ancien comportement rechargeait l'historique via
  /// [FinancialAdvisorService.loadHistory] pour donner au chat une
  /// "memoire" visuelle d'une session a l'autre ; ce n'est plus le cas ici,
  /// mais les messages restent quand meme enregistres sur Firebase via
  /// [FinancialAdvisorService.appendMessage] a chaque envoi, au cas ou ils
  /// redeviendraient utiles plus tard.)
  Future<void> _loadHistoryOrWelcome() async {
    if (!mounted) {
      return;
    }
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsivePageBody(
            top: 8,
            bottom: 10,
            child: Column(
              children: <Widget>[
                FintechPageAppBar(
                  title: _tr(
                    context,
                    'Finance Chatbot',
                    'Chatbot financier',
                    ar: 'شات بوت مالي',
                  ),
                  showBackToHome: true,
                ),
                const SizedBox(height: UiTokens.spacingXs),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    itemCount: _messages.length + 1,
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _headerCard(context),
                        );
                      }
                      return _messageBubble(context, _messages[index - 1]);
                    },
                  ),
                ),
                if (_isReplying)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _tr(
                          context,
                          'Assistant is typing...',
                          'Assistant ecrit...',
                          ar: 'المساعد يكتب...',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _composer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _tr(
              context,
              'Ask about app features, income, spending, budget, wallets, Pro plan, tools and settings.',
              'Posez des questions sur revenu, depenses, budget, solde, plans et epargne.',
              ar: 'اسأل عن ميزات التطبيق والدخل والمصاريف والميزانية والمحافظ وخطة Pro والأدوات والإعدادات.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickPrompts(context)
                .map(
                  (String prompt) => ActionChip(
                    label: Text(prompt),
                    onPressed: () => _sendMessage(prompt),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(BuildContext context, _ChatMessage message) {
    final bool fromUser = message.fromUser;
    final Color bubbleColor = fromUser
        ? const Color(0xFF1976D2).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.09);

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(
            message.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: fromUser ? 0.98 : 0.92),
              height: 1.28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (String value) {
                _sendMessage(value);
              },
              decoration: InputDecoration(
                hintText: _tr(
                  context,
                  'Type your question...',
                  'Ecrivez votre question...',
                  ar: 'اكتب سؤالك...',
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _sendMessage(_inputController.text),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  void _addWelcomeMessage() {
    if (!mounted || _messages.isNotEmpty) {
      return;
    }
    final SettingsController settings = context.read<SettingsController>();
    final FinanceChatbotSnapshot snapshot = _buildSnapshot();

    final String welcome = _chatbot.openingMessage(
      localeCode: settings.localeCode,
      snapshot: snapshot,
      firstName: settings.userFirstName,
    );

    setState(() {
      _messages.add(_ChatMessage(text: welcome, fromUser: false));
    });
  }

  Future<void> _sendMessage(String rawText) async {
    final String text = rawText.trim();
    if (text.isEmpty || _isReplying) {
      return;
    }

    final FinancialAdvisorService advisor = context
        .read<FinancialAdvisorService>();

    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _isReplying = true;
    });
    _scrollToBottom();
    unawaited(
      advisor.appendMessage(
        AdvisorMessage(role: 'user', content: text, timestamp: DateTime.now()),
      ),
    );

    final SettingsController settings = context.read<SettingsController>();
    final FinanceChatbotSnapshot snapshot = _buildSnapshot();

    String reply;
    try {
      // Agent conseiller IA (voir financial_advisor_service.dart) : il
      // consulte l'archive documentaire de l'utilisateur et repond
      // directement via l'API Groq.
      reply = await advisor.ask(question: text, snapshot: snapshot.toMap());
    } catch (error) {
      // Filet de securite hors-ligne / si la cle Groq n'est pas (encore)
      // configuree : le chatbot a mots-cles prend le relais, l'utilisateur
      // n'est jamais bloque sans reponse. On journalise quand meme la
      // cause exacte (visible dans le terminal `flutter run` ou Logcat)
      // pour pouvoir diagnostiquer pourquoi l'IA n'a pas repondu.
      debugPrint('Agent conseiller IA indisponible, repli local -> $error');
      final String fallback = _chatbot.reply(
        localeCode: settings.localeCode,
        message: text,
        snapshot: snapshot,
      );
      // TEMPORAIRE (diagnostic) : affiche la cause exacte directement dans
      // le chat, pour ne pas avoir a chercher dans les logs du telephone.
      // A retirer une fois le probleme de l'agent IA resolu.
      reply = '$fallback\n\n[DEBUG] $error';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: reply, fromUser: false));
      _isReplying = false;
    });
    _scrollToBottom();
    unawaited(
      advisor.appendMessage(
        AdvisorMessage(
          role: 'assistant',
          content: reply,
          timestamp: DateTime.now(),
        ),
      ),
    );
  }

  FinanceChatbotSnapshot _buildSnapshot() {
    final SettingsController settings = context.read<SettingsController>();
    final ExpenseController expenses = context.read<ExpenseController>();
    final ToolsController tools = context.read<ToolsController>();

    final String accountId = settings.activeBankAccountId;
    final List<Expense> list = expenses.expensesForAccount(accountId);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime weekStart = today.subtract(
      Duration(days: today.weekday - 1),
    );
    final int totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final int daysElapsedInMonth = now.day.clamp(1, totalDaysInMonth);
    final int remainingDaysInMonth = max(totalDaysInMonth - now.day, 0);

    double monthlySpending = 0;
    double monthlyRecordedIncome = 0;
    double todaySpending = 0;
    double todayIncome = 0;
    double weeklySpending = 0;
    double weeklyIncome = 0;
    int transactionsThisMonth = 0;
    // Totaux tous historiques confondus (voir commentaire sur
    // FinanceChatbotSnapshot.totalSpendingAllTime) : calcules sur TOUTES
    // les depenses, meme celles d'un mois different du mois en cours (par
    // exemple un releve bancaire PDF importe qui couvre des mois passes).
    double totalSpendingAllTime = 0;
    double totalIncomeAllTime = 0;
    int totalTransactionsAllTime = 0;
    final Map<String, double> categoryTotals = <String, double>{};
    final Map<String, String> categoryDisplayNames = <String, String>{};

    for (final Expense item in list) {
      if (item.isTransfer) {
        continue;
      }

      final DateTime itemDay = DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
      );
      final bool isToday = itemDay == today;
      final bool isInWeek =
          !itemDay.isBefore(weekStart) && !itemDay.isAfter(today);
      final bool isCurrentMonth =
          item.date.year == now.year && item.date.month == now.month;

      totalTransactionsAllTime += 1;
      if (item.amount > 0) {
        totalSpendingAllTime += item.amount;
      } else {
        totalIncomeAllTime += item.amount.abs();
      }

      if (isToday) {
        if (item.amount > 0) {
          todaySpending += item.amount;
        } else {
          todayIncome += item.amount.abs();
        }
      }

      if (isInWeek) {
        if (item.amount > 0) {
          weeklySpending += item.amount;
        } else {
          weeklyIncome += item.amount.abs();
        }
      }

      if (!isCurrentMonth) {
        continue;
      }

      transactionsThisMonth += 1;
      if (item.amount > 0) {
        monthlySpending += item.amount;
        final String label = item.categoryLabel(settings.localeCode).trim();
        final String key = item.isCustomCategory
            ? 'custom:${label.toLowerCase()}'
            : item.category.key;
        categoryTotals[key] = (categoryTotals[key] ?? 0) + item.amount;
        if (label.isNotEmpty) {
          categoryDisplayNames[key] = label;
        } else {
          categoryDisplayNames[key] = item.category.localizedLabel(
            settings.localeCode,
          );
        }
      } else {
        monthlyRecordedIncome += item.amount.abs();
      }
    }

    String? topCategoryKey;
    double topCategoryAmount = 0;
    categoryTotals.forEach((String key, double amount) {
      if (amount > topCategoryAmount) {
        topCategoryKey = key;
        topCategoryAmount = amount;
      }
    });

    final double monthlyIncome = settings.monthlyIncome + monthlyRecordedIncome;
    final double spendableBudget = max(
      monthlyIncome - settings.monthlySavingsGoal,
      0,
    );
    final double remainingBudget = spendableBudget - monthlySpending;
    final double currentBalance = monthlyIncome - monthlySpending;
    final double averageDailySpending =
        monthlySpending / max(daysElapsedInMonth, 1);
    final double projectedMonthlySpending =
        averageDailySpending * totalDaysInMonth;
    final int activeRecurringCount = tools.recurringPlans
        .where((plan) => plan.isActive)
        .length;

    return FinanceChatbotSnapshot(
      currencyCode: settings.currencyCode,
      configuredMonthlyIncome: settings.monthlyIncome,
      recordedIncomeThisMonth: monthlyRecordedIncome,
      localeCode: settings.localeCode,
      languageLabel: context.l10n.languageLabel(settings.localeCode),
      themeModeKey: settings.themeMode.name,
      monthlyIncome: monthlyIncome,
      monthlySpending: monthlySpending,
      totalSpendingAllTime: totalSpendingAllTime,
      totalIncomeAllTime: totalIncomeAllTime,
      totalTransactionsAllTime: totalTransactionsAllTime,
      todaySpending: todaySpending,
      todayIncome: todayIncome,
      weeklySpending: weeklySpending,
      weeklyIncome: weeklyIncome,
      monthlySavingsGoal: settings.monthlySavingsGoal,
      spendableBudget: spendableBudget,
      remainingBudget: remainingBudget,
      currentBalance: currentBalance,
      averageDailySpending: averageDailySpending,
      projectedMonthlySpending: projectedMonthlySpending,
      daysElapsedInMonth: daysElapsedInMonth,
      remainingDaysInMonth: remainingDaysInMonth,
      transactionsThisMonth: transactionsThisMonth,
      topCategoryLabel: topCategoryKey == null
          ? null
          : categoryDisplayNames[topCategoryKey!],
      topCategoryAmount: topCategoryAmount,
      budgetCount: tools.budgets.length,
      recurringCount: tools.recurringPlans.length,
      activeRecurringCount: activeRecurringCount,
      categorySpending: Map<String, double>.unmodifiable(categoryTotals),
      categoryDisplayNames: Map<String, String>.unmodifiable(
        categoryDisplayNames,
      ),
      walletCount: settings.bankAccounts.length,
      activeWalletName: settings.displayBankAccountName(
        settings.activeBankAccount,
      ),
      isPro: settings.isPro,
      freeWalletLimit: settings.freeWalletLimit,
      unreadNoticeCount: tools.unreadNoticeCount,
      biometricEnabled: tools.biometricEnabled,
      pinEnabled: tools.pinEnabled,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  List<String> _quickPrompts(BuildContext context) {
    return <String>[
      _tr(
        context,
        'How much incoming this month?',
        'Combien de revenu ce mois?',
        ar: 'كم الدخل هذا الشهر؟',
      ),
      _tr(
        context,
        'How much did I spend this week?',
        'Combien ai-je depense cette semaine?',
        ar: 'كم صرفت هذا الأسبوع؟',
      ),
      _tr(
        context,
        'What is my net cashflow this month?',
        'Quel est mon cashflow net ce mois?',
        ar: 'ما هو صافي التدفق المالي هذا الشهر؟',
      ),
      _tr(
        context,
        'How much on food this month?',
        'Combien pour nourriture ce mois?',
        ar: 'كم صرفت على الأكل هذا الشهر؟',
      ),
      _tr(
        context,
        'Can I spend 50?',
        'Puis-je depenser 50?',
        ar: 'هل يمكنني صرف 50؟',
      ),
      _tr(
        context,
        'How many wallets can I use?',
        'Combien de portefeuilles puis-je utiliser ?',
        ar: 'كم عدد المحافظ التي يمكنني استخدامها؟',
      ),
      _tr(
        context,
        'How do I change app language?',
        'Comment changer la langue de l application ?',
        ar: 'كيف أغير لغة التطبيق؟',
      ),
    ];
  }

  String _tr(BuildContext context, String en, String fr, {String? ar}) {
    final String localeCode = context.read<SettingsController>().localeCode;
    final String code = AppLocalizations.normalizeLanguageCode(localeCode);
    if (code == 'ar' && ar != null && ar.trim().isNotEmpty) {
      return ar;
    }
    return context.l10n.phrase(en, french: fr);
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}
