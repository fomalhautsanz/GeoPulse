import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/shell_scope.dart';
import '../theme/app_colors.dart';
import 'bottom_nav.dart';
import 'top_bar.dart';

export '../state/shell_scope.dart' show AppTab;

/// The frame every main tab shares: [TopBar] at the top, [BottomNav] at
/// the bottom, and the screen's own [body] in between.
///
/// Inside the main app, tab taps and the bell go to the main shell
/// automatically; pass [onTabSelected] / [onNotificationsTap] to override.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.currentTab,
    required this.body,
    this.onTabSelected,
    this.onNotificationsTap,
    this.overlay,
    this.background,
  });

  final String title;
  final AppTab currentTab;
  final Widget body;
  final ValueChanged<AppTab>? onTabSelected;
  final VoidCallback? onNotificationsTap;

  /// Optional widget drawn on top of [body].
  final Widget? overlay;

  /// Optional decoration drawn behind everything, in a Stack that starts at
  /// the top of the screen, e.g. the Status arch. Can be a `Positioned`.
  final Widget? background;

  static final _navItems = [
    for (final tab in AppTab.values)
      BottomNavItem(
        label: tab.label,
        iconAsset: tab.iconAsset,
        icon: tab == AppTab.sensors ? Icons.speed_rounded : null,
        iconSize: tab.iconSize,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    final shell = ShellScope.maybeOf(context);
    final overlay = this.overlay;

    return Scaffold(
      backgroundColor: AppColors.surface, // pure white #FFFFFF
      // The Stack starts at the very top of the screen, so a background's
      // `top:` is measured from there; the Column draws on top of it.
      body: Stack(
        children: [
          ?background, // `?` = only added when not null
          Column(
            children: [
              Padding(
                // 61 px from the top in Figma, or below the system status bar.
                padding: EdgeInsets.fromLTRB(33, math.max(61, insets.top), 33, 0),
                child: TopBar(
                  title: title,
                  showUnreadDot: shell?.hasUnread ?? false,
                  onNotificationsTap: onNotificationsTap ?? shell?.actions.openNotifications,
                ),
              ),
              Expanded(
                child: overlay == null ? body : Stack(children: [body, overlay]),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(13, 0, 13, math.max(14, insets.bottom)),
                child: BottomNav(
                  items: _navItems,
                  selectedIndex: currentTab.index,
                  onSelected: (i) {
                    final tab = AppTab.values[i];
                    final handler = onTabSelected;
                    if (handler != null) {
                      handler(tab);
                    } else {
                      shell?.actions.selectTab(tab);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
