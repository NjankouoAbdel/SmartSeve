import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/shell_navigation_controller.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/tools_action_button.dart';

class FintechPageAppBar extends StatelessWidget {
  const FintechPageAppBar({
    required this.title,
    super.key,
    this.showBackToHome = false,
    this.onBackPressed,
  });

  final String title;
  final bool showBackToHome;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            height: 44,
            child: showBackToHome
                ? IconButton(
                    onPressed: () {
                      if (onBackPressed != null) {
                        onBackPressed!.call();
                        return;
                      }
                      final NavigatorState navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                        return;
                      }
                      context.read<ShellNavigationController>().goHome();
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: context.l10n.phrase(
                      'Back to home',
                      french: 'Retour a l accueil',
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              context.l10n.phrase(title),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 44, height: 44, child: ToolsActionButton()),
        ],
      ),
    );
  }
}

