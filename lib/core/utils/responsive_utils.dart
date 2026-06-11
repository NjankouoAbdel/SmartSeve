import 'dart:math';

import 'package:flutter/material.dart';

class ResponsiveUtils {
  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 700;
  }

  static bool isWideTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 1000;
  }

  static double horizontalPadding(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width < 320) {
      return 8;
    }
    if (width < 360) {
      return 12;
    }
    if (width >= 1200) {
      return 32;
    }
    if (width >= 700) {
      return 24;
    }
    return 16;
  }

  static double maxContentWidth(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return min(width, 1200);
  }
}
