import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// A page transition that fades the new screen in, optionally rising by
/// [rise] pixels as it does. With animations turned off it becomes a short
/// fade with no movement.
///
/// ```dart
/// Navigator.of(context).push(fadeRoute(context, const SettingsScreen()));
/// ```
Route<T> fadeRoute<T>(
  BuildContext context,
  Widget page, {
  Duration duration = AppMotion.levelChange,
  double rise = 0,
  bool fullscreenDialog = false,
}) {
  final reduced = AppMotion.reduced(context);

  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: reduced ? AppMotion.shortFade : duration,
    reverseTransitionDuration: reduced ? AppMotion.shortFade : AppMotion.levelChange,
    pageBuilder: (context, _, _) => page,
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final faded = FadeTransition(opacity: curved, child: child);
      if (reduced || rise == 0) return faded;
      return AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, rise * (1 - curved.value)),
          child: child,
        ),
        child: faded,
      );
    },
  );
}
