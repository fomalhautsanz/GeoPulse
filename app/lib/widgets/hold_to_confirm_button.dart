import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// An outlined button that must be held for 2 seconds. A fill sweeps across
/// while holding; letting go early snaps it back (200 ms) and nothing
/// happens. Used for "Silence on this phone", so it can't happen by accident.
///
/// Screen-reader users confirm with a long press (double-tap and hold).
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.doneLabel,
    required this.done,
    required this.onConfirmed,
    this.height = 52,
  });

  final String label; // before
  final String doneLabel; // after confirming
  final bool done;
  final VoidCallback onConfirmed;
  final double height;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

// `with SingleTickerProviderStateMixin` lets this State drive one animation.
class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  // An AnimationController counts from 0.0 to 1.0 over its duration.
  // Here 0 = not held, 1 = held for the full 2 seconds.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: AppMotion.hold,
  )..addStatusListener(_onStatus);

  Offset? _downAt;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !widget.done) {
      HapticFeedback.heavyImpact();
      widget.onConfirmed();
    }
  }

  void _start(Offset position) {
    if (widget.done) return;
    _downAt = position;
    _progress.forward(); // linear, so the fill tracks time exactly
  }

  void _release() {
    _downAt = null;
    if (widget.done || _progress.isCompleted) return;
    if (AppMotion.reduced(context)) {
      _progress.value = 0; // instant
    } else {
      _progress.animateBack(0, duration: AppMotion.holdRelease, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.done ? widget.doneLabel : widget.label;

    return Semantics(
      button: true,
      enabled: !widget.done,
      label: label,
      hint: widget.done ? null : 'Hold for 2 seconds',
      onLongPress: widget.done ? null : () => _progress.value = 1,
      // Listener sees raw finger down/up events, which is what a hold needs.
      child: Listener(
        onPointerDown: (e) => _start(e.position),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        onPointerMove: (e) {
          // Sliding the finger away cancels, like a normal button.
          final start = _downAt;
          if (start != null && (e.position - start).distance > 24) _release();
        },
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.brand, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // AnimatedBuilder redraws its builder every animation frame.
                AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.done ? 1 : _progress.value,
                    child: const ColoredBox(color: AppColors.holdFill),
                  ),
                ),
                Center(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.172,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
