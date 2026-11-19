import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// The app header: the page title in a red pill in the middle, with either
/// the logo or a back chevron on the left, and an optional bell on the right.
///
/// It's a `StatelessWidget` because it only draws what it's given and keeps
/// no state of its own.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onNotificationsTap,
    this.showNotifications = true,
    this.showUnreadDot = false,
  });

  /// Small red dot on the bell when there are unread notifications.
  final bool showUnreadDot;

  final String title;

  /// If set, a back chevron replaces the logo (sub-screens like Log in).
  final VoidCallback? onBack;

  /// Called when the bell is tapped. `VoidCallback` = a function with no
  /// arguments and no return value. Nullable (`?`) so it's optional.
  final VoidCallback? onNotificationsTap;
  final bool showNotifications;

  @override
  Widget build(BuildContext context) {
    final back = onBack;

    return SizedBox(
      height: 33,
      // A Stack layers its children; this keeps the pill centred on screen
      // no matter what's on the left and right.
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: back == null
                ? SvgPicture.asset(
                    'assets/icons/logo.svg',
                    width: 29,
                    height: 29,
                    semanticsLabel: 'GeoPulse',
                  )
                : Pressable(
                    onTap: back,
                    semanticLabel: 'Back',
                    child: const SizedBox(
                      width: 33,
                      height: 33,
                      child: Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.ink),
                    ),
                  ),
          ),
          Container(
            height: 33,
            // At least 110 wide like Figma; wider for long titles.
            constraints: const BoxConstraints(minWidth: 110, maxWidth: 230),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(14.5),
            ),
            // widthFactor 1 = only as wide as the text (not the full 230),
            // while still centring it vertically.
            child: Center(
              widthFactor: 1,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.onBrand,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (showNotifications)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Pressable(
                  onTap: onNotificationsTap,
                  semanticLabel: showUnreadDot ? 'Notifications, unread' : 'Notifications',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.asset(
                        'assets/icons/bell.png',
                        width: 26,
                        height: 26,
                        // The PNG is a shape mask; this paints it brand red.
                        color: AppColors.brand,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                      if (showUnreadDot)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.unreadDot,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
