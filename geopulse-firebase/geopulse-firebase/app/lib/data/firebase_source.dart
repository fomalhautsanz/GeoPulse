import 'package:firebase_database/firebase_database.dart';

import '../models/device_status.dart';
import '../models/history.dart';
import '../models/settings.dart';

// Reads and writes the ESP32 node's data in Firebase Realtime Database.
// Only `status_repository.dart` imports this file; screens never do.

const String firebaseNodeId = 'GP-01';

DatabaseReference _node() => FirebaseDatabase.instance.ref('geopulse/nodes/$firebaseNodeId');

double _d(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
int _i(Object? v, [int fallback = 0]) => v is num ? v.round() : fallback;

StatusLevel _level(Object? v) =>
    StatusLevel.values.firstWhere((l) => l.name == v, orElse: () => StatusLevel.stable);

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
  final event = await FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.first;
  return _offsetMs = _i(event.snapshot.value);
}

/// The latest reading the node wrote. Throws if the node never wrote one.
Future<DeviceStatus> fetchFirebaseStatus() async {
  final snap = await _node().child('status').get();
  final raw = snap.value;
  if (raw is! Map) throw StateError('No data from the node yet');
  final m = Map<String, dynamic>.from(raw);

  final last = DateTime.fromMillisecondsSinceEpoch(_i(m['ts']));
  final serverNow = DateTime.now().add(Duration(milliseconds: await _serverOffsetMs()));
  final online = serverNow.difference(last) < const Duration(seconds: 30);

  return DeviceStatus(
    nodeId: (m['nodeId'] as String?) ?? firebaseNodeId,
    level: _level(m['level']),
    soilMoisturePercent: _i(m['soil']),
    vibrationPerMin: _i(m['vibration']),
    tiltDegrees: _d(m['tilt']),
    online: online,
    batteryPercent: _i(m['battery'], 100), // not measured yet: shows 100
    gsmBars: _bars(_i(m['rssi'], -100)), // Wi-Fi signal, shown in the signal slot
    lastUpdate: last,
    sirenOn: false, // no siren in this build
    smsSent: 0,
    smsTotal: 0,
  );
}

/// The last 30 alerts the node logged, newest first.
Future<List<AlertEvent>> fetchFirebaseHistory() async {
  final snap = await _node().child('history').orderByKey().limitToLast(30).get();
  final events = <AlertEvent>[];
  for (final child in snap.children) {
    final raw = child.value;
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    final level = _level(m['level']);
    final label = level.name[0].toUpperCase() + level.name.substring(1);
    events.add(AlertEvent(
      kind: HazardKind.landslide,
      level: level,
      title: 'Landslide · $label',
      detail: 'Soil ${_i(m['soil'])}% · tilt ${_d(m['tilt']).toStringAsFixed(1)}° · '
          'vibration ${_i(m['vibration'])}/min',
      time: DateTime.fromMillisecondsSinceEpoch(_i(m['ts'])),
      outputs: const [
        AlertOutput(OutputKind.leds, 'LEDs'),
        AlertOutput(OutputKind.cloud, 'Cloud'),
      ],
    ));
  }
  return events.reversed.toList();
}

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
    sirenEnabled: (m['sirenEnabled'] as bool?) ?? false,
    ledsEnabled: (m['ledsEnabled'] as bool?) ?? true,
    autoSms: (m['autoSms'] as bool?) ?? false,
    combinedAlert: (m['combinedAlert'] as bool?) ?? true,
  );
}

/// "Save and sync to device": the node picks these up within ~30 seconds.
Future<void> saveFirebaseThresholds(Thresholds t) => _node().child('thresholds').set({
      'soilWatchPercent': t.soilWatchPercent,
      'soilCriticalPercent': t.soilCriticalPercent,
      'vibrationPerMin': t.vibrationPerMin,
      'sensitivity': t.sensitivity.name,
      'tiltDegrees': t.tiltDegrees,
      'sirenEnabled': t.sirenEnabled,
      'ledsEnabled': t.ledsEnabled,
      'autoSms': t.autoSms,
      'combinedAlert': t.combinedAlert,
    });
