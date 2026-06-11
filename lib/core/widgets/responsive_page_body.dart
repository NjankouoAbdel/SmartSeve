import 'package:flutter/material.dart';
import 'package:wfer_flousk_firebase/core/utils/responsive_utils.dart';

class ResponsivePageBody extends StatelessWidget {
  const ResponsivePageBody({
    required this.child,
    super.key,
    this.top = 10,
    this.bottom = 10,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = ResponsiveUtils.horizontalPadding(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveUtils.maxContentWidth(context),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            top,
            horizontalPadding,
            bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}

