import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// Filled = solid brand red (primary action). Outlined = white with a red
/// border (secondary action). Neutral = white with a grey border and dark
/// text (low-emphasis, e.g. "Export report").
enum AppButtonVariant { filled, outlined, neutral }

/// The app's button, with the standard press feedback from [Pressable].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.height = 52,
    this.minWidth = 0,
    this.horizontalPadding = 12,
    this.fontSize = 14,
  });

  final String label;
  final VoidCallback? onPressed; // null = disabled
  final AppButtonVariant variant;
  final IconData? icon;
  final double height;

  /// The button is at least this wide, and grows if its text needs more
  /// room (e.g. with a large system text size) instead of cutting it off.
  final double minWidth;
  final double horizontalPadding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final filled = variant == AppButtonVariant.filled;
    final foreground = switch (variant) {
      AppButtonVariant.filled => AppColors.onBrand,
      AppButtonVariant.outlined => AppColors.brand,
      AppButtonVariant.neutral => AppColors.ink,
    };

    return Pressable(
      onTap: onPressed,
      child: Container(
        height: height,
        constraints: BoxConstraints(minWidth: minWidth),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: filled ? AppColors.brand : AppColors.surface,
          border: switch (variant) {
            AppButtonVariant.filled => null,
            AppButtonVariant.outlined => Border.all(
              color: AppColors.brand,
              width: 1.5,
            ),
            AppButtonVariant.neutral => Border.all(
              color: AppColors.outline,
              width: 1.5,
            ),
          },
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.172,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
