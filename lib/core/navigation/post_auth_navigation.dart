import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/services/home_widget_service.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/accounts/account_selector_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/onboarding/onboarding_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/shell/main_shell_page.dart';

/// Decides which page to show once the user is authenticated with a real
/// (non-anonymous) account and navigates to it, replacing the current route.
///
/// Used both by [SplashPage] (when a session is already active) and by
/// [RequireLoginPage] (right after a successful sign in / sign up), so the
/// "where do we go after auth" logic only lives in one place.
Future<void> navigateToPostAuthDestination(BuildContext context) async {
  final SettingsController settings = context.read<SettingsController>();
  final HomeWidgetService homeWidgetService = context
      .read<HomeWidgetService>();
  final NavigatorState navigator = Navigator.of(context);

  if (!settings.maintenanceNoticeAcknowledged) {
    // Do not block navigation if this cloud write is denied/offline.
    unawaited(
      settings.setMaintenanceNoticeAcknowledged(true).catchError((_) {}),
    );
  }

  final HomeWidgetQuickAction? launchAction = await homeWidgetService
      .initiallyLaunchedQuickAction();

  if (!navigator.mounted) {
    return;
  }

  final Widget nextPage = settings.hasCompletedOnboarding
      ? (launchAction != null && launchAction != HomeWidgetQuickAction.openApp
            ? MainShellPage(initialQuickAction: launchAction)
            : AccountSelectorPage(initialQuickAction: launchAction))
      : const OnboardingPage();

  navigator.pushReplacement(AppRouter.slideFade(nextPage));
}
