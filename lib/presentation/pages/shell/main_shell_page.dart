import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/shell_navigation_controller.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/services/home_widget_service.dart';
import 'package:wfer_flousk_firebase/core/theme/theme_preferences.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/add_expense/add_expense_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/home/home_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/settings/settings_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/statistics/statistics_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/transactions/transactions_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key, this.initialQuickAction});

  final HomeWidgetQuickAction? initialQuickAction;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;
  bool _isShellControllerBound = false;
  int _quickActionRequestCounter = 0;
  HomeWidgetQuickActionTrigger? _quickActionTrigger;
  StreamSubscription<HomeWidgetQuickAction>? _widgetActionSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuickAction != null) {
      _queueQuickAction(widget.initialQuickAction!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isShellControllerBound) {
      return;
    }
    context.read<ShellNavigationController>().bindGoHome(() {
      if (!mounted) {
        return;
      }
      setState(() => _currentIndex = 0);
    });
    _isShellControllerBound = true;

    _widgetActionSubscription ??= context
        .read<HomeWidgetService>()
        .quickActions
        .listen(_queueQuickAction);
  }

  void _openAddExpenseStandalone() {
    Navigator.of(context)
        .push<bool>(
          AppRouter.slideFade(const AddExpensePage(isStandalone: true)),
        )
        .then((bool? saved) {
          if (!mounted || saved != true) {
            return;
          }
          setState(() => _currentIndex = 0);
        });
  }

  List<Widget> get _pages => <Widget>[
    HomePage(
      onQuickAddTap: _openAddExpenseStandalone,
      quickActionTrigger: _quickActionTrigger,
      onQuickActionConsumed: _onQuickActionConsumed,
    ),
    const StatisticsPage(),
    const TransactionsPage(),
    const SettingsPage(),
  ];

  void _queueQuickAction(HomeWidgetQuickAction action) {
    if (!mounted) {
      return;
    }
    if (action == HomeWidgetQuickAction.openApp) {
      setState(() => _currentIndex = 0);
      return;
    }
    setState(() {
      _currentIndex = 0;
      _quickActionRequestCounter += 1;
      _quickActionTrigger = HomeWidgetQuickActionTrigger(
        action: action,
        requestId: _quickActionRequestCounter,
      );
    });
  }

  void _onQuickActionConsumed(int requestId) {
    if (_quickActionTrigger?.requestId != requestId) {
      return;
    }
    setState(() => _quickActionTrigger = null);
  }

  @override
  void dispose() {
    _widgetActionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final Animation<Offset> slide = Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_currentIndex),
              child: _pages[_currentIndex],
            ),
          ),
        ),
        bottomNavigationBar: _bottomBar(context, settings),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, SettingsController settings) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _ShellBottomStyle style = _bottomStyle(
      accent: settings.accentPreset,
      backgroundStyle: settings.backgroundStyle,
      isDark: isDark,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SizedBox(
          height: 84,
          child: Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      height: 66,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: style.barGradient,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: style.barBorder),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: style.barShadow,
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final bool compact = constraints.maxWidth < 330;
                              final double centerGap = compact ? 56 : 70;

                              return Row(
                                children: <Widget>[
                                  _navItem(
                                    icon: Icons.home_rounded,
                                    label: 'Home',
                                    index: 0,
                                    selectedColor: style.selectedItemColor,
                                    unselectedColor: style.unselectedItemColor,
                                    showLabel: !compact,
                                  ),
                                  _navItem(
                                    icon: Icons.bar_chart_rounded,
                                    label: 'Statistics',
                                    index: 1,
                                    selectedColor: style.selectedItemColor,
                                    unselectedColor: style.unselectedItemColor,
                                    showLabel: !compact,
                                  ),
                                  SizedBox(width: centerGap),
                                  _navItem(
                                    icon: Icons.receipt_long_rounded,
                                    label: 'Transactions',
                                    index: 2,
                                    selectedColor: style.selectedItemColor,
                                    unselectedColor: style.unselectedItemColor,
                                    showLabel: !compact,
                                  ),
                                  _navItem(
                                    icon: Icons.settings_rounded,
                                    label: 'Settings',
                                    index: 3,
                                    selectedColor: style.selectedItemColor,
                                    unselectedColor: style.unselectedItemColor,
                                    showLabel: !compact,
                                  ),
                                ],
                              );
                            },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: GestureDetector(
                  onTap: _openAddExpenseStandalone,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: style.fabGradient,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: style.fabGlow,
                          blurRadius: 22,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: style.fabBorder, width: 1),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required Color selectedColor,
    required Color unselectedColor,
    bool showLabel = true,
  }) {
    final bool selected = _currentIndex == index;
    final Color color = selected ? selectedColor : unselectedColor;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              if (showLabel) ...<Widget>[
                const SizedBox(height: 2),
                SizedBox(
                  height: 11,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.l10n.phrase(label),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        height: 1.0,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _ShellBottomStyle _bottomStyle({
    required AccentPreset accent,
    required BackgroundStyle backgroundStyle,
    required bool isDark,
  }) {
    final Color selected = isDark
        ? accent.glow.withValues(alpha: 0.95)
        : accent.primary.withValues(alpha: 0.96);
    final Color unselected = isDark
        ? Colors.white.withValues(alpha: 0.66)
        : AppColors.deepBlue.withValues(alpha: 0.58);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.11)
        : AppColors.deepBlue.withValues(alpha: 0.14);
    final Color shadow = isDark
        ? Colors.black.withValues(alpha: 0.34)
        : AppColors.deepBlue.withValues(alpha: 0.18);
    final Color fabBorder = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : Colors.white.withValues(alpha: 0.70);
    final Color fabGlow = (isDark ? accent.glow : accent.primary).withValues(
      alpha: isDark ? 0.52 : 0.38,
    );

    List<Color> barGradient;
    switch (backgroundStyle) {
      case BackgroundStyle.classic:
        barGradient = isDark
            ? <Color>[
                const Color(0xFF0F1F31).withValues(alpha: 0.90),
                const Color(0xFF132A42).withValues(alpha: 0.94),
              ]
            : <Color>[
                const Color(0xFFFFFFFF).withValues(alpha: 0.88),
                const Color(0xFFF3F7FF).withValues(alpha: 0.90),
              ];
      case BackgroundStyle.aurora:
        barGradient = isDark
            ? <Color>[
                accent.primary.withValues(alpha: 0.42),
                accent.secondary.withValues(alpha: 0.34),
              ]
            : <Color>[
                accent.glow.withValues(alpha: 0.22),
                accent.secondary.withValues(alpha: 0.18),
              ];
      case BackgroundStyle.contrast:
        barGradient = isDark
            ? <Color>[
                const Color(0xFF0B111B).withValues(alpha: 0.92),
                accent.secondary.withValues(alpha: 0.28),
              ]
            : <Color>[
                const Color(0xFFF8FAFD).withValues(alpha: 0.90),
                accent.secondary.withValues(alpha: 0.12),
              ];
    }

    final LinearGradient fabGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[accent.primary, accent.secondary],
    );

    return _ShellBottomStyle(
      barGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: barGradient,
      ),
      barBorder: border,
      barShadow: shadow,
      selectedItemColor: selected,
      unselectedItemColor: unselected,
      fabGradient: fabGradient,
      fabGlow: fabGlow,
      fabBorder: fabBorder,
    );
  }
}

class _ShellBottomStyle {
  const _ShellBottomStyle({
    required this.barGradient,
    required this.barBorder,
    required this.barShadow,
    required this.selectedItemColor,
    required this.unselectedItemColor,
    required this.fabGradient,
    required this.fabGlow,
    required this.fabBorder,
  });

  final LinearGradient barGradient;
  final Color barBorder;
  final Color barShadow;
  final Color selectedItemColor;
  final Color unselectedItemColor;
  final LinearGradient fabGradient;
  final Color fabGlow;
  final Color fabBorder;
}

