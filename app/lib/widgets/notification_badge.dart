import 'package:flutter/material.dart';

import '../models/notifications.dart';
import '../theme/app_colors.dart';
import 'common.dart';

/// The round icon for each notification type, as in the Figma list:
/// siren on maroon (critical), pulse on red (high), warning on rose
/// (watch), shield (back to stable), crossed-out cloud (offline).
class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key, required this.type, this.size = 40});

  final NotificationType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = switch (type) {
      NotificationType.critical => (Icons.volume_up_outlined, AppColors.criticalContainer, AppColors.criticalOn),
      NotificationType.high => (Icons.monitor_heart_outlined, AppColors.brand, AppColors.onBrand),
      NotificationType.watch => (Icons.warning_amber_rounded, AppColors.watchContainer, AppColors.watchStrong),
      NotificationType.backToStable => (Icons.shield_outlined, AppColors.card, AppColors.ink),
      NotificationType.offline => (Icons.cloud_off_outlined, Colors.transparent, AppColors.ink),
      NotificationType.lowBattery => (Icons.battery_2_bar_rounded, AppColors.card, AppColors.ink),
    };
    return IconBadge(icon: icon, background: bg, foreground: fg, size: size, iconSize: size * 0.5);
  }
}
