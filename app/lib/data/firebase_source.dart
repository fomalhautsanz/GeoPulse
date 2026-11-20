import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/device_status.dart';
import '../models/history.dart';
import '../models/notifications.dart';
import '../models/sensor.dart';
import '../models/settings.dart';
import '../models/user_profile.dart';

// Reads and writes the ESP32 node's data in Firebase Realtime Database.
// Only `status_repository.dart` imports this file; screens never do.

const String firebaseNodeId = 'GP-01';

DatabaseReference _node() =>
    FirebaseDatabase.instance.ref('geopulse/nodes/$firebaseNodeId');

double _d(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;
int _i(Object? v, [int fallback = 0]) => v is num ? v.round() : fallback;

StatusLevel _level(Object? v) => StatusLevel.values.firstWhere(
  (l) => l.name == v,
  orElse: () => throw FormatException('Unknown status level: $v'),
);

/// Wi-Fi signal strength (dBm) to 0-4 bars.
int _bars(int rssi) {
  if (rssi >= -60) return 4;
  if (rssi >= -70) return 3;
  if (rssi >= -80) return 2;
  if (rssi >= -90) return 1;
  return 0;
}

// Difference between this phone's clock and Firebase's, so "online" doesn't
// depend on the phone's time being exact.
int? _offsetMs;
Future<int> _serverOffsetMs() async {
  final cached = _offsetMs;
  if (cached != null) return cached;
  final event = await FirebaseDatabase.instance
      .ref('.info/serverTimeOffset')
      .onValue
      .first;
  return _offsetMs = _i(event.snapshot.value);
}

Future<bool> _isStatusOnline(DateTime lastUpdate) async {
  final serverNow = DateTime.now().add(
    Duration(milliseconds: await _serverOffsetMs()),
  );
  return serverNow.difference(lastUpdate) < const Duration(seconds: 30);
}

Future<bool> isFirebaseStatusOnline(DateTime lastUpdate) =>
    _isStatusOnline(lastUpdate);

Future<DeviceStatus> _statusFromValue(Object? raw) async {
  if (raw is! Map) throw StateError('No data from the node yet');
  final m = Map<String, dynamic>.from(raw);

  final timestamp = _i(m['ts']);
  if (timestamp <= 0) {
    throw const FormatException('Node status is missing its timestamp');
  }
  if (m['soil'] is! num) {
    throw const FormatException('Node status is missing the soil reading');
  }
  final adxlReady = m['adxlReady'] == true;
  if (adxlReady &&
      (m['vibration'] is! num ||
          m['tilt'] is! num ||
          m['tiltX'] is! num ||
          m['tiltY'] is! num)) {
    throw const FormatException('Node status is missing ADXL345 readings');
  }
  final last = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final online = await _isStatusOnline(last);

  return DeviceStatus(
    nodeId: (m['nodeId'] as String?) ?? firebaseNodeId,
    level: _level(m['level']),
    soilMoisturePercent: _i(m['soil']),
    vibrationPerMin: _i(m['vibration']),
    tiltDegrees: _d(m['tilt']),
    tiltX: m['tiltX'] is num ? (m['tiltX'] as num).toDouble() : null,
    tiltY: m['tiltY'] is num ? (m['tiltY'] as num).toDouble() : null,
    sustainedVibration: m['sustainedVibration'] == true,
    adxlReady: adxlReady,
    soilWatchThresholdPercent: _i(
      m['soilWatchPercent'],
      DeviceStatus.soilWarningPercent,
    ),
    soilCriticalThresholdPercent: _i(
      m['soilCriticalPercent'],
      DeviceStatus.soilCriticalPercent,
    ),
    vibrationThresholdPerMin: _i(
      m['vibrationThresholdPerMin'],
      DeviceStatus.vibrationLimitPerMin,
    ),
    tiltThresholdDegrees: _d(
      m['tiltThresholdDegrees'],
      DeviceStatus.tiltLimitDegrees,
    ),
    online: online,
    batteryPercent: m['battery'] is num ? _i(m['battery']) : null,
    wifiBars: m['rssi'] is num ? _bars(_i(m['rssi'])) : null,
    lastUpdate: last,
  );
}

/// The latest reading the node wrote. Throws if the node never wrote one.
Future<DeviceStatus> fetchFirebaseStatus() async {
  final snap = await _node().child('status').get();
  return _statusFromValue(snap.value);
}

/// Pushes status changes to the UI as soon as Firebase receives them.
Stream<DeviceStatus> watchFirebaseStatus() => _node()
    .child('status')
    .onValue
    .asyncMap((event) => _statusFromValue(event.snapshot.value));

Future<List<Map<String, dynamic>>> _readingsSince(DateTime since) async {
  final snap = await _node()
      .child('readings')
      .orderByChild('ts')
      .startAt(since.millisecondsSinceEpoch)
      .get();
  final readings = <Map<String, dynamic>>[];
  for (final child in snap.children) {
    final raw = child.value;
    if (raw is Map) readings.add(Map<String, dynamic>.from(raw));
  }
  return readings;
}

double _sensorValue(SensorKind kind, Map<String, dynamic> reading) {
  final field = switch (kind) {
    SensorKind.soil => 'soil',
    SensorKind.vibration => 'vibration',
    SensorKind.tilt => 'tilt',
  };
  final value = reading[field];
  if (value is! num) {
    throw FormatException('Sensor history entry is missing $field');
  }
  return value.toDouble();
}

Future<SensorHistory> fetchFirebaseSensorHistory(
  SensorKind kind,
  SensorRange range,
) async {
  final serverNow = DateTime.now().add(
    Duration(milliseconds: await _serverOffsetMs()),
  );
  final since = serverNow.subtract(range.span);
  final readings = await _readingsSince(since);
  final usableReadings = readings.where(
    (reading) => kind == SensorKind.soil || reading['adxlReady'] == true,
  );
  final points = usableReadings
      .map((reading) => _sensorValue(kind, reading))
      .toList();

  if (points.isEmpty) {
    final status = await fetchFirebaseStatus();
    if ((kind == SensorKind.soil || status.adxlReady) &&
        !status.lastUpdate.isBefore(since)) {
      points.add(switch (kind) {
        SensorKind.soil => status.soilMoisturePercent.toDouble(),
        SensorKind.vibration => status.vibrationPerMin.toDouble(),
        SensorKind.tilt => status.tiltDegrees,
      });
    }
  }

  return SensorHistory(kind: kind, range: range, points: points);
}

Future<SensorDetails> fetchFirebaseSensorDetails() async {
  final recentSnapshot = await _node()
      .child('readings')
      .orderByChild('ts')
      .limitToLast(12)
      .get();
  final readings = <Map<String, dynamic>>[];
  for (final child in recentSnapshot.children) {
    final raw = child.value;
    if (raw is Map) readings.add(Map<String, dynamic>.from(raw));
  }
  final statusSnapshot = await _node().child('status').get();
  final rawStatus = statusSnapshot.value;
  if (rawStatus is! Map) throw StateError('No data from the node yet');
  final status = Map<String, dynamic>.from(rawStatus);
  if (status['adxlReady'] != true) {
    throw StateError('ADXL345 is not detected by the node');
  }
  final statusTimestamp = _i(status['ts']);
  if (statusTimestamp <= 0 ||
      status['tiltX'] is! num ||
      status['tiltY'] is! num ||
      status['vibration'] is! num) {
    throw const FormatException('Node status is missing ADXL345 details');
  }
  final calibratedTimestamp = _i(status['calibratedAt'], statusTimestamp);
  final peakTimestamp = _i(status['vibrationPeakAt'], statusTimestamp);

  final recentVibration = readings
      .where((reading) => reading['adxlReady'] == true)
      .map((reading) => _i(reading['vibration']))
      .toList();
  if (recentVibration.isEmpty) recentVibration.add(_i(status['vibration']));

  return SensorDetails(
    tiltX: _d(status['tiltX']),
    tiltY: _d(status['tiltY']),
    vibrationPeakPerMin: _i(
      status['vibrationPeakPerMin'],
      _i(status['vibration']),
    ),
    vibrationPeakTime: DateTime.fromMillisecondsSinceEpoch(
      peakTimestamp > 0 ? peakTimestamp : statusTimestamp,
    ),
    recentVibration: recentVibration,
    calibratedOn: DateTime.fromMillisecondsSinceEpoch(
      calibratedTimestamp > 0 ? calibratedTimestamp : statusTimestamp,
    ),
    // The node publishes live status every second; history remains sampled slower.
    readEvery: const Duration(seconds: 1),
  );
}

/// The last 30 alerts the node logged, newest first.
Future<List<AlertEvent>> fetchFirebaseHistory() async {
  final snap = await _node()
      .child('history')
      .orderByKey()
      .limitToLast(30)
      .get();
  final events = <AlertEvent>[];
  for (final child in snap.children) {
    final raw = child.value;
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    if (m['soil'] is! num) {
      throw const FormatException(
        'Alert history entry is missing the soil reading',
      );
    }
    if (m['adxlReady'] == true &&
        (m['tilt'] is! num || m['vibration'] is! num)) {
      throw const FormatException(
        'Alert history entry is missing ADXL345 readings',
      );
    }
    final level = _level(m['level']);
    final kind = HazardKind.values.firstWhere(
      (value) => value.name == m['kind'],
      orElse: () => throw FormatException('Unknown alert kind: ${m['kind']}'),
    );
    final label = level.name[0].toUpperCase() + level.name.substring(1);
    final timestamp = _i(m['ts']);
    if (timestamp <= 0) {
      throw const FormatException(
        'Alert history entry is missing its timestamp',
      );
    }
    final adxlReady = m['adxlReady'] == true;
    final detail = adxlReady
        ? 'Soil ${_i(m['soil'])}% · tilt ${_d(m['tilt']).toStringAsFixed(1)}° · '
              'vibration ${_i(m['vibration'])}/min'
        : 'Soil ${_i(m['soil'])}% · ADXL345 unavailable';
    final rawOutputs = m['outputs'];
    final outputs = <AlertOutput>[];
    if (rawOutputs is List) {
      for (final rawOutput in rawOutputs) {
        if (rawOutput is! Map) continue;
        final output = Map<String, dynamic>.from(rawOutput);
        final outputKind = OutputKind.values.firstWhere(
          (value) => value.name == output['kind'],
          orElse: () =>
              throw FormatException('Unknown alert output: ${output['kind']}'),
        );
        outputs.add(
          AlertOutput(
            outputKind,
            (output['label'] as String?) ?? outputKind.name,
            ok: (output['ok'] as bool?) ?? true,
          ),
        );
      }
    }
    events.add(
      AlertEvent(
        kind: kind,
        level: level,
        title: '${kind.label} · $label',
        detail: detail,
        time: DateTime.fromMillisecondsSinceEpoch(timestamp),
        outputs: outputs,
      ),
    );
  }
  return events.reversed.toList();
}

Future<DeviceInfo> fetchFirebaseDeviceInfo() async {
  final raw = (await _node().child('status').get()).value;
  if (raw is! Map) throw StateError('No device information reported yet');
  final status = Map<String, dynamic>.from(raw);
  return DeviceInfo(
    name:
        (status['name'] as String?) ??
        'GeoPulse Node ${status['nodeId'] ?? firebaseNodeId}',
    board: (status['board'] as String?) ?? 'Not reported',
    firmware: (status['firmware'] as String?) ?? 'Not reported',
  );
}

Future<List<AlertContact>> fetchFirebaseContacts() async {
  final raw = (await _node().child('contacts').get()).value;
  if (raw is! Map) return [];
  final contacts = <AlertContact>[];
  for (final value in raw.values) {
    if (value is! Map) continue;
    final contact = Map<String, dynamic>.from(value);
    final roleName = contact['role'];
    final alertLevelName = contact['alertLevel'];
    contacts.add(
      AlertContact(
        name: contact['name'] as String,
        phone: contact['phone'] as String,
        role: UserRole.values.firstWhere((role) => role.name == roleName),
        alertLevel: ContactAlertLevel.values.firstWhere(
          (level) => level.name == alertLevelName,
        ),
      ),
    );
  }
  return contacts;
}

NotificationType _notificationType(Object? value) =>
    NotificationType.values.firstWhere((type) => type.name == value);

Future<List<AppNotification>> fetchFirebaseNotifications() async {
  final snap = await _node()
      .child('notifications')
      .orderByKey()
      .limitToLast(100)
      .get();
  final notifications = <AppNotification>[];
  for (final child in snap.children) {
    final raw = child.value;
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    final key = child.key;
    if (key == null) {
      throw StateError('Notification is missing its database key');
    }
    final timestamp = _i(item['time']);
    if (timestamp <= 0) {
      throw const FormatException('Notification is missing its timestamp');
    }
    notifications.add(
      AppNotification(
        id: key,
        type: _notificationType(item['type']),
        title: item['title'] as String,
        body: item['body'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(timestamp),
        read: (item['read'] as bool?) ?? false,
      ),
    );
  }
  notifications.sort((a, b) => b.time.compareTo(a.time));
  return notifications;
}

Future<void> addFirebaseNotification({
  required NotificationType type,
  required String title,
  required String body,
}) async {
  final reference = _node().child('notifications').push();
  if (reference.key == null) {
    throw StateError('Could not allocate a notification key');
  }
  await reference.set({
    'type': type.name,
    'title': title,
    'body': body,
    'time': DateTime.now().millisecondsSinceEpoch,
    'read': false,
  });
}

Future<void> markFirebaseNotificationRead(String id) =>
    _node().child('notifications/$id/read').set(true);

Future<void> markAllFirebaseNotificationsRead() async {
  final reference = _node().child('notifications');
  final snap = await reference.get();
  final updates = <String, Object?>{};
  for (final child in snap.children) {
    if (child.key != null) updates['${child.key}/read'] = true;
  }
  if (updates.isNotEmpty) await reference.update(updates);
}

DatabaseReference _notificationPrefs() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw StateError('Sign in before loading notification preferences');
  }
  return FirebaseDatabase.instance.ref('geopulse/users/$uid/notificationPrefs');
}

Future<NotificationPrefs> fetchFirebaseNotificationPrefs() async {
  final raw = (await _notificationPrefs().get()).value;
  if (raw is! Map) return defaultNotificationPrefs;
  final prefs = Map<String, dynamic>.from(raw);
  return NotificationPrefs(
    warnings: (prefs['warnings'] as bool?) ?? defaultNotificationPrefs.warnings,
    backToStable:
        (prefs['backToStable'] as bool?) ??
        defaultNotificationPrefs.backToStable,
    deviceOnline:
        (prefs['deviceOnline'] as bool?) ??
        defaultNotificationPrefs.deviceOnline,
    lowBattery:
        (prefs['lowBattery'] as bool?) ?? defaultNotificationPrefs.lowBattery,
  );
}

Future<void> saveFirebaseNotificationPrefs(NotificationPrefs prefs) =>
    _notificationPrefs().set({
      'warnings': prefs.warnings,
      'backToStable': prefs.backToStable,
      'deviceOnline': prefs.deviceOnline,
      'lowBattery': prefs.lowBattery,
    });

/// Thresholds saved in the cloud, or null if none were saved yet.
Future<Thresholds?> fetchFirebaseThresholds() async {
  final raw = (await _node().child('thresholds').get()).value;
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  return Thresholds(
    soilWatchPercent: _i(m['soilWatchPercent'], 70),
    soilCriticalPercent: _i(m['soilCriticalPercent'], 90),
    vibrationPerMin: _i(m['vibrationPerMin'], 5),
    sensitivity: VibrationSensitivity.values.firstWhere(
      (s) => s.name == m['sensitivity'],
      orElse: () => VibrationSensitivity.medium,
    ),
    tiltDegrees: _d(m['tiltDegrees'], 2.0),
  );
}

/// "Save and sync to device": the node picks these up within ~30 seconds.
Future<void> saveFirebaseThresholds(Thresholds t) =>
    _node().child('thresholds').set({
      'soilWatchPercent': t.soilWatchPercent,
      'soilCriticalPercent': t.soilCriticalPercent,
      'vibrationPerMin': t.vibrationPerMin,
      'sensitivity': t.sensitivity.name,
      'tiltDegrees': t.tiltDegrees,
    });
