import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  Future<bool> isStoreAvailable() async {
    if (kIsWeb) {
      return false;
    }
    return _inAppPurchase.isAvailable();
  }

  void startPurchaseListener({
    required Future<void> Function(List<PurchaseDetails>) onData,
    required void Function(Object error) onError,
  }) {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      onData,
      onError: onError,
    );
  }

  Future<ProductDetails?> queryProduct(String productId) async {
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(<String>{productId});
    if (response.error != null || response.productDetails.isEmpty) {
      return null;
    }
    return response.productDetails.first;
  }

  Future<void> buyNonConsumable(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }
}
