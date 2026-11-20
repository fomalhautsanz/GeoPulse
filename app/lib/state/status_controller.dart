import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/status_repository.dart';
import '../models/device_status.dart';

/// Holds the latest device reading for the whole app and listens for live
/// Firebase changes.
///
/// It's a `ChangeNotifier`: when the reading changes it calls
/// `notifyListeners()`, and widgets wrapped in a `ListenableBuilder` rebuild.
class StatusController extends ChangeNotifier {
  StatusController();

  DeviceStatus? _status;
  DeviceStatus? get status => _status;

  String? _error;
  String? get error => _error;

  /// Called when the risk level or online state changes (not on routine
  /// updates). The main shell uses it for notifications and the alert.
  void Function(DeviceStatus? before, DeviceStatus after)? onChange;

  StreamSubscription<DeviceStatus>? _subscription;
  Timer? _freshnessTimer;
  bool _loading = false;
  bool _checkingFreshness = false;

  void start() {
    _subscription ??= watchStatus().listen(
      _accept,
      onError: (Object error, StackTrace stackTrace) {
        _error = 'Couldn’t load status. Pull down to retry.';
        notifyListeners();
      },
    );
    _freshnessTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshOnlineState(),
    );
  }

  Future<void> _refreshOnlineState() async {
    final current = _status;
    if (current == null || _checkingFreshness) return;
    _checkingFreshness = true;
    try {
      final online = await isStatusOnline(current.lastUpdate);
      if (_status?.lastUpdate == current.lastUpdate &&
          current.online != online) {
        _accept(current.copyWith(online: online));
      }
    } catch (error, stackTrace) {
      debugPrint('Could not check node connection: $error\n$stackTrace');
    } finally {
      _checkingFreshness = false;
    }
  }

  void _accept(DeviceStatus next) {
    final before = _status;
    _status = next;
    _error = null;
    notifyListeners();
    if (before == null ||
        before.level != next.level ||
        before.soilLevel != next.soilLevel ||
        before.online != next.online) {
      onChange?.call(before, next);
    }
  }

  /// Fetches a new reading. Skipped if one is already on its way, unless
  /// [force] is set.
  Future<void> load({bool force = false}) async {
    if (_loading && !force) return;
    _loading = true;
    try {
      final next = await getStatus();
      _accept(next);
    } catch (_) {
      _error = 'Couldn’t load status. Pull down to retry.';
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}

/// Makes one [StatusController] available to every screen below it:
/// `StatusScope.of(context)` finds it.
class StatusScope extends InheritedNotifier<StatusController> {
  const StatusScope({
    super.key,
    required StatusController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller, and rebuild this widget whenever it changes.
  static StatusController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StatusScope>()!.notifier!;

  /// The controller without rebuilding (for button callbacks).
  static StatusController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StatusScope>()!.notifier!;
}
