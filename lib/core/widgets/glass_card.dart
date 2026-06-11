import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.borderRadius = 20,
    this.gradient,
    this.innerGlow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Gradient? gradient;
  final bool innerGlow;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient:
                  gradient ??
                  (isDark
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.08),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.94),
                            Colors.white.withValues(alpha: 0.84),
                          ],
                        )),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.48),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.1),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
                if (innerGlow)
                  BoxShadow(
                    color: AppColors.softBlueGlow.withValues(
                      alpha: isDark ? 0.08 : 0.06,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, -2),
                  ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

