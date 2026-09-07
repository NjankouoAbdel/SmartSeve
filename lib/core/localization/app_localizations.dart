import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wfer_flousk_firebase/core/localization/generated_phrase_overrides.dart';
import 'package:wfer_flousk_firebase/core/localization/generated_phrase_values.dart';

class AppLanguageOption {
  const AppLanguageOption({required this.code, required this.label});

  final String code;
  final String label;
}

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<String> supportedLanguageCodes = <String>[
    'en',
    'fr',
    'ar',
    'es',
    'de',
    'it',
    'pt',
    'ru',
    'tr',
    'id',
    'hi',
    'zh',
    'ja',
    'ko',
    'nl',
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('ar'),
    Locale('es'),
    Locale('de'),
    Locale('it'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('id'),
    Locale('hi'),
    Locale('zh'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
  ];

  static const Map<String, String> _languageNativeNames = <String, String>{
    'en': 'English',
    'fr': 'Francais',
    'ar': 'العربية',
    'es': 'Espanol',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Portugues',
    'ru': 'Русский',
    'tr': 'Turkce',
    'id': 'Bahasa Indonesia',
    'hi': 'हिन्दी',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'nl': 'Nederlands',
  };

  static bool isSupportedLanguageCode(String languageCode) {
    return supportedLanguageCodes.contains(normalizeLanguageCode(languageCode));
  }

  static String normalizeLanguageCode(String value) {
    final String normalized = value.trim().toLowerCase().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return 'en';
    }
    final String baseCode = normalized.split('-').first;
    if (supportedLanguageCodes.contains(baseCode)) {
      return baseCode;
    }
    return 'en';
  }

  static List<AppLanguageOption> languageOptions() {
    return supportedLanguageCodes
        .map(
          (String code) =>
              AppLanguageOption(code: code, label: _languageNativeNames[code]!),
        )
        .toList(growable: false);
  }

  static AppLocalizations of(BuildContext context) {
    final AppLocalizations? localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'No AppLocalizations found in context.');
    return localizations!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>>
  _values = <String, Map<String, String>>{
    'en': <String, String>{
      'appName': 'SMART SAVE Expense Manager_firebase',
      'appTagline': 'Track smarter. Spend better every day.',
      'appTaglineShort': 'Track smarter. Spend better.',
      'tabHome': 'Home',
      'tabStatistics': 'Statistics',
      'tabAddExpense': 'Add Expense',
      'tabSettings': 'Settings',
      'homeSubtitle': 'Track smarter. Spend better every day.',
      'homeOverview': 'Overview',
      'homeTotalBalance': 'Total Balance',
      'homeMonthlySpending': 'Monthly Spending',
      'homeTodaySpending': "Today's Spending",
      'homeQuickAddExpense': 'Quick Add Expense',
      'homeRecentTransactions': 'Recent Transactions',
      'homeNoExpenses': 'No expenses yet. Add your first one.',
      'homeMonthlyPlanTitle': 'Smart Monthly Plan',
      'homeMonthlyPlanSubtitle':
          'Control spending against your income and savings goal.',
      'homeSetPlan': 'Set Monthly Plan',
      'homeEditPlan': 'Edit Plan',
      'homeMonthlyIncome': 'Monthly Income',
      'homeSavingsGoal': 'Savings Goal',
      'homeSpendableBudget': 'Spendable Budget',
      'homeRemainingBudget': 'Remaining Budget',
      'homePotentialSavings': 'Potential Savings',
      'homeRecommendedDailySpend': 'Recommended Daily Spend',
      'homeSavingsProgress': 'Savings Progress',
      'homePlanTipSetup':
          'Add your monthly income and savings target to unlock smart guidance.',
      'homePlanTipOnTrack':
          'Great progress. You are on track to hit your savings target.',
      'homePlanTipOverspent': 'You exceeded your spendable budget this month.',
      'homePlanTipReduce':
          'To stay on track, keep daily spending around {daily}.',
      'homePlanDialogTitle': 'Monthly Plan Setup',
      'homePlanDialogIncomeLabel': 'Income for this month',
      'homePlanDialogGoalLabel': 'Savings target for this month',
      'homePlanDialogHint':
          'This helps the app calculate safe spending and savings guidance.',
      'homePlanSaved': 'Monthly plan saved.',
      'homePlanInvalid': 'Please enter valid numbers.',
      'homeNoIncome': 'No income configured',
      'statisticsTitle': 'Statistics',
      'statisticsSubtitle': 'Understand your spending behavior at a glance.',
      'statisticsNoData': 'No data yet for category chart.',
      'statisticsByCategory': 'Spending by Category',
      'statisticsMonthlyTrend': 'Monthly Spending Trend',
      'statisticsLast6Months': 'Last 6 months',
      'statisticsWeeklyComparison': 'Weekly Comparison',
      'statisticsCurrentWeek': 'Current Week',
      'statisticsPreviousWeek': 'Previous Week',
      'statisticsKpiHealthScore': 'Financial Health',
      'statisticsKpiAvgDaily': 'Avg Daily Spend',
      'statisticsKpiTopCategory': 'Top Category',
      'statisticsKpiActiveDays': 'Active Days',
      'statisticsInsightsTitle': 'Smart Insights',
      'statisticsInsightNoData': 'Add more expenses to unlock insights.',
      'statisticsInsightVsIncome':
          'Monthly spending is {ratio}% of your income.',
      'statisticsInsightSavingsRisk': 'Savings target risk: short by {amount}.',
      'statisticsInsightSavingsGood': 'Savings target is currently on track.',
      'statisticsInsightCategory': 'Most spending is in {category}.',
      'statisticsInsightDailyCap':
          'Suggested daily cap for remaining days: {amount}.',
      'statisticsNoTopCategory': 'No category',
      'addExpenseTitle': 'Add Expense',
      'addExpenseSubtitle': 'Create a new transaction quickly and accurately.',
      'addExpenseCategory': 'Category',
      'addExpenseNotes': 'Notes',
      'addExpenseSave': 'Save Expense',
      'addExpenseAmount': 'Amount',
      'addExpenseDate': 'Date',
      'addExpenseInvalidAmount': 'Please enter a valid amount.',
      'addExpenseAmountRequired': 'Amount is required',
      'addExpenseSaved': 'Expense saved successfully.',
      'settingsTitle': 'Settings',
      'settingsSubtitle': 'Personalize your app and manage premium tools.',
      'settingsAppearance': 'Appearance',
      'settingsDarkMode': 'Dark Mode',
      'settingsDarkModeSubtitle': 'Switch between dark and light theme',
      'settingsDisplayCurrency': 'Display Currency',
      'settingsAppLanguage': 'App Language',
      'languageEnglish': 'English',
      'languageFrench': 'French',
      'settingsProActive': 'Pro Active',
      'settingsUpgradePro': 'Upgrade to Pro',
      'settingsProActiveDescription':
          'Ads are removed. PDF export and backup are unlocked.',
      'settingsProInactiveDescription': 'One-time purchase. Price: {price}',
      'settingsUnlockPro': 'Unlock Pro Lifetime',
      'settingsProcessing': 'Processing...',
      'settingsRestorePurchases': 'Restore Purchases',
      'settingsProFeatures': 'Pro Features',
      'settingsExportPdf': 'Export to PDF (Pro)',
      'settingsExportPdfSubtitle': 'Generate and share a professional report.',
      'settingsBackupData': 'Backup Data (Pro)',
      'settingsBackupDataSubtitle': 'Create JSON backup and share it.',
      'settingsRemoveAds': 'Remove Ads (Pro)',
      'settingsAdsRemoved': 'Ads are already removed.',
      'settingsAdsLocked': 'Locked until Pro unlock.',
      'settingsProFeatureLocked':
          'This is a Pro feature. Please unlock Pro first.',
      'settingsActionFailed': 'Action failed. Please try again.',
      'settingsPdfExported': 'PDF exported:',
      'settingsBackupCreated': 'Backup created:',
      'toolsNotifications': 'Tools and notifications',
      'commonNoNote': 'No note',
      'commonCancel': 'Cancel',
      'commonSave': 'Save',
      'categoryFood': 'Food',
      'categoryTransport': 'Transport',
      'categoryRent': 'Rent',
      'categoryShopping': 'Shopping',
      'categoryBills': 'Bills',
      'categoryOther': 'Other',
    },
    'fr': <String, String>{
      'appName': 'Gestionnaire Intelligent des Depenses_firebase',
      'appTagline':
          'Suivez mieux vos depenses. Depensez plus intelligemment chaque jour.',
      'appTaglineShort': 'Suivez mieux. Depensez intelligemment.',
      'tabHome': 'Accueil',
      'tabStatistics': 'Statistiques',
      'tabAddExpense': 'Ajouter',
      'tabSettings': 'Parametres',
      'homeSubtitle':
          'Suivez mieux vos depenses. Depensez plus intelligemment chaque jour.',
      'homeOverview': 'Apercu',
      'homeTotalBalance': 'Solde total',
      'homeMonthlySpending': 'Depenses mensuelles',
      'homeTodaySpending': 'Depenses du jour',
      'homeQuickAddExpense': 'Ajouter rapidement',
      'homeRecentTransactions': 'Transactions recentes',
      'homeNoExpenses':
          'Aucune depense pour le moment. Ajoutez votre premiere depense.',
      'homeMonthlyPlanTitle': 'Plan Mensuel Intelligent',
      'homeMonthlyPlanSubtitle':
          'Controlez les depenses selon votre revenu et objectif d epargne.',
      'homeSetPlan': 'Definir le plan mensuel',
      'homeEditPlan': 'Modifier le plan',
      'homeMonthlyIncome': 'Revenu mensuel',
      'homeSavingsGoal': 'Objectif d epargne',
      'homeSpendableBudget': 'Budget depensable',
      'homeRemainingBudget': 'Budget restant',
      'homePotentialSavings': 'Epargne potentielle',
      'homeRecommendedDailySpend': 'Depense quotidienne recommandee',
      'homeSavingsProgress': 'Progression epargne',
      'homePlanTipSetup':
          'Ajoutez revenu et objectif d epargne pour activer le guidage intelligent.',
      'homePlanTipOnTrack':
          'Excellent. Vous etes en bonne voie pour atteindre l objectif d epargne.',
      'homePlanTipOverspent': 'Vous avez depasse le budget depensable ce mois.',
      'homePlanTipReduce':
          'Pour rester sur la bonne voie, gardez une depense quotidienne autour de {daily}.',
      'homePlanDialogTitle': 'Configuration du plan mensuel',
      'homePlanDialogIncomeLabel': 'Revenu pour ce mois',
      'homePlanDialogGoalLabel': 'Objectif d epargne pour ce mois',
      'homePlanDialogHint':
          'Cela aide l application a calculer une depense sure et un guidage epargne.',
      'homePlanSaved': 'Plan mensuel enregistre.',
      'homePlanInvalid': 'Veuillez entrer des nombres valides.',
      'homeNoIncome': 'Aucun revenu configure',
      'statisticsTitle': 'Statistiques',
      'statisticsSubtitle':
          'Comprenez votre comportement de depense en un coup d oeil.',
      'statisticsNoData':
          'Aucune donnee disponible pour le graphique des categories.',
      'statisticsByCategory': 'Depenses par categorie',
      'statisticsMonthlyTrend': 'Tendance mensuelle',
      'statisticsLast6Months': '6 derniers mois',
      'statisticsWeeklyComparison': 'Comparaison hebdomadaire',
      'statisticsCurrentWeek': 'Semaine actuelle',
      'statisticsPreviousWeek': 'Semaine precedente',
      'statisticsKpiHealthScore': 'Sante financiere',
      'statisticsKpiAvgDaily': 'Moyenne quotidienne',
      'statisticsKpiTopCategory': 'Categorie principale',
      'statisticsKpiActiveDays': 'Jours actifs',
      'statisticsInsightsTitle': 'Insights intelligents',
      'statisticsInsightNoData':
          'Ajoutez plus de depenses pour debloquer les insights.',
      'statisticsInsightVsIncome':
          'Les depenses mensuelles representent {ratio}% de votre revenu.',
      'statisticsInsightSavingsRisk':
          'Risque sur l objectif d epargne: il manque {amount}.',
      'statisticsInsightSavingsGood':
          'L objectif d epargne est actuellement en bonne voie.',
      'statisticsInsightCategory':
          'La plus grande part de depense est en {category}.',
      'statisticsInsightDailyCap':
          'Plafond quotidien suggere pour les jours restants: {amount}.',
      'statisticsNoTopCategory': 'Aucune categorie',
      'addExpenseTitle': 'Ajouter une depense',
      'addExpenseSubtitle':
          'Creez une nouvelle transaction rapidement et precisement.',
      'addExpenseCategory': 'Categorie',
      'addExpenseNotes': 'Notes',
      'addExpenseSave': 'Enregistrer la depense',
      'addExpenseAmount': 'Montant',
      'addExpenseDate': 'Date',
      'addExpenseInvalidAmount': 'Veuillez entrer un montant valide.',
      'addExpenseAmountRequired': 'Le montant est obligatoire',
      'addExpenseSaved': 'Depense enregistree avec succes.',
      'settingsTitle': 'Parametres',
      'settingsSubtitle':
          'Personnalisez votre application et gerez les outils premium.',
      'settingsAppearance': 'Apparence',
      'settingsDarkMode': 'Mode sombre',
      'settingsDarkModeSubtitle': 'Basculer entre le theme sombre et clair',
      'settingsDisplayCurrency': 'Devise affichee',
      'settingsAppLanguage': 'Langue de l application',
      'languageEnglish': 'Anglais',
      'languageFrench': 'Francais',
      'settingsProActive': 'Pro actif',
      'settingsUpgradePro': 'Passer a Pro',
      'settingsProActiveDescription':
          'Les publicites sont supprimees. Export PDF et sauvegarde actives.',
      'settingsProInactiveDescription': 'Achat unique. Prix: {price}',
      'settingsUnlockPro': 'Debloquer Pro a vie',
      'settingsProcessing': 'Traitement...',
      'settingsRestorePurchases': 'Restaurer les achats',
      'settingsProFeatures': 'Fonctionnalites Pro',
      'settingsExportPdf': 'Exporter en PDF (Pro)',
      'settingsExportPdfSubtitle':
          'Generez et partagez un rapport professionnel.',
      'settingsBackupData': 'Sauvegarde des donnees (Pro)',
      'settingsBackupDataSubtitle': 'Creez une sauvegarde JSON et partagez-la.',
      'settingsRemoveAds': 'Supprimer les pubs (Pro)',
      'settingsAdsRemoved': 'Les pubs sont deja supprimees.',
      'settingsAdsLocked': 'Verrouille jusqu au deblocage Pro.',
      'settingsProFeatureLocked':
          'Cette fonction est Pro. Veuillez d abord debloquer Pro.',
      'settingsActionFailed': 'Action echouee. Veuillez reessayer.',
      'settingsPdfExported': 'PDF exporte :',
      'settingsBackupCreated': 'Sauvegarde creee :',
      'toolsNotifications': 'Outils et notifications',
      'commonNoNote': 'Aucune note',
      'commonCancel': 'Annuler',
      'commonSave': 'Enregistrer',
      'categoryFood': 'Alimentation',
      'categoryTransport': 'Transport',
      'categoryRent': 'Loyer',
      'categoryShopping': 'Shopping',
      'categoryBills': 'Factures',
      'categoryOther': 'Autre',
    },
  };

  static final Map<String, Map<String, String>> _phraseValues =
      _buildPhraseValues();

  static Map<String, Map<String, String>> _buildPhraseValues() {
    final Map<String, Map<String, String>> merged =
        <String, Map<String, String>>{
          for (final MapEntry<String, Map<String, String>> entry
              in generatedPhraseValues.entries)
            entry.key: Map<String, String>.from(entry.value),
        };

    for (final MapEntry<String, Map<String, String>> entry
        in generatedPhraseOverrides.entries) {
      final Map<String, String> target = merged.putIfAbsent(
        entry.key,
        () => <String, String>{},
      );
      target.addAll(entry.value);
    }

    return merged;
  }

  String get _languageCode => normalizeLanguageCode(locale.languageCode);

  String languageLabel(String languageCode) {
    return _languageNativeNames[normalizeLanguageCode(languageCode)] ??
        languageCode.toUpperCase();
  }

  static String phraseForLocale(
    String localeCode,
    String english, {
    String? french,
  }) {
    final String languageCode = normalizeLanguageCode(localeCode);
    final String source = english.trim();
    final String normalizedSource = source.replaceAll('â€¢', '•');
    if (source.isEmpty) {
      return english;
    }

    if (languageCode == 'fr' && french != null && french.trim().isNotEmpty) {
      return french;
    }

    final Map<String, String>? dictionary = _phraseValues[languageCode];
    if (dictionary == null) {
      return english;
    }

    return dictionary[normalizedSource] ?? dictionary[source] ?? english;
  }

  static String phraseWithArgsForLocale(
    String localeCode,
    String english,
    Map<String, String> args, {
    String? french,
  }) {
    String output = phraseForLocale(localeCode, english, french: french);
    for (final MapEntry<String, String> entry in args.entries) {
      output = output.replaceAll('{${entry.key}}', entry.value);
    }
    return output;
  }

  String tr(String key) {
    final String languageCode = _languageCode;
    final String? localized = _values[languageCode]?[key];
    if (localized != null) {
      return localized;
    }
    final String? enValue = _values['en']?[key];
    if (enValue == null) {
      return key;
    }
    return phrase(enValue);
  }

  String trWithArgs(String key, Map<String, String> args) {
    String output = tr(key);
    for (final MapEntry<String, String> entry in args.entries) {
      output = output.replaceAll('{${entry.key}}', entry.value);
    }
    return output;
  }

  String phrase(String english, {String? french}) {
    return phraseForLocale(_languageCode, english, french: french);
  }

  String phraseWithArgs(
    String english,
    Map<String, String> args, {
    String? french,
  }) {
    String output = phrase(english, french: french);
    for (final MapEntry<String, String> entry in args.entries) {
      output = output.replaceAll('{${entry.key}}', entry.value);
    }
    return output;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.isSupportedLanguageCode(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

