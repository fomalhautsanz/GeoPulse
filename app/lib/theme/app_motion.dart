import 'package:flutter/widgets.dart';

/// Every animation timing in the app, from the Figma motion table
/// ("Reference · Risk colours and motion").
///
/// Rule from the spec: motion only shows a change of state; it never
/// decorates. Live readings never animate.
class AppMotion {
  AppMotion._();

  // Button press: scale to 0.97 for instant feedback.
  static const Duration press = Duration(milliseconds: 120);
  static const double pressScale = 0.97;
  static const Curve pressCurve = Curves.easeOut;

  // Risk level changes: hero colour crossfades in place, no slide or bounce.
  static const Duration levelChange = Duration(milliseconds: 200);
  static const Curve levelCurve = Curves.easeOut;

  // Critical alert opens: fades in and rises 8 px; warning ring pulses.
  static const Duration alertIn = Duration(milliseconds: 250);
  static const double alertRise = 8;
  static const Duration pulse = Duration(milliseconds: 1200);
  static const double pulseScale = 1.15;

  // Map node sheet: slides up, can be dragged down.
  static const Duration sheet = Duration(milliseconds: 300);
  static const Curve sheetCurve = Cubic(0.32, 0.72, 0, 1);

  // Silence on this phone: 2 s linear hold, 200 ms snap back.
  static const Duration hold = Duration(seconds: 2);
  static const Duration holdRelease = Duration(milliseconds: 200);

  // Dialogs fade in; also the fallback when animations are turned off.
  static const Duration dialog = Duration(milliseconds: 150);
  static const Duration shortFade = Duration(milliseconds: 100);

  /// True when the user turned animations off (Android: Settings ›
  /// Accessibility › "Remove animations"). Then we skip movement and use
  /// instant changes or short fades.
  ///
  /// `MediaQuery.disableAnimationsOf(context)` reads the same value as
  /// `MediaQuery.of(context).disableAnimations`, but only rebuilds the
  /// widget when that one setting changes.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// How long a risk-level colour change takes right now.
  static Duration levelChangeFor(BuildContext context) =>
      reduced(context) ? shortFade : levelChange;
}
