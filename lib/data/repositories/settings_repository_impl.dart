import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wfer_flousk_firebase/core/constants/app_constants.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_data_service.dart';
import 'package:wfer_flousk_firebase/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._firebaseDataService);

  final FirebaseDataService _firebaseDataService;
  final Map<String, dynamic> _cache = <String, dynamic>{};

  Future<void> initialize() async {
    try {
      final DocumentReference<Map<String, dynamic>> settingsDoc =
          await _firebaseDataService.settingsDocument();
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await settingsDoc.get();
      final Map<String, dynamic>? data = snapshot.data();
      if (data != null) {
        _cache
          ..clear()
          ..addAll(data);
      }
    } catch (_) {
      // Keep defaults when cloud settings are unavailable.
    }
  }

  @override
  String getCurrencyCode() {
    return _cache[AppConstants.settingCurrencyCode] as String? ?? 'USD';
  }

  @override
  String getLocaleCode() {
    return _cache[AppConstants.settingLocaleCode] as String? ?? 'en';
  }

  @override
  double getMonthlyIncome() {
    return _asDouble(_cache[AppConstants.settingMonthlyIncome]);
  }

  @override
  double getMonthlySavingsGoal() {
    return _asDouble(_cache[AppConstants.settingMonthlySavingsGoal]);
  }

  @override
  Map<String, double> getCategoryMonthlyPlans() {
    final dynamic value = _cache[AppConstants.settingCategoryMonthlyPlans];
    if (value is! Map) {
      return const <String, double>{};
    }
    final Map<String, double> result = <String, double>{};
    value.forEach((dynamic key, dynamic rawValue) {
      if (key is String && rawValue is num) {
        result[key] = rawValue.toDouble();
      }
    });
    return result;
  }

  @override
  bool hasCompletedOnboarding() {
    return _cache[AppConstants.settingHasCompletedOnboarding] as bool? ?? false;
  }

  @override
  String getUserFirstName() {
    return _cache[AppConstants.settingUserFirstName] as String? ?? '';
  }

  @override
  String getUserLastName() {
    return _cache[AppConstants.settingUserLastName] as String? ?? '';
  }

  @override
  String getThemeMode() {
    return _cache[AppConstants.settingThemeMode] as String? ?? 'dark';
  }

  @override
  bool isProEnabled() {
    return _cache[AppConstants.settingIsPro] as bool? ?? false;
  }

  @override
  Future<void> setCurrencyCode(String code) async {
    _cache[AppConstants.settingCurrencyCode] = code;
    await _saveSettings(<String, dynamic>{AppConstants.settingCurrencyCode: code});
  }

  @override
  Future<void> setLocaleCode(String code) async {
    _cache[AppConstants.settingLocaleCode] = code;
    await _saveSettings(<String, dynamic>{AppConstants.settingLocaleCode: code});
  }

  @override
  Future<void> setMonthlyIncome(double value) async {
    _cache[AppConstants.settingMonthlyIncome] = value;
    await _saveSettings(<String, dynamic>{AppConstants.settingMonthlyIncome: value});
  }

  @override
  Future<void> setMonthlySavingsGoal(double value) async {
    _cache[AppConstants.settingMonthlySavingsGoal] = value;
    await _saveSettings(<String, dynamic>{AppConstants.settingMonthlySavingsGoal: value});
  }

  @override
  Future<void> setCategoryMonthlyPlans(Map<String, double> values) async {
    _cache[AppConstants.settingCategoryMonthlyPlans] = values;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingCategoryMonthlyPlans: values,
    });
  }

  @override
  Future<void> setHasCompletedOnboarding(bool value) async {
    _cache[AppConstants.settingHasCompletedOnboarding] = value;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingHasCompletedOnboarding: value,
    });
  }

  @override
  Future<void> setUserFirstName(String value) async {
    _cache[AppConstants.settingUserFirstName] = value;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingUserFirstName: value,
    });
  }

  @override
  Future<void> setUserLastName(String value) async {
    _cache[AppConstants.settingUserLastName] = value;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingUserLastName: value,
    });
  }

  @override
  Future<void> setProEnabled(bool value) async {
    _cache[AppConstants.settingIsPro] = value;
    await _saveSettings(<String, dynamic>{AppConstants.settingIsPro: value});
  }

  @override
  Future<void> setThemeMode(String mode) async {
    _cache[AppConstants.settingThemeMode] = mode;
    await _saveSettings(<String, dynamic>{AppConstants.settingThemeMode: mode});
  }

  @override
  List<Map<String, dynamic>> getBankAccounts() {
    final dynamic value = _cache[AppConstants.settingBankAccounts];
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final dynamic item in value) {
      if (item is Map) {
        result.add(<String, dynamic>{
          for (final MapEntry<dynamic, dynamic> e in item.entries)
            '${e.key}': e.value,
        });
      }
    }
    return result;
  }

  @override
  Future<void> setBankAccounts(List<Map<String, dynamic>> value) async {
    _cache[AppConstants.settingBankAccounts] = value;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingBankAccounts: value,
    });
  }

  @override
  String getActiveBankAccountId() {
    return _cache[AppConstants.settingActiveBankAccountId] as String?
        ?? AppConstants.defaultBankAccountId;
  }

  @override
  Future<void> setActiveBankAccountId(String value) async {
    _cache[AppConstants.settingActiveBankAccountId] = value;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingActiveBankAccountId: value,
    });
  }

  @override
  List<Map<String, dynamic>> getCustomCategories() {
    final dynamic value = _cache[AppConstants.settingCustomCategories];
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final dynamic item in value) {
      if (item is Map) {
        result.add(<String, dynamic>{
          for (final MapEntry<dynamic, dynamic> e in item.entries)
            '${e.key}': e.value,
        });
      }
    }
    return result;
  }

  @override
  Future<void> setCustomCategories(List<Map<String, dynamic>> value) async {
    _cache[AppConstants.settingCustomCategories] = value;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingCustomCategories: value,
    });
  }

  @override
  bool getMaintenanceNoticeAcknowledged() {
    return _cache[AppConstants.settingMaintenanceNoticeAcknowledged] as bool?
        ?? false;
  }

  @override
  Future<void> setMaintenanceNoticeAcknowledged(bool value) async {
    _cache[AppConstants.settingMaintenanceNoticeAcknowledged] = value;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingMaintenanceNoticeAcknowledged: value,
    });
  }

  @override
  String getAccentPreset() {
    return _cache[AppConstants.settingAccentPreset] as String? ?? 'blue';
  }

  @override
  Future<void> setAccentPreset(String value) async {
    _cache[AppConstants.settingAccentPreset] = value;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingAccentPreset: value,
    });
  }

  @override
  String getBackgroundStyle() {
    return _cache[AppConstants.settingBackgroundStyle] as String? ?? 'classic';
  }

  @override
  Future<void> setBackgroundStyle(String value) async {
    _cache[AppConstants.settingBackgroundStyle] = value;
    await _saveSettings(<String, dynamic>{
      AppConstants.settingBackgroundStyle: value,
    });
  }

  Future<void> _saveSettings(Map<String, dynamic> values) async {
    try {
      final DocumentReference<Map<String, dynamic>> settingsDoc =
          await _firebaseDataService.settingsDocument();
      await settingsDoc.set(values, SetOptions(merge: true));
    } catch (error, stackTrace) {
      debugPrint('Settings cloud write failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      // Keep local cache updated even when cloud write is denied/unavailable.
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }
}

