import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/status_repository.dart';
import '../models/device_status.dart';
import '../models/notifications.dart';
import '../theme/app_colors.dart';
import '../utils/alert_text.dart';
import '../utils/time_format.dart';

/// Real Android notifications, using the flutter_local_notifications package.
///
/// Four channels (Android lets people mute each one in system settings):
/// - Critical alerts: alarm sound, full-screen on the lock screen, opens the
///   Critical alert screen.
/// - Warnings (Watch and High): sound and vibration.
/// - Back to Stable: quiet.
/// - Device status: online and offline.
///
/// On web and in tests every call quietly does nothing.
class NotificationService {
  NotificationService._(); // only static members

  static final _plugin = FlutterLocalNotificationsPlugin();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// What tapping a critical notification does. The main shell sets this
  /// while it's on screen; [fallbackOpenCritical] is used otherwise.
  static VoidCallback? onOpenCritical;
  static VoidCallback? fallbackOpenCritical;

  static const _critical = AndroidNotificationChannel(
    'critical_alarm',
    'Critical alerts',
    description: 'Critical device status changes while the app is connected.',
    importance: Importance.max,
    bypassDnd: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );
  static const _warnings = AndroidNotificationChannel(
    'warnings',
    'Warnings (Watch and High)',
    description: 'Sound and vibration.',
    importance: Importance.high,
  );
  static const _stable = AndroidNotificationChannel(
    'back_to_stable',
    'Back to Stable',
    description: 'Quiet notification when risk clears.',
    importance: Importance.low,
  );
  static const _device = AndroidNotificationChannel(
    'device',
    'Device status',
    description: 'Device offline or back online.',
  );

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Call once at startup. Returns true if the app was opened by tapping a
  /// critical notification (or its full-screen alarm).
  static Future<bool> init() async {
    if (!isSupported) return false;
    try {
      return await _init();
    } catch (e) {
      debugPrint('Notification setup failed: $e');
      return false;
    }
  }

  static Future<bool> _init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );
    for (final channel in [_critical, _warnings, _stable, _device]) {
      await _android?.createNotificationChannel(channel);
    }
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return (launch?.didNotificationLaunchApp ?? false) &&
        launch?.notificationResponse?.payload == 'critical';
  }

  /// Android 13+ asks the user before an app may show notifications.
  static Future<void> requestPermission() => _safely(() async {
    await _android?.requestNotificationsPermission();
  });

  /// Android 14+ needs a separate permission for full-screen alarms. This
  /// opens the system setting if it isn't granted yet.
  static Future<void> requestFullScreenPermission() => _safely(() async {
    await _android?.requestFullScreenIntentPermission();
  });

  /// Runs a plugin call, but never lets a notification problem crash the
  /// app (e.g. in tests, where the Android side doesn't exist).
  static Future<void> _safely(Future<void> Function() call) async {
    if (!isSupported) return;
    try {
      await call();
    } catch (e) {
      debugPrint('Notification call failed: $e');
    }
  }

  static void _onTap(NotificationResponse response) {
    if (response.payload == 'critical') {
      (onOpenCritical ?? fallbackOpenCritical)?.call();
    }
  }

  /// Shows one notification of [type].
  static Future<void> show(NotificationType type, String title, String body) =>
      _safely(() => _show(type, title, body));

  static Future<void> _show(
    NotificationType type,
    String title,
    String body,
  ) async {
    final channel = switch (type) {
      NotificationType.critical => _critical,
      NotificationType.high || NotificationType.watch => _warnings,
      NotificationType.backToStable => _stable,
      NotificationType.offline || NotificationType.lowBattery => _device,
    };
    final critical = type == NotificationType.critical;
    await _plugin.show(
      id:
          100 +
          type.index, // one notification per type; a new one replaces the old
      title: title,
      body: body,
      payload: critical ? 'critical' : null,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: critical ? Priority.max : Priority.high,
          category: critical
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.status,
          fullScreenIntent: critical, // opens the alert over the lock screen
          channelBypassDnd: critical,
          audioAttributesUsage: critical
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          visibility:
              NotificationVisibility.public, // readable on the lock screen
          color: critical ? AppColors.criticalContainer : AppColors.brand,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  /// Turns a change in device status into a notification (if the user's
  /// settings allow it) and an entry in the in-app Notifications list.
  static Future<void> notifyChange(
    DeviceStatus? before,
    DeviceStatus after,
  ) async {
    if (before == null) return; // first reading after opening the app
    final message = _messageFor(before, after);
    if (message == null) return;
    final (type, title, body) = message;
    await addNotification(type: type, title: title, body: body);
    final prefs = await getNotificationPrefs();
    if (prefs.allows(type)) await show(type, title, body);
  }

  static (NotificationType, String, String)? _messageFor(
    DeviceStatus before,
    DeviceStatus after,
  ) {
    final node = 'Node ${after.nodeId}';
    if (before.online && !after.online) {
      return (
        NotificationType.offline,
        '$node is offline',
        'No live data since ${formatClock(after.lastUpdate)}. Readings are unavailable until it reconnects.',
      );
    }
    if (before.level == after.level) return null;
    return switch (after.level) {
      StatusLevel.critical => () {
        final (title, _) = criticalHeadline(after);
        final readings = after.adxlReady
            ? 'Soil ${after.soilMoisturePercent}%, tilt ${after.tiltDegrees.toStringAsFixed(1)}°, '
                  'vibration ${after.vibrationPerMin}/min'
            : 'Soil ${after.soilMoisturePercent}%; ADXL345 readings unavailable';
        return (
          NotificationType.critical,
          title,
          '$readings at $node. '
              'Move away from slopes and follow official evacuation instructions.',
        );
      }(),
      StatusLevel.high => (
        NotificationType.high,
        statusTitle(StatusLevel.high),
        'Soil ${after.soilMoisturePercent}% at $node. Get ready to evacuate.',
      ),
      StatusLevel.watch => (
        NotificationType.watch,
        statusTitle(StatusLevel.watch),
        'Soil moisture passed ${after.soilWatchThresholdPercent}%. Prepare your go-bag and route.',
      ),
      StatusLevel.stable => (
        NotificationType.backToStable,
        'Back to Stable',
        'All sensors are below warning levels again.',
      ),
    };
  }
}
