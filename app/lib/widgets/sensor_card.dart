import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'pressable.dart';

/// A grey card showing one sensor reading: an icon, a title, a big value
/// and a small caption.
///
/// ```dart
/// SensorCard(
///   icon: Image.asset('assets/icons/soil.png'),
///   title: 'Soil Moisture Status',
///   value: '49%',
///   caption: 'Normal · warning at 70%',
/// )
/// ```
class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    this.valueColor = AppColors.ink,
    this.accentColor,
    this.onTap,
  });

  /// Any widget; it's placed in a 52×52 box.
  final Widget icon;
  final String title;
  final String value;
  final String caption;

  /// Colour of the big value, e.g. [AppColors.watchStrong] when a reading is rising.
  final Color valueColor;

  /// When set, the card gets a border in this colour to draw the eye
  /// (e.g. the soil card at Watch or High).
  final Color? accentColor;

  /// When set, the card is tappable (Status → Sensors).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor;
    final card = Container(
      // 90 px tall like Figma, but allowed to grow if the user has a
      // larger system text size, instead of cutting text off.
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.fromLTRB(30, 11, 16, 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(
          color: accent ?? AppColors.outline,
          width: accent == null ? 1 : 1.5,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: SizedBox(width: 52, height: 52, child: icon),
          ),
          const SizedBox(width: 18),
          // Expanded lets the text take the remaining width.
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(title, 15, FontWeight.w700, AppColors.ink),
                // The value's colour fades when its risk level changes
                // (200 ms). The number itself just updates: live readings
                // never animate.
                AnimatedDefaultTextStyle(
                  duration: AppMotion.levelChangeFor(context),
                  curve: AppMotion.levelCurve,
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.172,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _line(caption, 11, FontWeight.w500, AppColors.ink),
              ],
            ),
          ),
        ],
      ),
    );
    // MergeSemantics makes screen readers read the card as one item.
    return MergeSemantics(
      child: onTap == null ? card : Pressable(onTap: onTap, child: card),
    );
  }

  // Leading underscore = private helper, only usable inside this file.
  Widget _line(String text, double size, FontWeight weight, Color color) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // height 1.172 = Roboto's "normal" line height, as used in Figma.
      style: TextStyle(
        fontSize: size,
        height: 1.172,
        fontWeight: weight,
        color: color,
      ),
    );
  }
}
