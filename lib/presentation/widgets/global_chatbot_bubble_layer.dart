import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/theme/theme_preferences.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/tools/finance_chatbot_page.dart';

class GlobalChatbotBubbleLayer extends StatefulWidget {
  const GlobalChatbotBubbleLayer({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<GlobalChatbotBubbleLayer> createState() =>
      _GlobalChatbotBubbleLayerState();
}

class _GlobalChatbotBubbleLayerState extends State<GlobalChatbotBubbleLayer> {
  static const double _bubbleSize = 62;
  static const double _dragThreshold = 4;

  Offset? _position;
  bool _dragging = false;
  bool _opening = false;
  Offset? _pointerDownGlobal;
  Offset? _startBubblePosition;
  bool _movedDuringPointer = false;

  Offset _clampPosition(
    Offset raw,
    Size size,
    EdgeInsets padding,
    EdgeInsets insets,
  ) {
    final double minX = 8 + padding.left;
    final double maxX = max(minX, size.width - _bubbleSize - 8 - padding.right);
    final double minY = 8 + padding.top;
    final double bottomInset = max(insets.bottom + 12, padding.bottom + 12);
    final double maxY = max(minY, size.height - _bubbleSize - bottomInset);
    return Offset(raw.dx.clamp(minX, maxX), raw.dy.clamp(minY, maxY));
  }

  Offset _defaultPosition(Size size, EdgeInsets padding, EdgeInsets insets) {
    final double preferredBottom = max(
      insets.bottom + 16,
      padding.bottom + 108,
    );
    final Offset raw = Offset(
      size.width - _bubbleSize - 16 - padding.right,
      size.height - _bubbleSize - preferredBottom,
    );
    return _clampPosition(raw, size, padding, insets);
  }

  Future<void> _openChatbot() async {
    if (_opening) {
      return;
    }
    final NavigatorState? navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    setState(() => _opening = true);
    try {
      await navigator.push<void>(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 330),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder:
              (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
              ) {
                return const FinanceChatbotPage();
              },
          transitionsBuilder:
              (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
                Widget child,
              ) {
                final CurvedAnimation curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0.06),
                      end: Offset.zero,
                    ).animate(curved),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
                      child: child,
                    ),
                  ),
                );
              },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final MediaQueryData media = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final EdgeInsets padding = media.padding;
        final EdgeInsets insets = media.viewInsets;

        _position ??= _defaultPosition(size, padding, insets);
        _position = _clampPosition(_position!, size, padding, insets);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            widget.child,
            AnimatedPositioned(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: _position!.dx,
              top: _position!.dy,
              child: AnimatedOpacity(
                opacity: _opening ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: _opening,
                  child: Listener(
                    onPointerDown: (PointerDownEvent event) {
                      _pointerDownGlobal = event.position;
                      _startBubblePosition = _position;
                      _movedDuringPointer = false;
                      setState(() => _dragging = true);
                    },
                    onPointerMove: (PointerMoveEvent event) {
                      if (_pointerDownGlobal == null ||
                          _startBubblePosition == null) {
                        return;
                      }
                      final Offset delta = event.position - _pointerDownGlobal!;
                      if (!_movedDuringPointer &&
                          delta.distance >= _dragThreshold) {
                        _movedDuringPointer = true;
                      }
                      if (!_movedDuringPointer) {
                        return;
                      }
                      setState(() {
                        _position = _clampPosition(
                          _startBubblePosition! + delta,
                          size,
                          padding,
                          insets,
                        );
                      });
                    },
                    onPointerUp: (_) {
                      final bool shouldOpen = !_movedDuringPointer;
                      _pointerDownGlobal = null;
                      _startBubblePosition = null;
                      _movedDuringPointer = false;
                      setState(() => _dragging = false);
                      if (shouldOpen) {
                        _openChatbot();
                      }
                    },
                    onPointerCancel: (_) {
                      _pointerDownGlobal = null;
                      _startBubblePosition = null;
                      _movedDuringPointer = false;
                      setState(() => _dragging = false);
                    },
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 140),
                      scale: _dragging ? 0.97 : 1,
                      child: Container(
                        width: _bubbleSize,
                        height: _bubbleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: settings.accentPreset.primary,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          size: 29,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

