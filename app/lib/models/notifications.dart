/// The kinds of notification GeoPulse sends ("Reference · Notification
/// types" in Figma).
enum NotificationType {
  critical,
  high,
  watch,
  backToStable,
  offline,
  lowBattery,
}

/// One entry in the in-app Notifications list.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime time;
  final bool read;

  AppNotification markedRead() => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    time: time,
    read: true,
  );
}

/// Which notifications the user wants. Critical alerts are always on.
class NotificationPrefs {
  const NotificationPrefs({
    required this.warnings,
    required this.backToStable,
    required this.deviceOnline,
    required this.lowBattery,
  });

  final bool warnings; // Watch and High
  final bool backToStable;
  final bool deviceOnline; // device offline / back online
  final bool lowBattery;

  bool get critical => true; // always on, can't be turned off

  NotificationPrefs copyWith({
    bool? warnings,
    bool? backToStable,
    bool? deviceOnline,
    bool? lowBattery,
  }) {
    return NotificationPrefs(
      warnings: warnings ?? this.warnings,
      backToStable: backToStable ?? this.backToStable,
      deviceOnline: deviceOnline ?? this.deviceOnline,
      lowBattery: lowBattery ?? this.lowBattery,
    );
  }

  /// Should a notification of this type be shown?
  bool allows(NotificationType type) => switch (type) {
    NotificationType.critical => true,
    NotificationType.high || NotificationType.watch => warnings,
    NotificationType.backToStable => backToStable,
    NotificationType.offline => deviceOnline,
    NotificationType.lowBattery => lowBattery,
  };
}

const defaultNotificationPrefs = NotificationPrefs(
  warnings: true,
  backToStable: true,
  deviceOnline: true,
  lowBattery: false,
);
