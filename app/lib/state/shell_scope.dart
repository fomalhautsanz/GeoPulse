import 'package:flutter/widgets.dart';

import '../models/sensor.dart';

/// The five tabs of the bottom navigation bar (as in the Figma nav).
///
/// An "enhanced enum": each value carries its own label and icon.
enum AppTab {
  map('Map', 'assets/icons/nav_map.png', 23),
  history('History', 'assets/icons/nav_history.png', 32.31),
  status('Status', 'assets/icons/nav_status.png', 31.5),
  sensors('Sensors', null, 28), // Material speed icon
  settings('Settings', 'assets/icons/nav_settings.png', 25);

  const AppTab(this.label, this.iconAsset, this.iconSize);

  final String label;
  final String? iconAsset;
  final double iconSize;
}

/// What any screen can ask the main app frame to do.
abstract class ShellActions {
  void selectTab(AppTab tab, {SensorKind? sensor});
  void openNotifications();
  void openCriticalAlert();
}

/// Shares the main frame's state with every screen inside it.
/// `ShellScope.maybeOf(context)` returns null outside the main app (e.g. on
/// Log in), so widgets can work in both places.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.actions,
    required this.currentTab,
    required this.hasUnread,
    required super.child,
  });

  final ShellActions actions;
  final AppTab currentTab;
  final bool hasUnread; // red dot on the bell

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope old) =>
      old.currentTab != currentTab || old.hasUnread != hasUnread || old.actions != actions;
}
