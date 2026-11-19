import 'package:flutter/painting.dart';

import '../models/device_status.dart';
import 'app_colors.dart';

/// The colours and name for one risk level, so every widget shows a level
/// the same way. A level is never shown by colour alone: the icon and the
/// title also change.
class LevelStyle {
  const LevelStyle._({
    required this.label,
    required this.container,
    required this.onContainer,
    required this.strong,
    required this.glow,
  });

  final String label; // "Stable", "Watch", …
  final Color container; // chip / badge background
  final Color onContainer; // text on [container]
  final Color strong; // accent: hero icon, warning values
  final Color glow; // dome behind the status icon

  static const _stable = LevelStyle._(
    label: 'Stable',
    container: AppColors.stableContainer,
    onContainer: AppColors.stableOn,
    strong: AppColors.ink,
    glow: AppColors.heroGlow,
  );
  static const _watch = LevelStyle._(
    label: 'Watch',
    container: AppColors.watchContainer,
    onContainer: AppColors.watchOn,
    strong: AppColors.watchStrong,
    glow: AppColors.watchContainer,
  );
  static const _high = LevelStyle._(
    label: 'High',
    container: AppColors.highContainer,
    onContainer: AppColors.highOn,
    strong: AppColors.brand,
    glow: AppColors.highGlow,
  );
  static const _critical = LevelStyle._(
    label: 'Critical',
    container: AppColors.criticalContainer,
    onContainer: AppColors.criticalOn,
    strong: AppColors.criticalContainer,
    glow: AppColors.criticalGlow,
  );

  static LevelStyle of(StatusLevel level) => switch (level) {
        StatusLevel.stable => _stable,
        StatusLevel.watch => _watch,
        StatusLevel.high => _high,
        StatusLevel.critical => _critical,
      };
}
