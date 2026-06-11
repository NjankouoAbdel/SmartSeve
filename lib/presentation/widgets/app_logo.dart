import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 64,
    this.assetPath = 'assets/icons/app_icon2.png',
    this.heroTag = 'app_logo',
  });

  final double size;
  final String assetPath;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final Widget logo = SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );

    if (heroTag == null) {
      return logo;
    }

    return Hero(tag: heroTag!, child: logo);
  }
}
