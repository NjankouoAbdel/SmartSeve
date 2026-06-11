import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/theme/app_theme.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/splash/splash_page.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/global_chatbot_bubble_layer.dart';
import 'package:provider/provider.dart';

class SmartExpenseApp extends StatelessWidget {
  const SmartExpenseApp({super.key});

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder:
          (BuildContext context, SettingsController settings, Widget? child) {
            return MaterialApp(
              navigatorKey: _navigatorKey,
              debugShowCheckedModeBanner: false,
              onGenerateTitle: (BuildContext context) {
                return context.l10n.tr('appName');
              },
              theme: AppTheme.lightTheme(settings.accentPreset),
              darkTheme: AppTheme.darkTheme(settings.accentPreset),
              themeMode: settings.themeMode,
              locale: settings.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (BuildContext context, Widget? child) {
                final MediaQueryData media = MediaQuery.of(context);
                final double scale = media.textScaler.scale(1).clamp(0.9, 1.0);
                return MediaQuery(
                  data: media.copyWith(textScaler: TextScaler.linear(scale)),
                  child: GlobalChatbotBubbleLayer(
                    navigatorKey: _navigatorKey,
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              home: const SplashPage(),
            );
          },
    );
  }
}

