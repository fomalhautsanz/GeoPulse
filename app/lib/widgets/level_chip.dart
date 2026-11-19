import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../theme/app_colors.dart';
import '../theme/level_style.dart';

/// A small rounded badge naming a risk level, e.g. "Critical" on maroon.
class LevelChip extends StatelessWidget {
  const LevelChip({super.key, required this.level});

  final StatusLevel level;

  @override
  Widget build(BuildContext context) {
    final style = LevelStyle.of(level);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.container,
        // The grey Stable chip needs an outline to show on white.
        border: level == StatusLevel.stable ? Border.all(color: AppColors.outline) : null,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 12,
          height: 1.172,
          fontWeight: FontWeight.w700,
          color: style.onContainer,
        ),
      ),
    );
  }
}
