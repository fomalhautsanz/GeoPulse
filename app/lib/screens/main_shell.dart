import 'package:flutter/material.dart';

import '../data/status_repository.dart';
import '../models/device_status.dart';
import '../services/alert_sound_service.dart';
import '../models/sensor.dart';
import '../services/notification_service.dart';
import '../state/shell_scope.dart';
import '../state/status_controller.dart';
import '../widgets/fade_route.dart';
import 'critical_alert_screen.dart';
import 'history_screen.dart';
import 'map_screen.dart';
import 'notifications_screen.dart';
import 'sensors_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

/// The logged-in app: the five tabs (Map, History, Status, Sensors,
/// Settings) plus everything that works on every tab:
/// - keeps the live device reading ([StatusController]),
/// - shows notifications when the risk level changes,
/// - opens the full-screen Critical alert when the level becomes critical,
/// - keeps the unread notification badge current.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialTab = AppTab.status,
    this.controller,
  });

  final AppTab initialTab;

  /// Tests can pass their own controller; normally the shell makes one.
  final StatusController? controller;

  @override
  State<MainShell> createState() => _MainShellState();
}

// `implements ShellActions` promises this class has every method listed in
// ShellActions, so screens can call them through ShellScope.
class _MainShellState extends State<MainShell> implements ShellActions {
  late final StatusController _controller =
      widget.controller ?? StatusController();
  late AppTab _tab = widget.initialTab;
  final _sensor = ValueNotifier<SensorKind>(
    SensorKind.soil,
  ); // Sensors tab choice
  bool _alertOpen = false;
  bool _silencedOnPhone = false;
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _controller.onChange = _onStatusChange;
    _controller.start();
    NotificationService.onOpenCritical = openCriticalAlert;
    NotificationService.requestPermission();
    _refreshUnread();
  }

  @override
  void dispose() {
    if (NotificationService.onOpenCritical == openCriticalAlert) {
      NotificationService.onOpenCritical = null;
    }
    if (widget.controller == null) _controller.dispose();
    _sensor.dispose();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    try {
      final list = await getNotifications();
      if (mounted) setState(() => _hasUnread = list.any((n) => !n.read));
    } catch (error, stackTrace) {
      debugPrint('Could not refresh notification badge: $error\n$stackTrace');
    }
  }

  Future<void> _onStatusChange(DeviceStatus? before, DeviceStatus after) async {
    if (after.level != StatusLevel.critical) _silencedOnPhone = false;
    if (AlertSoundService.riskIncreased(before, after)) {
      await AlertSoundService.playAlert();
    }
    try {
      await NotificationService.notifyChange(before, after);
      await _refreshUnread();
    } catch (error, stackTrace) {
      debugPrint('Could not process device notification: $error\n$stackTrace');
    }
    // Becoming critical opens the full-screen alert once.
    if (after.level == StatusLevel.critical &&
        before?.level != StatusLevel.critical) {
      openCriticalAlert();
    }
  }

  @override
  void selectTab(AppTab tab, {SensorKind? sensor}) {
    if (sensor != null) _sensor.value = sensor;
    setState(() => _tab = tab);
  }

  @override
  Future<void> openNotifications() async {
    await Navigator.of(context)
        .push(fadeRoute<void>(context, const NotificationsScreen()));
    _refreshUnread();
  }

  @override
  Future<void> openCriticalAlert() async {
    final status = _controller.status;
    if (status == null || _alertOpen || !mounted) return;
    if (status.level != StatusLevel.critical) {
      // The alert has cleared; show the current status instead.
      selectTab(AppTab.status);
      return;
    }
    _alertOpen = true;
    await Navigator.of(context).push(
      criticalAlertRoute(
        context,
        status: status,
        silenced: _silencedOnPhone,
        onSilenced: () => setState(() => _silencedOnPhone = true),
      ),
    );
    _alertOpen = false; // the user closed it
  }

  @override
  Widget build(BuildContext context) {
    return StatusScope(
      controller: _controller,
      child: ShellScope(
        actions: this,
        currentTab: _tab,
        hasUnread: _hasUnread,
        child: Stack(
          children: [
            // IndexedStack shows one tab but keeps the others alive, so each
            // tab remembers its scroll position and choices.
            IndexedStack(
              index: _tab.index,
              children: [
                const MapScreen(),
                const HistoryScreen(),
                const StatusScreen(),
                SensorsScreen(selected: _sensor),
                const SettingsScreen(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
