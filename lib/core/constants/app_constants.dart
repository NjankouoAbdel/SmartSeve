class AppConstants {
  static const String appName = 'SMART SAVE Expense Manager_firebase';

  static const String expensesBox = 'expenses_box';
  static const String settingsBox = 'settings_box';
  static const String budgetsBox = 'budgets_box';
  static const String recurringBox = 'recurring_box';
  static const String noticesBox = 'notices_box';
  static const String toolsBox = 'tools_box';

  static const String settingThemeMode = 'theme_mode';
  static const String settingCurrencyCode = 'currency_code';
  static const String settingLocaleCode = 'locale_code';
  static const String settingMonthlyIncome = 'monthly_income';
  static const String settingMonthlySavingsGoal = 'monthly_savings_goal';
  static const String settingCategoryMonthlyPlans = 'category_monthly_plans';
  static const String settingHasCompletedOnboarding =
      'has_completed_onboarding';
  static const String settingUserFirstName = 'user_first_name';
  static const String settingUserLastName = 'user_last_name';
  static const String settingIsPro = 'is_pro';
  static const String settingBankAccounts = 'bank_accounts';
  static const String settingActiveBankAccountId = 'active_bank_account_id';
  static const String settingCustomCategories = 'custom_categories';
  static const String settingMaintenanceNoticeAcknowledged =
      'maintenance_notice_acknowledged';
  static const String settingAccentPreset = 'accent_preset';
  static const String settingBackgroundStyle = 'background_style';

  static const String defaultBankAccountId = 'main';

  static const String toolsKeyBiometricEnabled = 'biometric_enabled';
  static const String toolsKeyPinEnabled = 'pin_enabled';
  static const String toolsKeyPinCode = 'pin_code';
  static const String toolsKeySmartSaving80Month = 'smart_saving_80_month';
  static const String toolsKeySmartSaving100Month = 'smart_saving_100_month';

  // Google Play Billing managed product id (one-time unlock).
  // Create this exact product id in Play Console > Monetize > Products > In-app products.
  static const String iapProProductId = 'pro_lifetime';

  // Google Sheets export (service account). Leave empty to disable.
  // 1) Create a Google Cloud service account.
  // 2) Enable Google Sheets API.
  // 3) Put the raw JSON credentials string here (or inject securely).
  // 4) Share the target spreadsheet with service-account email.
  static const String googleSheetsSpreadsheetId = '';
  static const String googleSheetsServiceAccountJson = '';

  static const int freeWalletLimit = 2;
}
