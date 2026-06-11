import 'package:flutter/material.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';

enum AccentPreset { blue, emerald, amber, coral }

extension AccentPresetX on AccentPreset {
  String get key => name;

  static AccentPreset fromKey(String raw) {
    return AccentPreset.values.firstWhere(
      (AccentPreset preset) => preset.key == raw,
      orElse: () => AccentPreset.blue,
    );
  }

  String get label {
    switch (this) {
      case AccentPreset.blue:
        return 'Blue';
      case AccentPreset.emerald:
        return 'Emerald';
      case AccentPreset.amber:
        return 'Amber';
      case AccentPreset.coral:
        return 'Coral';
    }
  }

  Color get primary {
    switch (this) {
      case AccentPreset.blue:
        return AppColors.primaryBlue;
      case AccentPreset.emerald:
        return const Color(0xFF0F766E);
      case AccentPreset.amber:
        return const Color(0xFFB45309);
      case AccentPreset.coral:
        return const Color(0xFFBE123C);
    }
  }

  Color get secondary {
    switch (this) {
      case AccentPreset.blue:
        return AppColors.gradientBlue2;
      case AccentPreset.emerald:
        return const Color(0xFF10B981);
      case AccentPreset.amber:
        return const Color(0xFFF59E0B);
      case AccentPreset.coral:
        return const Color(0xFFFB7185);
    }
  }

  Color get glow {
    switch (this) {
      case AccentPreset.blue:
        return AppColors.softBlueGlow;
      case AccentPreset.emerald:
        return const Color(0xFF34D399);
      case AccentPreset.amber:
        return const Color(0xFFFBBF24);
      case AccentPreset.coral:
        return const Color(0xFFFDA4AF);
    }
  }
}

enum BackgroundStyle { classic, aurora, contrast }

extension BackgroundStyleX on BackgroundStyle {
  String get key => name;

  static BackgroundStyle fromKey(String raw) {
    return BackgroundStyle.values.firstWhere(
      (BackgroundStyle style) => style.key == raw,
      orElse: () => BackgroundStyle.classic,
    );
  }

  String get label {
    switch (this) {
      case BackgroundStyle.classic:
        return 'Classic';
      case BackgroundStyle.aurora:
        return 'Aurora';
      case BackgroundStyle.contrast:
        return 'Contrast';
    }
  }
}

