import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Wraps anything tappable and gives it press feedback: it shrinks to 97%
/// while the finger is down (120 ms, ease-out). No ripple or hover effect.
///
/// When the user turned animations off it dims briefly instead of moving.
/// Pass `onTap: null` to disable it.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// What a screen reader says. Leave null if [child] already has text.
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final down = enabled && _pressed;

    final Widget feedback = AppMotion.reduced(context)
        ? AnimatedOpacity(
            opacity: down ? 0.7 : 1,
            duration: AppMotion.shortFade,
            child: widget.child,
          )
        : AnimatedScale(
            scale: down ? AppMotion.pressScale : 1,
            duration: AppMotion.press,
            curve: AppMotion.pressCurve,
            child: widget.child,
          );

    // MergeSemantics: a screen reader reads the button and its text as one.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: widget.onTap,
          child: Opacity(opacity: enabled ? 1 : 0.5, child: feedback),
        ),
      ),
    );
  }
}
