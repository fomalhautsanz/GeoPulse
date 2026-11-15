import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/status_repository.dart';
import '../models/device_status.dart';

/// Holds the latest device reading for the whole app and refreshes it every
/// 2 seconds ("Live readings" in the motion spec: numbers just update).
///
/// It's a `ChangeNotifier`: when the reading changes it calls
/// `notifyListeners()`, and widgets wrapped in a `ListenableBuilder` rebuild.
class StatusController extends ChangeNotifier {
  StatusController({this.refreshEvery = const Duration(seconds: 2)});

  final Duration refreshEvery;

  DeviceStatus? _status;
  DeviceStatus? get status => _status;

  String? _error;
  String? get error => _error;

  /// Called when the risk level or online state changes (not on routine
  /// updates). The main shell uses it for notifications and the alert.
  void Function(DeviceStatus? before, DeviceStatus after)? onChange;

  Timer? _timer;
  bool _loading = false;

  void start() {
    load();
    _timer ??= Timer.periodic(refreshEvery, (_) => load());
  }

  /// Fetches a new reading. Skipped if one is already on its way, unless
  /// [force] is set.
  Future<void> load({bool force = false}) async {
    if (_loading && !force) return;
    _loading = true;
    try {
      final next = await getStatus();
      final before = _status;
      _status = next;
      _error = null;
      notifyListeners();
      if (before == null || before.level != next.level || before.online != next.online) {
        onChange?.call(before, next);
      }
    } catch (_) {
      _error = 'Couldn’t load status. Pull down to retry.';
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  /// Debug menu: switch the mock data's level and reload right away.
  Future<void> debugSetLevel(StatusLevel level) async {
    debugSetMockLevel(level);
    await load(force: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Makes one [StatusController] available to every screen below it:
/// `StatusScope.of(context)` finds it.
class StatusScope extends InheritedNotifier<StatusController> {
  const StatusScope({super.key, required StatusController controller, required super.child})
      : super(notifier: controller);

  /// The controller, and rebuild this widget whenever it changes.
  static StatusController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StatusScope>()!.notifier!;

  /// The controller without rebuilding (for button callbacks).
  static StatusController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StatusScope>()!.notifier!;
}
