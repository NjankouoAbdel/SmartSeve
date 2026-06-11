import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

enum HomeWidgetQuickAction { openApp, addExpense, addIncome, addTransfer }

extension HomeWidgetQuickActionX on HomeWidgetQuickAction {
  String get key {
    switch (this) {
      case HomeWidgetQuickAction.openApp:
        return 'open';
      case HomeWidgetQuickAction.addExpense:
        return 'expense';
      case HomeWidgetQuickAction.addIncome:
        return 'income';
      case HomeWidgetQuickAction.addTransfer:
        return 'transfer';
    }
  }
}

class HomeWidgetQuickActionTrigger {
  const HomeWidgetQuickActionTrigger({
    required this.action,
    required this.requestId,
  });

  final HomeWidgetQuickAction action;
  final int requestId;
}

class HomeWidgetService {
  static const String _androidProviderName = 'SmartDailyHomeWidgetProvider';
  static const String _scheme = 'wferflousk';
  static const String _host = 'quick';

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Uri quickActionUri(HomeWidgetQuickAction action) {
    return Uri(
      scheme: _scheme,
      host: _host,
      queryParameters: <String, String>{'action': action.key},
    );
  }

  Future<HomeWidgetQuickAction?> initiallyLaunchedQuickAction() async {
    if (!isSupported) {
      return null;
    }
    final Uri? uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    return parseQuickAction(uri);
  }

  Stream<HomeWidgetQuickAction> get quickActions async* {
    if (!isSupported) {
      return;
    }
    await for (final Uri? uri in HomeWidget.widgetClicked) {
      final HomeWidgetQuickAction? action = parseQuickAction(uri);
      if (action != null) {
        yield action;
      }
    }
  }

  HomeWidgetQuickAction? parseQuickAction(Uri? uri) {
    if (uri == null) {
      return null;
    }
    final String action = (uri.queryParameters['action'] ?? uri.host)
        .trim()
        .toLowerCase();
    switch (action) {
      case 'expense':
        return HomeWidgetQuickAction.addExpense;
      case 'income':
        return HomeWidgetQuickAction.addIncome;
      case 'transfer':
        return HomeWidgetQuickAction.addTransfer;
      case 'open':
        return HomeWidgetQuickAction.openApp;
      default:
        return null;
    }
  }

  Future<void> updateDashboardWidget({
    required String accountName,
    required double balance,
    required double monthlySpending,
    required String currencyCode,
  }) async {
    if (!isSupported) {
      return;
    }

    final NumberFormat formatter = NumberFormat('#,##0.00');
    final String balanceText = '$currencyCode ${formatter.format(balance)}';
    final String spendingText =
        'Spent: $currencyCode ${formatter.format(monthlySpending)}';

    await HomeWidget.saveWidgetData<String>('widget_account', accountName);
    await HomeWidget.saveWidgetData<String>('widget_balance', balanceText);
    await HomeWidget.saveWidgetData<String>('widget_spending', spendingText);
    await HomeWidget.saveWidgetData<String>(
      'widget_updated',
      'Updated: ${DateFormat('HH:mm').format(DateTime.now())}',
    );

    await HomeWidget.updateWidget(androidName: _androidProviderName);
  }
}
