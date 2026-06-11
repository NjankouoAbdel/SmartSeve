import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/tools/tools_center_page.dart';

class ToolsActionButton extends StatelessWidget {
  const ToolsActionButton({super.key, this.openNotificationsTab = true});

  final bool openNotificationsTab;

  @override
  Widget build(BuildContext context) {
    return Consumer<ToolsController>(
      builder: (BuildContext context, ToolsController tools, Widget? child) {
        final int unread = tools.unreadNoticeCount;

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IconButton(
              onPressed: () {
                final TabController? tabController =
                    DefaultTabController.maybeOf(context);
                if (openNotificationsTab &&
                    tabController != null &&
                    tabController.length > 1) {
                  tabController.animateTo(1);
                  return;
                }
                Navigator.of(context).push(
                  AppRouter.slideFade(
                    ToolsCenterPage(initialTab: openNotificationsTab ? 1 : 0),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: context.l10n.tr('toolsNotifications'),
            ),
            if (unread > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

