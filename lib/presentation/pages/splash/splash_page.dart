import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/navigation/post_auth_navigation.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/auth/require_login_page.dart';
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

    // Security requirement: every user must be tied to a real, verifiable
    // email account before reaching onboarding or the app's home screen —
    // silent anonymous access alone is never enough past this point.
    final ToolsController tools = context.read<ToolsController>();
    if (!tools.isLoggedIn) {
      final NavigatorState navigator = Navigator.of(context);
      if (!navigator.mounted) {
        return;
      }
      navigator.pushReplacement(AppRouter.slideFade(const RequireLoginPage()));
      return;
    }

    await navigateToPostAuthDestination(context);
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
