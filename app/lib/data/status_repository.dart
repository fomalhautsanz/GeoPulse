import '../models/device_status.dart';
import '../models/history.dart';
import '../models/notifications.dart';
import '../models/sensor.dart';
import '../models/settings.dart';
import 'firebase_source.dart';

Stream<DeviceStatus> watchStatus() => watchFirebaseStatus();

Future<DeviceStatus> getStatus() => fetchFirebaseStatus();

Future<bool> isStatusOnline(DateTime lastUpdate) =>
    isFirebaseStatusOnline(lastUpdate);

Future<List<AlertEvent>> getAlertHistory() => fetchFirebaseHistory();

Future<SensorHistory> getSensorHistory(SensorKind kind, SensorRange range) =>
    fetchFirebaseSensorHistory(kind, range);

Future<SensorDetails> getSensorDetails() => fetchFirebaseSensorDetails();

Future<DeviceInfo> getDeviceInfo() => fetchFirebaseDeviceInfo();

Future<Thresholds> getThresholds() async {
  return await fetchFirebaseThresholds() ?? defaultThresholds;
}

/// Sends new thresholds to the device ("Save and sync to device").
Future<void> saveThresholds(Thresholds thresholds) =>
    saveFirebaseThresholds(thresholds);

Future<List<AlertContact>> getContacts() => fetchFirebaseContacts();

Future<List<AppNotification>> getNotifications() =>
    fetchFirebaseNotifications();

Future<void> markNotificationRead(String id) =>
    markFirebaseNotificationRead(id);

Future<void> markAllNotificationsRead() => markAllFirebaseNotificationsRead();

/// Adds a new entry to the in-app list (newest first).
Future<void> addNotification({
  required NotificationType type,
  required String title,
  required String body,
}) => addFirebaseNotification(type: type, title: title, body: body);

Future<NotificationPrefs> getNotificationPrefs() =>
    fetchFirebaseNotificationPrefs();

Future<void> saveNotificationPrefs(NotificationPrefs prefs) =>
    saveFirebaseNotificationPrefs(prefs);
