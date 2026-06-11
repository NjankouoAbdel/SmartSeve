import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wfer_flousk_firebase/core/constants/app_constants.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/theme/theme_preferences.dart';
import 'package:wfer_flousk_firebase/domain/entities/bank_account.dart';
import 'package:wfer_flousk_firebase/domain/entities/custom_category.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/domain/repositories/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._settingsRepository)
    : _themeMode = _decodeThemeMode(_settingsRepository.getThemeMode()),
      _currencyCode = _settingsRepository.getCurrencyCode(),
      _localeCode = _normalizeLocaleCode(_settingsRepository.getLocaleCode()),
      _monthlyIncome = _settingsRepository.getMonthlyIncome(),
      _monthlySavingsGoal = _settingsRepository.getMonthlySavingsGoal(),
      _categoryMonthlyPlans = _normalizeCategoryPlans(
        _settingsRepository.getCategoryMonthlyPlans(),
      ),
      _hasCompletedOnboarding = _settingsRepository.hasCompletedOnboarding(),
      _userFirstName = _settingsRepository.getUserFirstName(),
      _userLastName = _settingsRepository.getUserLastName(),
      _isPro = _settingsRepository.isProEnabled(),
      _bankAccounts = _normalizeBankAccounts(
        _settingsRepository.getBankAccounts(),
      ),
      _activeBankAccountId = _settingsRepository.getActiveBankAccountId(),
      _customCategories = _normalizeCustomCategories(
        _settingsRepository.getCustomCategories(),
      ),
      _maintenanceNoticeAcknowledged = _settingsRepository
          .getMaintenanceNoticeAcknowledged(),
      _accentPreset = AccentPresetX.fromKey(
        _settingsRepository.getAccentPreset(),
      ),
      _backgroundStyle = BackgroundStyleX.fromKey(
        _settingsRepository.getBackgroundStyle(),
      ) {
    if (_bankAccounts.isEmpty) {
      _bankAccounts = <BankAccount>[_defaultBankAccount()];
    }

    if (_bankAccounts.every((BankAccount a) => a.id != _activeBankAccountId)) {
      _activeBankAccountId = _bankAccounts.first.id;
    }

    if (_syncLocalizedDefaultBankAccountLabels()) {
      unawaited(_persistBankAccounts());
    }
  }

  final SettingsRepository _settingsRepository;

  ThemeMode _themeMode;
  String _currencyCode;
  String _localeCode;
  double _monthlyIncome;
  double _monthlySavingsGoal;
  Map<ExpenseCategory, double> _categoryMonthlyPlans;
  bool _hasCompletedOnboarding;
  String _userFirstName;
  String _userLastName;
  bool _isPro;
  List<BankAccount> _bankAccounts;
  String _activeBankAccountId;
  List<CustomCategory> _customCategories;
  bool _maintenanceNoticeAcknowledged;
  AccentPreset _accentPreset;
  BackgroundStyle _backgroundStyle;

  ThemeMode get themeMode => _themeMode;
  String get currencyCode => _currencyCode;
  String get localeCode => _localeCode;
  Locale get locale => Locale(_localeCode);
  double get monthlyIncome => _monthlyIncome;
  double get monthlySavingsGoal => _monthlySavingsGoal;
  Map<ExpenseCategory, double> get categoryMonthlyPlans =>
      Map<ExpenseCategory, double>.unmodifiable(_categoryMonthlyPlans);
  double get totalCategoryMonthlyPlan => _categoryMonthlyPlans.values.fold(
    0,
    (double sum, double value) => sum + value,
  );
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  String get userFirstName => _userFirstName;
  String get userLastName => _userLastName;
  String get userFullName {
    final String fullName = '${_userFirstName.trim()} ${_userLastName.trim()}'
        .trim();
    return fullName.isEmpty
        ? AppLocalizations.phraseForLocale(
            _localeCode,
            'User',
            french: 'Utilisateur',
          )
        : fullName;
  }

  //bool get isPro => _isPro;
  bool get isPro => true;
  List<BankAccount> get bankAccounts =>
      List<BankAccount>.unmodifiable(_bankAccounts);
  String get activeBankAccountId => _activeBankAccountId;
  List<CustomCategory> get customCategories =>
      List<CustomCategory>.unmodifiable(_customCategories);
  bool get maintenanceNoticeAcknowledged => _maintenanceNoticeAcknowledged;
  AccentPreset get accentPreset => _accentPreset;
  BackgroundStyle get backgroundStyle => _backgroundStyle;
  int get freeWalletLimit => AppConstants.freeWalletLimit;
  bool get hasReachedFreeWalletLimit =>
      !_isPro && _bankAccounts.length >= AppConstants.freeWalletLimit;
  bool get canAddMoreWallets =>
      _isPro || _bankAccounts.length < AppConstants.freeWalletLimit;
  String get localizedMainWalletLabel => _localizedMainWalletLabel(_localeCode);
  String get localizedGeneralLabel => _localizedGeneralLabel(_localeCode);
  String get localizedBankLabel => _localizedBankLabel(_localeCode);
  BankAccount get activeBankAccount {
    return _bankAccounts.firstWhere(
      (BankAccount account) => account.id == _activeBankAccountId,
      orElse: () => _bankAccounts.first,
    );
  }

  String displayBankAccountName(BankAccount account) {
    if (account.id != AppConstants.defaultBankAccountId) {
      return account.name;
    }
    if (!_isDefaultMainWalletAlias(account.name)) {
      return account.name;
    }
    return localizedMainWalletLabel;
  }

  String displayBankAccountInstitution(BankAccount account) {
    if (account.id != AppConstants.defaultBankAccountId) {
      return account.institution;
    }
    if (!_isDefaultGeneralAlias(account.institution)) {
      return account.institution;
    }
    return localizedGeneralLabel;
  }

  CustomCategory? customCategoryById(String id) {
    try {
      return _customCategories.firstWhere(
        (CustomCategory category) => category.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    await _settingsRepository.setThemeMode(_encodeThemeMode(themeMode));
    notifyListeners();
  }

  Future<void> setCurrencyCode(String currencyCode) async {
    _currencyCode = currencyCode;
    await _settingsRepository.setCurrencyCode(currencyCode);
    notifyListeners();
  }

  Future<void> setLocaleCode(String localeCode) async {
    final String normalized = _normalizeLocaleCode(localeCode);
    _localeCode = normalized;
    await _settingsRepository.setLocaleCode(normalized);
    if (_syncLocalizedDefaultBankAccountLabels()) {
      await _persistBankAccounts();
    }
    notifyListeners();
  }

  Future<void> setMonthlyIncome(double value) async {
    _monthlyIncome = value < 0 ? 0 : value;
    await _settingsRepository.setMonthlyIncome(_monthlyIncome);
    notifyListeners();
  }

  Future<void> setMonthlySavingsGoal(double value) async {
    _monthlySavingsGoal = value < 0 ? 0 : value;
    await _settingsRepository.setMonthlySavingsGoal(_monthlySavingsGoal);
    notifyListeners();
  }

  Future<void> setCategoryMonthlyPlan(
    ExpenseCategory category,
    double value,
  ) async {
    _categoryMonthlyPlans = <ExpenseCategory, double>{
      ..._categoryMonthlyPlans,
      category: value < 0 ? 0 : value,
    };
    await _settingsRepository.setCategoryMonthlyPlans(
      _encodeCategoryPlans(_categoryMonthlyPlans),
    );
    notifyListeners();
  }

  Future<void> setCategoryMonthlyPlans(
    Map<ExpenseCategory, double> values,
  ) async {
    _categoryMonthlyPlans = <ExpenseCategory, double>{
      for (final ExpenseCategory category in ExpenseCategory.values)
        category: (values[category] ?? 0) < 0 ? 0 : (values[category] ?? 0),
    };
    await _settingsRepository.setCategoryMonthlyPlans(
      _encodeCategoryPlans(_categoryMonthlyPlans),
    );
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String firstName,
    required String lastName,
  }) async {
    _userFirstName = firstName.trim();
    _userLastName = lastName.trim();
    _hasCompletedOnboarding = true;

    await _settingsRepository.setUserFirstName(_userFirstName);
    await _settingsRepository.setUserLastName(_userLastName);
    await _settingsRepository.setHasCompletedOnboarding(true);
    notifyListeners();
  }

  Future<void> updateProfileName({
    required String firstName,
    required String lastName,
  }) async {
    _userFirstName = firstName.trim();
    _userLastName = lastName.trim();
    await _settingsRepository.setUserFirstName(_userFirstName);
    await _settingsRepository.setUserLastName(_userLastName);
    notifyListeners();
  }

  Future<void> setProLocally(bool value) async {
    _isPro = value;
    await _settingsRepository.setProEnabled(value);
    notifyListeners();
  }

  Future<bool> addBankAccount({
    required String name,
    String institution = 'Bank',
    int iconCodePoint = 0xe850,
    int colorValue = 0xFF42A5F5,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return false;
    }

    if (hasReachedFreeWalletLimit) {
      return false;
    }

    final String id = 'acc_${DateTime.now().microsecondsSinceEpoch}';
    _bankAccounts = <BankAccount>[
      ..._bankAccounts,
      BankAccount(
        id: id,
        name: trimmedName,
        institution: institution.trim().isEmpty
            ? localizedBankLabel
            : institution.trim(),
        createdAt: DateTime.now(),
        iconCodePoint: iconCodePoint,
        colorValue: colorValue,
      ),
    ];
    _activeBankAccountId = id;
    await _persistBankAccounts();
    await _settingsRepository.setActiveBankAccountId(_activeBankAccountId);
    notifyListeners();
    return true;
  }

  Future<void> setActiveBankAccount(String accountId) async {
    if (_bankAccounts.every((BankAccount a) => a.id != accountId)) {
      return;
    }
    _activeBankAccountId = accountId;
    await _settingsRepository.setActiveBankAccountId(accountId);
    notifyListeners();
  }

  Future<void> removeBankAccount(String accountId) async {
    if (_bankAccounts.length <= 1) {
      return;
    }
    _bankAccounts = _bankAccounts
        .where((BankAccount account) => account.id != accountId)
        .toList(growable: false);
    if (_bankAccounts.isEmpty) {
      _bankAccounts = <BankAccount>[_defaultBankAccount()];
    }
    if (_bankAccounts.every((BankAccount a) => a.id != _activeBankAccountId)) {
      _activeBankAccountId = _bankAccounts.first.id;
    }
    await _persistBankAccounts();
    await _settingsRepository.setActiveBankAccountId(_activeBankAccountId);
    notifyListeners();
  }

  Future<void> addCustomCategory({
    required String name,
    int iconCodePoint = 0xe14c,
    int colorValue = 0xFF64B5F6,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final bool exists = _customCategories.any(
      (CustomCategory category) =>
          category.name.toLowerCase() == trimmedName.toLowerCase(),
    );
    if (exists) {
      return;
    }

    _customCategories = <CustomCategory>[
      ..._customCategories,
      CustomCategory(
        id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
        name: trimmedName,
        iconCodePoint: iconCodePoint,
        colorValue: colorValue,
        createdAt: DateTime.now(),
      ),
    ];

    await _persistCustomCategories();
    notifyListeners();
  }

  Future<void> updateCustomCategory(CustomCategory updated) async {
    final int index = _customCategories.indexWhere(
      (CustomCategory category) => category.id == updated.id,
    );
    if (index < 0) {
      return;
    }

    _customCategories = <CustomCategory>[
      ..._customCategories.sublist(0, index),
      updated,
      ..._customCategories.sublist(index + 1),
    ];
    await _persistCustomCategories();
    notifyListeners();
  }

  Future<void> removeCustomCategory(String categoryId) async {
    _customCategories = _customCategories
        .where((CustomCategory category) => category.id != categoryId)
        .toList(growable: false);
    await _persistCustomCategories();
    notifyListeners();
  }

  Future<void> setMaintenanceNoticeAcknowledged(bool value) async {
    _maintenanceNoticeAcknowledged = value;
    await _settingsRepository.setMaintenanceNoticeAcknowledged(value);
    notifyListeners();
  }

  Future<void> setAccentPreset(AccentPreset preset) async {
    _accentPreset = preset;
    await _settingsRepository.setAccentPreset(preset.key);
    notifyListeners();
  }

  Future<void> setBackgroundStyle(BackgroundStyle style) async {
    _backgroundStyle = style;
    await _settingsRepository.setBackgroundStyle(style.key);
    notifyListeners();
  }

  Future<void> updateBankAccount(BankAccount updated) async {
    final int index = _bankAccounts.indexWhere(
      (BankAccount account) => account.id == updated.id,
    );
    if (index < 0) {
      return;
    }
    _bankAccounts = <BankAccount>[
      ..._bankAccounts.sublist(0, index),
      updated,
      ..._bankAccounts.sublist(index + 1),
    ];
    await _persistBankAccounts();
    notifyListeners();
  }

  void setProState(bool value) {
    _isPro = value;
    notifyListeners();
  }

  static ThemeMode _decodeThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static String _normalizeLocaleCode(String localeCode) {
    return AppLocalizations.normalizeLanguageCode(localeCode);
  }

  static Map<ExpenseCategory, double> _normalizeCategoryPlans(
    Map<String, double> source,
  ) {
    return <ExpenseCategory, double>{
      for (final ExpenseCategory category in ExpenseCategory.values)
        category: (source[category.key] ?? 0) < 0
            ? 0
            : (source[category.key] ?? 0),
    };
  }

  static Map<String, double> _encodeCategoryPlans(
    Map<ExpenseCategory, double> values,
  ) {
    return <String, double>{
      for (final MapEntry<ExpenseCategory, double> entry in values.entries)
        entry.key.key: entry.value < 0 ? 0 : entry.value,
    };
  }

  static List<BankAccount> _normalizeBankAccounts(
    List<Map<String, dynamic>> source,
  ) {
    if (source.isEmpty) {
      return const <BankAccount>[];
    }
    return source.map(BankAccount.fromMap).toList(growable: false);
  }

  static List<CustomCategory> _normalizeCustomCategories(
    List<Map<String, dynamic>> source,
  ) {
    if (source.isEmpty) {
      return const <CustomCategory>[];
    }

    return source.map(CustomCategory.fromMap).toList(growable: false);
  }

  BankAccount _defaultBankAccount() {
    return BankAccount(
      id: AppConstants.defaultBankAccountId,
      name: localizedMainWalletLabel,
      institution: localizedGeneralLabel,
      createdAt: DateTime.now(),
      iconCodePoint: 0xe850,
      colorValue: 0xFF42A5F5,
    );
  }

  bool _syncLocalizedDefaultBankAccountLabels() {
    final int index = _bankAccounts.indexWhere(
      (BankAccount account) => account.id == AppConstants.defaultBankAccountId,
    );
    if (index < 0) {
      return false;
    }

    final BankAccount account = _bankAccounts[index];
    final bool shouldReplaceName = _isDefaultMainWalletAlias(account.name);
    final bool shouldReplaceInstitution = _isDefaultGeneralAlias(
      account.institution,
    );
    if (!shouldReplaceName && !shouldReplaceInstitution) {
      return false;
    }

    final String updatedName = shouldReplaceName
        ? localizedMainWalletLabel
        : account.name;
    final String updatedInstitution = shouldReplaceInstitution
        ? localizedGeneralLabel
        : account.institution;

    if (updatedName == account.name &&
        updatedInstitution == account.institution) {
      return false;
    }

    _bankAccounts = <BankAccount>[
      ..._bankAccounts.sublist(0, index),
      BankAccount(
        id: account.id,
        name: updatedName,
        institution: updatedInstitution,
        createdAt: account.createdAt,
        iconCodePoint: account.iconCodePoint,
        colorValue: account.colorValue,
      ),
      ..._bankAccounts.sublist(index + 1),
    ];
    return true;
  }

  bool _isDefaultMainWalletAlias(String value) {
    return _mainWalletAliases.contains(_normalizeAlias(value));
  }

  bool _isDefaultGeneralAlias(String value) {
    return _generalAliases.contains(_normalizeAlias(value));
  }

  static String _normalizeAlias(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _localizedMainWalletLabel(String localeCode) {
    final String normalized = _normalizeLocaleCode(localeCode);
    return _mainWalletByLocale[normalized] ?? _mainWalletByLocale['en']!;
  }

  static String _localizedGeneralLabel(String localeCode) {
    final String normalized = _normalizeLocaleCode(localeCode);
    return _generalByLocale[normalized] ?? _generalByLocale['en']!;
  }

  static String _localizedBankLabel(String localeCode) {
    final String normalized = _normalizeLocaleCode(localeCode);
    return _bankByLocale[normalized] ?? _bankByLocale['en']!;
  }

  static Set<String> _buildMainWalletAliases() {
    final Set<String> aliases = <String>{
      'main',
      'wallet',
      'main wallet',
      'main account',
    };
    for (final String code in AppLocalizations.supportedLanguageCodes) {
      aliases.add(_normalizeAlias(_localizedMainWalletLabel(code)));
    }
    return aliases;
  }

  static Set<String> _buildGeneralAliases() {
    final Set<String> aliases = <String>{'general', 'generale', 'bank'};
    for (final String code in AppLocalizations.supportedLanguageCodes) {
      aliases
        ..add(_normalizeAlias(_localizedGeneralLabel(code)))
        ..add(_normalizeAlias(_localizedBankLabel(code)));
    }
    return aliases;
  }

  static const Map<String, String> _mainWalletByLocale = <String, String>{
    'en': 'Main Wallet',
    'fr': 'Portefeuille principal',
    'ar': 'المحفظة الرئيسية',
    'es': 'Billetera principal',
    'de': 'Hauptwallet',
    'it': 'Portafoglio principale',
    'pt': 'Carteira principal',
    'ru': 'Основной кошелек',
    'tr': 'Ana cüzdan',
    'id': 'Dompet utama',
    'hi': 'मुख्य वॉलेट',
    'zh': '主钱包',
    'ja': 'メインウォレット',
    'ko': '메인 지갑',
    'nl': 'Hoofdportemonnee',
  };

  static const Map<String, String> _generalByLocale = <String, String>{
    'en': 'General',
    'fr': 'Général',
    'ar': 'عام',
    'es': 'General',
    'de': 'Allgemein',
    'it': 'Generale',
    'pt': 'Geral',
    'ru': 'Общий',
    'tr': 'Genel',
    'id': 'Umum',
    'hi': 'सामान्य',
    'zh': '通用',
    'ja': '一般',
    'ko': '일반',
    'nl': 'Algemeen',
  };

  static const Map<String, String> _bankByLocale = <String, String>{
    'en': 'Bank',
    'fr': 'Banque',
    'ar': 'بنك',
    'es': 'Banco',
    'de': 'Bank',
    'it': 'Banca',
    'pt': 'Banco',
    'ru': 'Банк',
    'tr': 'Banka',
    'id': 'Bank',
    'hi': 'बैंक',
    'zh': '银行',
    'ja': '銀行',
    'ko': '은행',
    'nl': 'Bank',
  };

  static final Set<String> _mainWalletAliases = _buildMainWalletAliases();
  static final Set<String> _generalAliases = _buildGeneralAliases();

  Future<void> _persistBankAccounts() async {
    await _settingsRepository.setBankAccounts(
      _bankAccounts.map((BankAccount account) => account.toMap()).toList(),
    );
  }

  Future<void> _persistCustomCategories() async {
    await _settingsRepository.setCustomCategories(
      _customCategories
          .map((CustomCategory category) => category.toMap())
          .toList(),
    );
  }
}

