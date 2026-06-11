abstract class SettingsRepository {
  String getThemeMode();
  Future<void> setThemeMode(String mode);

  String getCurrencyCode();
  Future<void> setCurrencyCode(String code);

  String getLocaleCode();
  Future<void> setLocaleCode(String code);

  double getMonthlyIncome();
  Future<void> setMonthlyIncome(double value);

  double getMonthlySavingsGoal();
  Future<void> setMonthlySavingsGoal(double value);

  Map<String, double> getCategoryMonthlyPlans();
  Future<void> setCategoryMonthlyPlans(Map<String, double> values);

  bool hasCompletedOnboarding();
  Future<void> setHasCompletedOnboarding(bool value);

  String getUserFirstName();
  Future<void> setUserFirstName(String value);

  String getUserLastName();
  Future<void> setUserLastName(String value);

  bool isProEnabled();
  Future<void> setProEnabled(bool value);

  List<Map<String, dynamic>> getBankAccounts();
  Future<void> setBankAccounts(List<Map<String, dynamic>> value);

  String getActiveBankAccountId();
  Future<void> setActiveBankAccountId(String value);

  List<Map<String, dynamic>> getCustomCategories();
  Future<void> setCustomCategories(List<Map<String, dynamic>> value);

  bool getMaintenanceNoticeAcknowledged();
  Future<void> setMaintenanceNoticeAcknowledged(bool value);

  String getAccentPreset();
  Future<void> setAccentPreset(String value);

  String getBackgroundStyle();
  Future<void> setBackgroundStyle(String value);
}
