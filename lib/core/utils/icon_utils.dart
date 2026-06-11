import 'package:flutter/material.dart';

class AppIconUtils {
  static const List<IconData> selectableIcons = <IconData>[
    Icons.account_balance_wallet_rounded,
    Icons.credit_card_rounded,
    Icons.account_balance_rounded,
    Icons.savings_rounded,
    Icons.payments_rounded,
    Icons.shopping_bag_rounded,
    Icons.fastfood_rounded,
    Icons.directions_bus_filled_rounded,
    Icons.bolt_rounded,
    Icons.label_rounded,
    Icons.restaurant_rounded,
    Icons.apartment_rounded,
    Icons.receipt_long_rounded,
    Icons.more_horiz_rounded,
    Icons.currency_exchange_rounded,
    Icons.work_rounded,
    Icons.star_rounded,
  ];

  static IconData fromCodePoint(
    int? codePoint, {
    IconData fallback = Icons.label_rounded,
  }) {
    if (codePoint == null) {
      return fallback;
    }
    for (final IconData icon in selectableIcons) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }
    return fallback;
  }
}
