
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/services/home_widget_service.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/accounts/account_selector_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/onboarding/onboarding_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/shell/main_shell_page.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/app_logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _openMainShell();
  }

  Future<void> _openMainShell() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) {
      return;
    }
    final SettingsController settings = context.read<SettingsController>();
    final HomeWidgetService homeWidgetService = context
        .read<HomeWidgetService>();
    final NavigatorState navigator = Navigator.of(context);
    if (!settings.maintenanceNoticeAcknowledged) {
      // Do not block splash navigation if cloud write is denied/offline.
      unawaited(
        settings.setMaintenanceNoticeAcknowledged(true).catchError((_) {}),
      );
    }
    final HomeWidgetQuickAction? launchAction = await homeWidgetService
        .initiallyLaunchedQuickAction();
    if (!mounted || !navigator.mounted) {
      return;
    }
    final Widget nextPage = settings.hasCompletedOnboarding
        ? (launchAction != null && launchAction != HomeWidgetQuickAction.openApp
              ? MainShellPage(initialQuickAction: launchAction)
              : AccountSelectorPage(initialQuickAction: launchAction))
        : const OnboardingPage();

    navigator.pushReplacement(AppRouter.slideFade(nextPage));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double logoSize = (screenWidth * 0.52).clamp(180.0, 260.0);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppLogo(
                    size: logoSize,
                    assetPath: 'assets/icons/app_icon.jpeg',
                    heroTag: 'splash_logo',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.tr('appName'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.tr('appTaglineShort'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
