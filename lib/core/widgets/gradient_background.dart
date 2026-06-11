import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/theme/theme_preferences.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    SettingsController? settings;
    try {
      settings = Provider.of<SettingsController>(context, listen: true);
    } catch (_) {
      settings = null;
    }
    final AccentPreset accentPreset =
        settings?.accentPreset ?? AccentPreset.blue;
    final BackgroundStyle backgroundStyle =
        settings?.backgroundStyle ?? BackgroundStyle.classic;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _gradientColors(
            accentPreset: accentPreset,
            backgroundStyle: backgroundStyle,
            isDark: isDark,
          ),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -170,
            left: -40,
            right: -40,
            child: _BlurCircle(
              color: accentPreset.glow.withValues(alpha: isDark ? 0.24 : 0.18),
              size: 430,
            ),
          ),
          Positioned(
            top: 160,
            right: -120,
            child: _BlurCircle(
              color: accentPreset.primary.withValues(
                alpha: isDark ? 0.12 : 0.1,
              ),
              size: 320,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _BlurCircle(
              color: accentPreset.secondary.withValues(
                alpha: isDark ? 0.08 : 0.07,
              ),
              size: 300,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

List<Color> _gradientColors({
  required AccentPreset accentPreset,
  required BackgroundStyle backgroundStyle,
  required bool isDark,
}) {
  switch (backgroundStyle) {
    case BackgroundStyle.classic:
      return isDark ? AppColors.darkGradient : AppColors.lightGradient;
    case BackgroundStyle.aurora:
      return isDark
          ? <Color>[
              const Color(0xFF060A12),
              accentPreset.primary.withValues(alpha: 0.40),
              const Color(0xFF101827),
            ]
          : <Color>[
              const Color(0xFFF4F9FF),
              accentPreset.glow.withValues(alpha: 0.22),
              const Color(0xFFFFFFFF),
            ];
    case BackgroundStyle.contrast:
      return isDark
          ? <Color>[
              const Color(0xFF090D14),
              const Color(0xFF0F172A),
              accentPreset.secondary.withValues(alpha: 0.30),
            ]
          : <Color>[
              const Color(0xFFF6F8FC),
              const Color(0xFFEFF3F8),
              accentPreset.secondary.withValues(alpha: 0.14),
            ];
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

