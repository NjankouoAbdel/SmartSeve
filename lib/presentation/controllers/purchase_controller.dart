import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:wfer_flousk_firebase/core/constants/app_constants.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_toolkit_service.dart';
import 'package:wfer_flousk_firebase/core/services/purchase_service.dart';
import 'package:wfer_flousk_firebase/domain/repositories/settings_repository.dart';

class PurchaseController extends ChangeNotifier {
  PurchaseController({
    required PurchaseService purchaseService,
    required SettingsRepository settingsRepository,
    required FirebaseToolkitService firebaseToolkitService,
    required this.onProChanged,
  }) : _purchaseService = purchaseService,
       _settingsRepository = settingsRepository,
       _firebaseToolkitService = firebaseToolkitService;

  final PurchaseService _purchaseService;
  final SettingsRepository _settingsRepository;
  final FirebaseToolkitService _firebaseToolkitService;
  final void Function(bool isPro) onProChanged;

  bool _storeAvailable = false;
  bool _isLoading = false;
  bool _isPurchasePending = false;
  String? _errorMessage;
  ProductDetails? _product;
  bool _listenerStarted = false;
  bool _hasSyncedOwnedPurchases = false;
  String _localeCode = 'en';

  bool get storeAvailable => _storeAvailable;
  bool get isLoading => _isLoading;
  bool get isPurchasePending => _isPurchasePending;
  String? get errorMessage => _errorMessage;
  String get localizedPrice => _product?.price ?? '4.99';
  bool get hasProduct => _product != null;

  void setLocaleCode(String localeCode) {
    _localeCode = AppLocalizations.normalizeLanguageCode(localeCode);
  }

  Future<void> initialize() async {
    if (_isLoading) {
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _storeAvailable = await _purchaseService.isStoreAvailable();
      if (!_storeAvailable) {
        _errorMessage = _t(
          'Google Play Billing is not available on this device.',
          fr: 'Google Play Billing n est pas disponible sur cet appareil.',
        );
        return;
      }

      if (!_listenerStarted) {
        _purchaseService.startPurchaseListener(
          onData: _onPurchaseUpdates,
          onError: (Object error) {
            _isPurchasePending = false;
            _errorMessage = _ta('Billing error: {error}', <String, String>{
              'error': error.toString(),
            }, fr: 'Erreur de facturation : {error}');
            notifyListeners();
          },
        );
        _listenerStarted = true;
      }

      _product = await _purchaseService.queryProduct(
        AppConstants.iapProProductId,
      );
      if (_product == null) {
        _errorMessage = _ta(
          'Product not found. Create "{id}" in Play Console.',
          <String, String>{'id': AppConstants.iapProProductId},
          fr: 'Produit introuvable. Creez "{id}" dans Play Console.',
        );
      }

      if (_settingsRepository.isProEnabled()) {
        onProChanged(true);
      }

      // Auto-sync previous purchases on launch so Pro can unlock automatically
      // after reinstall/login with the same Google account.
      if (!_hasSyncedOwnedPurchases) {
        await _silentSyncOwnedPurchases();
        _hasSyncedOwnedPurchases = true;
      }
    } catch (e) {
      _errorMessage = _ta(
        'Billing init failed: {error}',
        <String, String>{'error': e.toString()},
        fr: 'Initialisation billing echouee : {error}',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> buyPro() async {
    if (!_storeAvailable) {
      _errorMessage = _t(
        'Google Play Billing is unavailable.',
        fr: 'Google Play Billing est indisponible.',
      );
      notifyListeners();
      return;
    }
    if (_product == null) {
      _errorMessage = _t(
        'Product unavailable. Check Play Console product ID and app version.',
        fr: 'Produit indisponible. Verifiez l identifiant Play Console et la version de l application.',
      );
      notifyListeners();
      return;
    }

    _isPurchasePending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _purchaseService.buyNonConsumable(_product!);
    } catch (e) {
      _isPurchasePending = false;
      _errorMessage = _ta('Purchase failed: {error}', <String, String>{
        'error': e.toString(),
      }, fr: 'Achat echoue : {error}');
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    bool hasPending = false;

    for (final PurchaseDetails purchase in purchases) {
      if (purchase.productID != AppConstants.iapProProductId) {
        await _purchaseService.completePurchase(purchase);
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          hasPending = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grantProAccess();
          _errorMessage = null;
          break;
        case PurchaseStatus.canceled:
          _errorMessage = _t('Purchase canceled.', fr: 'Achat annule.');
          break;
        case PurchaseStatus.error:
          _errorMessage =
              purchase.error?.message ??
              _t('Purchase failed.', fr: 'Achat echoue.');
          break;
      }

      await _purchaseService.completePurchase(purchase);
    }

    _isPurchasePending = hasPending;
    notifyListeners();
  }

  Future<void> restorePurchases() async {
    if (!_storeAvailable) {
      _errorMessage = _t(
        'Google Play Billing is unavailable.',
        fr: 'Google Play Billing est indisponible.',
      );
      notifyListeners();
      return;
    }

    _isPurchasePending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _purchaseService.restorePurchases();
    } catch (e) {
      _errorMessage = _ta('Restore failed: {error}', <String, String>{
        'error': e.toString(),
      }, fr: 'Restauration echouee : {error}');
    } finally {
      _isPurchasePending = false;
      notifyListeners();
    }
  }

  Future<void> _grantProAccess() async {
    await _settingsRepository.setProEnabled(true);
    onProChanged(true);
    try {
      await _firebaseToolkitService.setSubscriptionStatus(isPro: true);
    } catch (_) {}
  }

  Future<void> _silentSyncOwnedPurchases() async {
    if (!_storeAvailable) {
      return;
    }
    try {
      await _purchaseService.restorePurchases();
    } catch (_) {
      // Silent on startup: manual "Restore Purchases" remains available in UI.
    }
  }

  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }

  String _t(String english, {String? fr}) {
    return AppLocalizations.phraseForLocale(_localeCode, english, french: fr);
  }

  String _ta(String english, Map<String, String> args, {String? fr}) {
    return AppLocalizations.phraseWithArgsForLocale(
      _localeCode,
      english,
      args,
      french: fr,
    );
  }
}

