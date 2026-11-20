import '../models/device_status.dart';
import '../models/history.dart';
import '../models/notifications.dart';
import '../models/sensor.dart';
import '../models/settings.dart';
import 'firebase_source.dart';
import 'mock_data.dart';

// The single door screens use to get device data.
//
// Every function returns a `Future`, a value that arrives later, just like a
// real network call would. When the backend exists, replace the bodies with
// API requests and keep the same signatures; no screen needs to change.

const _latency = Duration(milliseconds: 300); // pretend network delay

/// true = read the real ESP32 node through Firebase; false = sample data.
/// Flip it to false to demo the UI without hardware or internet.
const bool useFirebase = true;

Future<DeviceStatus> getStatus() async {
  if (useFirebase) return fetchFirebaseStatus();
  await Future<void>.delayed(_latency);
  return currentMockStatus();
}

Future<List<AlertEvent>> getAlertHistory() async {
  if (useFirebase) return fetchFirebaseHistory();
  await Future<void>.delayed(_latency);
  return mockAlertHistory();
}

Future<SensorHistory> getSensorHistory(SensorKind kind, SensorRange range) async {
  await Future<void>.delayed(_latency);
  return mockSensorHistory(kind, range, currentMockStatus());
}

Future<SensorDetails> getSensorDetails() async {
  await Future<void>.delayed(_latency);
  return mockSensorDetails(currentMockStatus());
}

Future<DeviceInfo> getDeviceInfo() async {
  await Future<void>.delayed(_latency);
  return mockDeviceInfo();
}

Future<Thresholds> getThresholds() async {
  if (useFirebase) {
    final saved = await fetchFirebaseThresholds();
    if (saved != null) return saved;
  }
  await Future<void>.delayed(_latency);
  return mockThresholds();
}

/// Sends new thresholds to the device ("Save and sync to device").
Future<void> saveThresholds(Thresholds thresholds) async {
  if (useFirebase) await saveFirebaseThresholds(thresholds);
  await Future<void>.delayed(_latency);
  saveMockThresholds(thresholds);
}

Future<List<AlertContact>> getContacts() async {
  await Future<void>.delayed(_latency);
  return mockContacts;
}

/// The SMS text the device sends at Critical.
Future<String> getSmsPreview() async => mockSmsPreview;

Future<void> sendTestSms() async => Future<void>.delayed(_latency);

Future<void> testSiren() async => Future<void>.delayed(_latency);

Future<List<AppNotification>> getNotifications() async {
  await Future<void>.delayed(_latency);
  return mockNotifications();
}

Future<void> markNotificationRead(int id) async {
  setMockNotifications([
    for (final n in mockNotifications()) n.id == id ? n.markedRead() : n,
  ]);
}

Future<void> markAllNotificationsRead() async {
  setMockNotifications([for (final n in mockNotifications()) n.markedRead()]);
}

/// Adds a new entry to the in-app list (newest first).
Future<void> addNotification({
  required NotificationType type,
  required String title,
  required String body,
}) async {
  final list = mockNotifications();
  final nextId = list.fold<int>(0, (max, n) => n.id > max ? n.id : max) + 1;
  setMockNotifications([
    AppNotification(id: nextId, type: type, title: title, body: body, time: DateTime.now()),
    ...list,
  ]);
}

Future<NotificationPrefs> getNotificationPrefs() async => mockNotificationPrefs();

Future<void> saveNotificationPrefs(NotificationPrefs prefs) async => saveMockNotificationPrefs(prefs);

/// TEMPORARY, debug builds only: serve sample data at this risk level.
/// Delete together with the mock data.
void debugSetMockLevel(StatusLevel level) => setMockLevel(level);

/// TEMPORARY, debug builds only: step to the next sample level.
StatusLevel debugCycleMockLevel() => cycleMockLevel();
