import 'dart:math';

import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';

class FinanceChatbotSnapshot {
  const FinanceChatbotSnapshot({
    required this.currencyCode,
    required this.localeCode,
    required this.languageLabel,
    required this.themeModeKey,
    required this.configuredMonthlyIncome,
    required this.recordedIncomeThisMonth,
    required this.monthlyIncome,
    required this.monthlySpending,
    required this.todaySpending,
    required this.todayIncome,
    required this.weeklySpending,
    required this.weeklyIncome,
    required this.monthlySavingsGoal,
    required this.spendableBudget,
    required this.remainingBudget,
    required this.currentBalance,
    required this.averageDailySpending,
    required this.projectedMonthlySpending,
    required this.daysElapsedInMonth,
    required this.remainingDaysInMonth,
    required this.transactionsThisMonth,
    required this.topCategoryLabel,
    required this.topCategoryAmount,
    required this.budgetCount,
    required this.recurringCount,
    required this.activeRecurringCount,
    required this.categorySpending,
    required this.categoryDisplayNames,
    required this.walletCount,
    required this.activeWalletName,
    required this.isPro,
    required this.freeWalletLimit,
    required this.unreadNoticeCount,
    required this.biometricEnabled,
    required this.pinEnabled,
  });

  final String currencyCode;
  final String localeCode;
  final String languageLabel;
  final String themeModeKey;
  final double configuredMonthlyIncome;
  final double recordedIncomeThisMonth;
  final double monthlyIncome;
  final double monthlySpending;
  final double todaySpending;
  final double todayIncome;
  final double weeklySpending;
  final double weeklyIncome;
  final double monthlySavingsGoal;
  final double spendableBudget;
  final double remainingBudget;
  final double currentBalance;
  final double averageDailySpending;
  final double projectedMonthlySpending;
  final int daysElapsedInMonth;
  final int remainingDaysInMonth;
  final int transactionsThisMonth;
  final String? topCategoryLabel;
  final double topCategoryAmount;
  final int budgetCount;
  final int recurringCount;
  final int activeRecurringCount;
  final Map<String, double> categorySpending;
  final Map<String, String> categoryDisplayNames;
  final int walletCount;
  final String activeWalletName;
  final bool isPro;
  final int freeWalletLimit;
  final int unreadNoticeCount;
  final bool biometricEnabled;
  final bool pinEnabled;
}

class FinanceChatbotService {
  const FinanceChatbotService();

  static const Map<String, String> _categoryAliases = <String, String>{
    'food': 'food',
    'meal': 'food',
    'nourriture': 'food',
    'makla': 'food',
    'طعام': 'food',
    'transport': 'transport',
    'na9l': 'transport',
    'نقل': 'transport',
    'rent': 'rent',
    'loyer': 'rent',
    'kira': 'rent',
    'إيجار': 'rent',
    'shopping': 'shopping',
    'achats': 'shopping',
    'شراء': 'shopping',
    'bills': 'bills',
    'factures': 'bills',
    'فواتير': 'bills',
    'other': 'other',
    'autre': 'other',
    'أخرى': 'other',
  };

  String openingMessage({
    required String localeCode,
    required FinanceChatbotSnapshot snapshot,
    String? firstName,
  }) {
    final String greet = (firstName ?? '').trim().isEmpty
        ? _p(
            localeCode,
            'Hi, I am your finance assistant.',
            'Salut, je suis votre assistant financier.',
            ar: 'مرحبا، أنا مساعدك المالي.',
          )
        : _pa(
            localeCode,
            'Hi {name}, I am your finance assistant.',
            <String, String>{'name': (firstName ?? '').trim()},
            'Salut {name}, je suis votre assistant financier.',
            ar: 'مرحبا {name}، أنا مساعدك المالي.',
          );

    final String summary = _pa(
      localeCode,
      'This month: incoming {income}, spending {spent}, remaining budget {remaining}.',
      <String, String>{
        'income': _a(snapshot.monthlyIncome, snapshot.currencyCode),
        'spent': _a(snapshot.monthlySpending, snapshot.currencyCode),
        'remaining': _a(snapshot.remainingBudget, snapshot.currencyCode),
      },
      'Ce mois : revenu {income}, depense {spent}, budget restant {remaining}.',
      ar: 'هذا الشهر: الدخل {income}، المصروف {spent}، المتبقي {remaining}.',
    );

    final String hint = _p(
      localeCode,
      'Ask me about income, spending, wallets, Pro plan, tools, settings, exports and security.',
      'Demandez sur revenu, depenses, portefeuilles, plan Pro, outils, parametres, export et securite.',
      ar: 'اسألني عن الدخل والمصاريف والمحافظ وخطة Pro والأدوات والإعدادات والتصدير والأمان.',
    );
    return '$greet\n$summary\n$hint';
  }

  String reply({
    required String localeCode,
    required String message,
    required FinanceChatbotSnapshot snapshot,
  }) {
    final String input = _normalize(message);
    if (input.isEmpty) {
      return _p(
        localeCode,
        'Please type a question.',
        'Ecrivez une question.',
        ar: 'اكتب سؤالك.',
      );
    }

    final bool asksToday = _containsAny(input, <String>[
      'today',
      'aujour',
      'lyom',
      'اليوم',
    ]);
    final bool asksWeek = _containsAny(input, <String>[
      'week',
      'semaine',
      'simana',
      'الأسبوع',
    ]);
    final double? amount = _extractFirstAmount(input);
    final String? categoryKey = _findCategoryKey(input, snapshot);

    if (_containsAny(input, <String>[
      'help',
      'aide',
      'what can you do',
      'مساعدة',
    ])) {
      return _help(localeCode);
    }

    if (_containsAny(input, <String>[
      'language',
      'langue',
      'currency',
      'devise',
      'theme',
      'dark mode',
      'settings',
      'إعدادات',
      'لغة',
      'عملة',
    ])) {
      return _settingsReply(localeCode, snapshot, input);
    }

    if (_containsAny(input, <String>[
      'wallet',
      'account',
      'bank',
      'portefeuille',
      'switch',
      'compte',
      'محفظة',
      'حساب',
    ])) {
      return _walletReply(localeCode, snapshot, input);
    }

    if (_containsAny(input, <String>[
      'pro',
      'upgrade',
      'premium',
      'free plan',
      'ترقية',
      'مدفوع',
    ])) {
      return _proReply(localeCode, snapshot);
    }

    if (_containsAny(input, <String>[
      'csv',
      'ocr',
      'scan',
      'receipt',
      'backup',
      'restore',
      'pdf',
      'excel',
      'pin',
      'biometric',
      'tools',
      'تصدير',
      'نسخ احتياطي',
      'بصمة',
    ])) {
      return _featuresReply(localeCode, snapshot, input);
    }

    if (amount != null &&
        _containsAny(input, <String>[
          'can i spend',
          'spend',
          'buy',
          'depense',
          'n9dar',
          'صرف',
        ])) {
      return _canSpendReply(localeCode, snapshot, amount);
    }

    if (_containsAny(input, <String>[
      'income',
      'incoming',
      'inflow',
      'revenu',
      'dakhl',
      'دخل',
    ])) {
      return _incomeReply(
        localeCode,
        snapshot,
        asksToday: asksToday,
        asksWeek: asksWeek,
      );
    }

    if (_containsAny(input, <String>[
      'net',
      'cashflow',
      'difference',
      'صافي',
    ])) {
      final double net = snapshot.monthlyIncome - snapshot.monthlySpending;
      return net >= 0
          ? _pa(
              localeCode,
              'Net cashflow this month is +{net}.',
              <String, String>{'net': _a(net, snapshot.currencyCode)},
              'Le cashflow net ce mois est +{net}.',
              ar: 'صافي التدفق المالي هذا الشهر هو +{net}.',
            )
          : _pa(
              localeCode,
              'Net cashflow this month is {net} (negative).',
              <String, String>{'net': _a(net, snapshot.currencyCode)},
              'Le cashflow net ce mois est {net} (negatif).',
              ar: 'صافي التدفق المالي هذا الشهر هو {net} (سلبي).',
            );
    }

    if (categoryKey != null &&
        _containsAny(input, <String>[
          'spend',
          'expense',
          'depense',
          'how much on',
          'مصروف',
          'انفاق',
        ])) {
      final double v = snapshot.categorySpending[categoryKey] ?? 0;
      final String name =
          snapshot.categoryDisplayNames[categoryKey] ??
          _humanizeCategory(categoryKey);
      return v <= 0
          ? _pa(
              localeCode,
              'No spending recorded for {category} this month.',
              <String, String>{'category': name},
              'Aucune depense enregistree pour {category} ce mois.',
              ar: 'لا توجد مصاريف مسجلة لفئة {category} هذا الشهر.',
            )
          : _pa(
              localeCode,
              'This month you spent {amount} on {category}.',
              <String, String>{
                'amount': _a(v, snapshot.currencyCode),
                'category': name,
              },
              'Ce mois vous avez depense {amount} pour {category}.',
              ar: 'هذا الشهر صرفت {amount} على {category}.',
            );
    }

    if (_containsAny(input, <String>[
      'spend',
      'expense',
      'outgoing',
      'depense',
      'مصروف',
      'انفاق',
    ])) {
      if (asksToday) {
        return _pa(
          localeCode,
          'Today: incoming {income}, spending {spent}.',
          <String, String>{
            'income': _a(snapshot.todayIncome, snapshot.currencyCode),
            'spent': _a(snapshot.todaySpending, snapshot.currencyCode),
          },
          'Aujourd hui : revenu {income}, depense {spent}.',
          ar: 'اليوم: الدخل {income}، المصروف {spent}.',
        );
      }
      if (asksWeek) {
        return _pa(
          localeCode,
          'This week: incoming {income}, spending {spent}.',
          <String, String>{
            'income': _a(snapshot.weeklyIncome, snapshot.currencyCode),
            'spent': _a(snapshot.weeklySpending, snapshot.currencyCode),
          },
          'Cette semaine : revenu {income}, depense {spent}.',
          ar: 'هذا الأسبوع: الدخل {income}، المصروف {spent}.',
        );
      }
      return _pa(
        localeCode,
        'This month: spending {spent}, incoming {income}, daily average {daily}, projected month-end spending {projected}, transactions {count}.',
        <String, String>{
          'spent': _a(snapshot.monthlySpending, snapshot.currencyCode),
          'income': _a(snapshot.monthlyIncome, snapshot.currencyCode),
          'daily': _a(snapshot.averageDailySpending, snapshot.currencyCode),
          'projected': _a(
            snapshot.projectedMonthlySpending,
            snapshot.currencyCode,
          ),
          'count': '${snapshot.transactionsThisMonth}',
        },
        'Ce mois : depenses {spent}, revenu {income}, moyenne/jour {daily}, projection {projected}, transactions {count}.',
        ar: 'هذا الشهر: المصروف {spent}، الدخل {income}، المتوسط اليومي {daily}، التوقع {projected}، العمليات {count}.',
      );
    }

    if (_containsAny(input, <String>[
      'budget',
      'remaining',
      'restant',
      'ba9i',
      'limit',
      'ميزانية',
      'المتبقي',
    ])) {
      final String base = _pa(
        localeCode,
        'Spendable budget is {budget}. Remaining budget is {remaining}. Savings goal is {goal}.',
        <String, String>{
          'budget': _a(snapshot.spendableBudget, snapshot.currencyCode),
          'remaining': _a(snapshot.remainingBudget, snapshot.currencyCode),
          'goal': _a(snapshot.monthlySavingsGoal, snapshot.currencyCode),
        },
        'Le budget depensable est {budget}. Le budget restant est {remaining}. L objectif d epargne est {goal}.',
        ar: 'الميزانية القابلة للصرف {budget}. المتبقي {remaining}. هدف الادخار {goal}.',
      );
      if (snapshot.remainingDaysInMonth <= 0 || snapshot.remainingBudget <= 0) {
        return base;
      }
      final double daily =
          snapshot.remainingBudget / snapshot.remainingDaysInMonth;
      return '$base\n${_pa(localeCode, 'Suggested safe daily spend for remaining days: {daily}.', <String, String>{'daily': _a(daily, snapshot.currencyCode)}, 'Depense quotidienne sure suggeree pour les jours restants : {daily}.', ar: 'الصرف اليومي الآمن المقترح للأيام المتبقية: {daily}.')}';
    }

    if (_containsAny(input, <String>[
      'balance',
      'solde',
      'how much i have',
      'chhal 3ndi',
      'الرصيد',
    ])) {
      return _pa(
        localeCode,
        'Estimated current balance for this month is {amount}.',
        <String, String>{
          'amount': _a(snapshot.currentBalance, snapshot.currencyCode),
        },
        'Le solde estime pour ce mois est {amount}.',
        ar: 'الرصيد التقديري الحالي لهذا الشهر هو {amount}.',
      );
    }

    if (_containsAny(input, <String>[
      'planned',
      'recurring',
      'schedule',
      'plans',
      'paiement',
      'خطة',
      'متكرر',
    ])) {
      return _pa(
        localeCode,
        'You have {activePlans} active planned payments ({allPlans} total plans) and {budgets} budget goals.',
        <String, String>{
          'activePlans': '${snapshot.activeRecurringCount}',
          'allPlans': '${snapshot.recurringCount}',
          'budgets': '${snapshot.budgetCount}',
        },
        'Vous avez {activePlans} paiements planifies actifs ({allPlans} au total) et {budgets} objectifs budget.',
        ar: 'عندك {activePlans} خطط مدفوعات مفعلة ({allPlans} بالمجموع) و{budgets} أهداف ميزانية.',
      );
    }

    if (_containsAny(input, <String>[
      'transaction',
      'operations',
      'activity',
      'عمليات',
    ])) {
      final double perDay =
          snapshot.transactionsThisMonth / max(snapshot.daysElapsedInMonth, 1);
      return _pa(
        localeCode,
        'You logged {count} transactions this month, around {perDay} per day.',
        <String, String>{
          'count': '${snapshot.transactionsThisMonth}',
          'perDay': perDay.toStringAsFixed(1),
        },
        'Vous avez enregistre {count} transactions ce mois, environ {perDay} par jour.',
        ar: 'سجلت {count} عملية هذا الشهر، بمعدل {perDay} يوميا.',
      );
    }

    if (_containsAny(input, <String>[
      'save',
      'saving',
      'tips',
      'epargne',
      'ادخار',
      'نصيحة',
    ])) {
      if (snapshot.monthlyIncome <= 0) {
        return _p(
          localeCode,
          'Set monthly income first to unlock precise savings tips.',
          'Definissez le revenu mensuel pour des conseils d epargne precis.',
          ar: 'حدد الدخل الشهري أولا للحصول على نصائح ادخار أدق.',
        );
      }
      if (snapshot.remainingBudget < 0) {
        return _pa(
          localeCode,
          'You are over spendable budget by {amount}. Reduce top spending category first.',
          <String, String>{
            'amount': _a(snapshot.remainingBudget.abs(), snapshot.currencyCode),
          },
          'Vous depassez le budget depensable de {amount}. Reduisez d abord la categorie principale.',
          ar: 'أنت متجاوز للميزانية القابلة للصرف بمقدار {amount}. قلل أعلى فئة صرف أولا.',
        );
      }
      final double daily = snapshot.remainingDaysInMonth <= 0
          ? snapshot.remainingBudget
          : snapshot.remainingBudget / snapshot.remainingDaysInMonth;
      return _pa(
        localeCode,
        'Good progress. Keep daily purchases near {daily} to stay on track.',
        <String, String>{'daily': _a(daily, snapshot.currencyCode)},
        'Bonne progression. Gardez des achats quotidiens proches de {daily}.',
        ar: 'تقدم جيد. خلّي الصرف اليومي قريب من {daily} للبقاء على المسار.',
      );
    }

    return _pa(
      localeCode,
      'I can answer about income, spending, balance, budget, wallets, Pro plan, tools and settings. Remaining budget is {amount}.',
      <String, String>{
        'amount': _a(snapshot.remainingBudget, snapshot.currencyCode),
      },
      'Je peux repondre sur revenu, depenses, solde, budget, portefeuilles, plan Pro, outils et parametres. Le budget restant est {amount}.',
      ar: 'أقدر أجاوبك على الدخل والمصاريف والرصيد والميزانية والمحافظ وخطة Pro والأدوات والإعدادات. المتبقي هو {amount}.',
    );
  }

  String _help(String localeCode) {
    return <String>[
      _p(
        localeCode,
        '- How much incoming this month?',
        '- Combien de revenu ce mois ?',
        ar: '- كم الدخل هذا الشهر؟',
      ),
      _p(
        localeCode,
        '- How much did I spend this week?',
        '- Combien ai-je depense cette semaine ?',
        ar: '- كم صرفت هذا الأسبوع؟',
      ),
      _p(
        localeCode,
        '- What is my net cashflow this month?',
        '- Quel est mon cashflow net ce mois ?',
        ar: '- ما هو صافي التدفق المالي هذا الشهر؟',
      ),
      _p(
        localeCode,
        '- Can I spend 100?',
        '- Puis-je depenser 100 ?',
        ar: '- هل يمكنني صرف 100؟',
      ),
      _p(
        localeCode,
        '- How many wallets do I have?',
        '- Combien de portefeuilles ai-je ?',
        ar: '- كم عدد المحافظ عندي؟',
      ),
      _p(
        localeCode,
        '- How do I change language/currency/theme?',
        '- Comment changer langue/devise/theme ?',
        ar: '- كيف أغير اللغة أو العملة أو الثيم؟',
      ),
    ].join('\n');
  }

  String _settingsReply(
    String localeCode,
    FinanceChatbotSnapshot snapshot,
    String input,
  ) {
    if (_containsAny(input, <String>['language', 'langue', 'lang', 'لغة'])) {
      return _pa(
        localeCode,
        'Current app language is {language}. To change it: Settings -> App Language.',
        <String, String>{'language': snapshot.languageLabel},
        'La langue actuelle est {language}. Pour la changer: Parametres -> Langue de l application.',
        ar: 'لغة التطبيق الحالية هي {language}. لتغييرها: الإعدادات -> لغة التطبيق.',
      );
    }
    if (_containsAny(input, <String>['currency', 'devise', 'عملة'])) {
      return _pa(
        localeCode,
        'Current currency is {currency}. To change it: Settings -> Display Currency.',
        <String, String>{'currency': snapshot.currencyCode},
        'La devise actuelle est {currency}. Pour la changer: Parametres -> Devise affichee.',
        ar: 'العملة الحالية هي {currency}. لتغييرها: الإعدادات -> عملة العرض.',
      );
    }
    if (_containsAny(input, <String>[
      'theme',
      'dark',
      'light',
      'appearance',
      'ثيم',
      'داكن',
      'فاتح',
    ])) {
      final String mode = snapshot.themeModeKey == 'dark'
          ? _p(localeCode, 'Dark', 'Sombre', ar: 'داكن')
          : snapshot.themeModeKey == 'light'
          ? _p(localeCode, 'Light', 'Clair', ar: 'فاتح')
          : _p(localeCode, 'System', 'Systeme', ar: 'تلقائي');
      return _pa(
        localeCode,
        'Current theme mode is {mode}. To change it: Settings -> Appearance.',
        <String, String>{'mode': mode},
        'Le mode actuel est {mode}. Pour le changer: Parametres -> Apparence.',
        ar: 'وضع الثيم الحالي هو {mode}. لتغييره: الإعدادات -> المظهر.',
      );
    }
    return _p(
      localeCode,
      'Open Settings to manage language, currency, theme and notifications.',
      'Ouvrez Parametres pour gerer langue, devise, theme et notifications.',
      ar: 'افتح الإعدادات لإدارة اللغة والعملة والثيم والتنبيهات.',
    );
  }

  String _walletReply(
    String localeCode,
    FinanceChatbotSnapshot snapshot,
    String input,
  ) {
    if (_containsAny(input, <String>[
      'switch',
      'change',
      'swap',
      'select',
      'بدل',
      'غير',
      'تبديل',
    ])) {
      return _p(
        localeCode,
        'To switch wallet: open Home and tap wallet switch button, or open account selector page.',
        'Pour changer de portefeuille: ouvrez Accueil puis le bouton de changement, ou la page de selection des comptes.',
        ar: 'لتبديل المحفظة: افتح الصفحة الرئيسية واضغط زر تبديل المحفظة، أو افتح صفحة اختيار الحسابات.',
      );
    }
    final String base = _pa(
      localeCode,
      'You currently have {count} wallet(s). Active wallet: {wallet}.',
      <String, String>{
        'count': '${snapshot.walletCount}',
        'wallet': snapshot.activeWalletName,
      },
      'Vous avez {count} portefeuille(s). Portefeuille actif: {wallet}.',
      ar: 'عندك {count} محفظة. المحفظة النشطة: {wallet}.',
    );
    if (snapshot.isPro) {
      return '$base\n${_p(localeCode, 'You are on Pro, wallet count is unlimited.', 'Vous etes en Pro, nombre de portefeuilles illimite.', ar: 'أنت على Pro، عدد المحافظ غير محدود.')}';
    }
    final int left = max(snapshot.freeWalletLimit - snapshot.walletCount, 0);
    return '$base\n${_pa(localeCode, 'Free plan limit is {limit} wallets. You can add {left} more before Pro.', <String, String>{'limit': '${snapshot.freeWalletLimit}', 'left': '$left'}, 'La limite du plan gratuit est {limit} portefeuilles. Vous pouvez encore ajouter {left} avant Pro.', ar: 'حد الخطة المجانية هو {limit} محافظ. يمكنك إضافة {left} أخرى قبل Pro.')}';
  }

  String _proReply(String localeCode, FinanceChatbotSnapshot snapshot) {
    if (snapshot.isPro) {
      return _p(
        localeCode,
        'Pro is active: unlimited wallets, OCR scanner, export and premium tools.',
        'Pro est actif: portefeuilles illimites, scanner OCR, export et outils premium.',
        ar: 'خطة Pro مفعلة: محافظ غير محدودة، ماسح OCR، تصدير وأدوات مميزة.',
      );
    }
    return _pa(
      localeCode,
      'You are on Free plan. Free supports up to {limit} wallets. Upgrade to Pro for unlimited wallets and advanced tools.',
      <String, String>{'limit': '${snapshot.freeWalletLimit}'},
      'Vous etes sur le plan gratuit. Le plan gratuit prend jusqu a {limit} portefeuilles. Passez Pro pour illimite et outils avances.',
      ar: 'أنت على الخطة المجانية. المجاني يدعم حتى {limit} محافظ. رقّ إلى Pro لمحافظ غير محدودة وأدوات متقدمة.',
    );
  }

  String _featuresReply(
    String localeCode,
    FinanceChatbotSnapshot snapshot,
    String input,
  ) {
    if (_containsAny(input, <String>['ocr', 'receipt', 'scan'])) {
      return _p(
        localeCode,
        'OCR scanner is in Tools page. Scan with camera/gallery, confirm amount and save expense.',
        'Le scanner OCR est dans la page Outils. Scannez camera/galerie, confirmez le montant puis enregistrez.',
        ar: 'ماسح OCR موجود في صفحة الأدوات. امسح بالكاميرا/المعرض، أكد المبلغ ثم احفظ العملية.',
      );
    }
    if (_containsAny(input, <String>[
      'csv',
      'excel',
      'pdf',
      'export',
      'import',
      'backup',
      'restore',
    ])) {
      return _p(
        localeCode,
        'CSV import/export is in Tools page. PDF/Excel/Backup are in Settings export section.',
        'Import/export CSV est dans Outils. PDF/Excel/Sauvegarde sont dans Parametres > export.',
        ar: 'استيراد/تصدير CSV في صفحة الأدوات. PDF/Excel/النسخ الاحتياطي في الإعدادات > التصدير.',
      );
    }
    if (_containsAny(input, <String>[
      'biometric',
      'fingerprint',
      'pin',
      'بصمة',
    ])) {
      final String b = snapshot.biometricEnabled
          ? _p(localeCode, 'ON', 'ACTIF', ar: 'مفعل')
          : _p(localeCode, 'OFF', 'OFF', ar: 'غير مفعل');
      final String p = snapshot.pinEnabled
          ? _p(localeCode, 'ON', 'ACTIF', ar: 'مفعل')
          : _p(localeCode, 'OFF', 'OFF', ar: 'غير مفعل');
      return _pa(
        localeCode,
        'Security state: biometric {bio}, PIN {pin}. Configure in Tools -> Biometric / PIN Lock.',
        <String, String>{'bio': b, 'pin': p},
        'Etat securite: biometrie {bio}, PIN {pin}. Configurez dans Outils -> Verrou biometrie / PIN.',
        ar: 'حالة الأمان: البصمة {bio}، الرمز {pin}. الإعداد من الأدوات -> قفل البصمة / PIN.',
      );
    }
    return _pa(
      localeCode,
      'Tools summary: {budgets} budgets, {plans} plans, {notices} unread notifications.',
      <String, String>{
        'budgets': '${snapshot.budgetCount}',
        'plans': '${snapshot.recurringCount}',
        'notices': '${snapshot.unreadNoticeCount}',
      },
      'Resume outils: {budgets} budgets, {plans} plans, {notices} notifications non lues.',
      ar: 'ملخص الأدوات: {budgets} ميزانيات، {plans} خطط، {notices} إشعارات غير مقروءة.',
    );
  }

  String _canSpendReply(
    String localeCode,
    FinanceChatbotSnapshot snapshot,
    double amount,
  ) {
    if (amount <= 0) {
      return _p(
        localeCode,
        'Please provide a positive amount.',
        'Veuillez fournir un montant positif.',
        ar: 'من فضلك أدخل مبلغا موجبا.',
      );
    }
    final double remaining = snapshot.remainingBudget;
    if (remaining >= amount) {
      return _pa(
        localeCode,
        'Yes, you can spend {amount}. Remaining budget after that would be {after}.',
        <String, String>{
          'amount': _a(amount, snapshot.currencyCode),
          'after': _a(remaining - amount, snapshot.currencyCode),
        },
        'Oui, vous pouvez depenser {amount}. Le budget restant serait {after}.',
        ar: 'نعم، يمكنك صرف {amount}. الميزانية المتبقية بعدها ستكون {after}.',
      );
    }
    return _pa(
      localeCode,
      'Not recommended now. Spending {amount} would exceed remaining budget by {over}.',
      <String, String>{
        'amount': _a(amount, snapshot.currencyCode),
        'over': _a(amount - remaining, snapshot.currencyCode),
      },
      'Pas recommande maintenant. Depenser {amount} depasserait le budget restant de {over}.',
      ar: 'غير مستحسن الآن. صرف {amount} سيتجاوز الميزانية المتبقية بمقدار {over}.',
    );
  }

  String _incomeReply(
    String localeCode,
    FinanceChatbotSnapshot snapshot, {
    required bool asksToday,
    required bool asksWeek,
  }) {
    if (asksToday) {
      return _pa(
        localeCode,
        'Today incoming is {amount}.',
        <String, String>{
          'amount': _a(snapshot.todayIncome, snapshot.currencyCode),
        },
        'Le revenu aujourd hui est {amount}.',
        ar: 'دخل اليوم هو {amount}.',
      );
    }
    if (asksWeek) {
      return _pa(
        localeCode,
        'This week incoming is {amount}.',
        <String, String>{
          'amount': _a(snapshot.weeklyIncome, snapshot.currencyCode),
        },
        'Le revenu cette semaine est {amount}.',
        ar: 'دخل هذا الأسبوع هو {amount}.',
      );
    }
    return _pa(
      localeCode,
      'Incoming this month is {total}. Configured income is {configured} and recorded income transactions are {recorded}.',
      <String, String>{
        'total': _a(snapshot.monthlyIncome, snapshot.currencyCode),
        'configured': _a(
          snapshot.configuredMonthlyIncome,
          snapshot.currencyCode,
        ),
        'recorded': _a(snapshot.recordedIncomeThisMonth, snapshot.currencyCode),
      },
      'Le revenu de ce mois est {total}. Revenu configure {configured} et revenus enregistres {recorded}.',
      ar: 'دخل هذا الشهر هو {total}. الدخل المحدد {configured} والدخل المسجل من العمليات {recorded}.',
    );
  }

  String _a(double amount, String currencyCode) {
    return CurrencyUtils.formatAmount(amount, currencyCode);
  }

  String _p(String localeCode, String en, String fr, {String? ar}) {
    final String code = AppLocalizations.normalizeLanguageCode(localeCode);
    if (code == 'ar' && ar != null && ar.trim().isNotEmpty) {
      return ar;
    }
    return AppLocalizations.phraseForLocale(code, en, french: fr);
  }

  String _pa(
    String localeCode,
    String en,
    Map<String, String> args,
    String fr, {
    String? ar,
  }) {
    String text = _p(localeCode, en, fr, ar: ar);
    for (final MapEntry<String, String> e in args.entries) {
      text = text.replaceAll('{${e.key}}', e.value);
    }
    return text;
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final String raw in keywords) {
      final String key = raw.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      if (key.contains(' ') ||
          RegExp(r'[^a-z0-9\u0600-\u06ff]').hasMatch(key)) {
        if (text.contains(key)) {
          return true;
        }
        continue;
      }
      final RegExp token = RegExp(
        '(^|[^a-z0-9\u0600-\u06ff])${RegExp.escape(key)}([^a-z0-9\u0600-\u06ff]|\$)',
      );
      if (token.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  String? _findCategoryKey(String input, FinanceChatbotSnapshot snapshot) {
    for (final MapEntry<String, String> e in _categoryAliases.entries) {
      if (_containsAny(input, <String>[e.key])) {
        return e.value;
      }
    }
    for (final MapEntry<String, String> e
        in snapshot.categoryDisplayNames.entries) {
      if (!e.key.startsWith('custom:')) {
        continue;
      }
      final String name = _normalize(e.value);
      if (name.length >= 3 && input.contains(name)) {
        return e.key;
      }
    }
    return null;
  }

  String _humanizeCategory(String key) {
    switch (key) {
      case 'food':
        return 'Food';
      case 'transport':
        return 'Transport';
      case 'rent':
        return 'Rent';
      case 'shopping':
        return 'Shopping';
      case 'bills':
        return 'Bills';
      case 'other':
        return 'Other';
      default:
        return key.startsWith('custom:') ? key.substring(7) : key;
    }
  }

  double? _extractFirstAmount(String text) {
    final RegExpMatch? match = RegExp(r'(-?\d+(?:[\.,]\d+)?)').firstMatch(text);
    if (match == null) {
      return null;
    }
    return double.tryParse((match.group(1) ?? '').replaceAll(',', '.'));
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

