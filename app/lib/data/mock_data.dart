import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/device_status.dart';
import '../models/history.dart';
import '../models/notifications.dart';
import '../models/sensor.dart';
import '../models/settings.dart';
import '../models/user_profile.dart';

// All hardcoded sample data lives in this file. Screens never import it:
// they go through `status_repository.dart` / `auth_repository.dart`.
// [Brackets] are placeholders, as in the Figma file.

/// The sample account used when logging in.
const mockUser = UserProfile(
  name: '[Your name]',
  phone: '+63 9XX XXX XXXX',
  role: UserRole.resident,
  barangay: '[Barangay name]',
);

// ---------------------------------------------------------------------------
// Device status
// ---------------------------------------------------------------------------

/// One snapshot for each alert level, matching the Figma Status frames.
///
/// `tick` nudges the soil reading by ±1 so a routine refresh shows a slightly
/// different number at the same level, like a real live update.
DeviceStatus mockStatus(StatusLevel level, {int tick = 0}) {
  final now = DateTime.now();
  final wobble = const [0, 1, 0, -1][tick % 4];

  // A `switch` expression returns a value for each case.
  return switch (level) {
    StatusLevel.stable => DeviceStatus(
        nodeId: 'GP‑01',
        level: StatusLevel.stable,
        soilMoisturePercent: 49 + wobble,
        vibrationPerMin: 0,
        tiltDegrees: 0.4,
        online: true,
        batteryPercent: 82,
        gsmBars: 3,
        lastUpdate: now.subtract(const Duration(seconds: 8)),
        sirenOn: false,
        smsSent: 0,
        smsTotal: 4,
      ),
    // "Status · Watch (node offline)": no new data, so no wobble.
    StatusLevel.watch => DeviceStatus(
        nodeId: 'GP‑01',
        level: StatusLevel.watch,
        soilMoisturePercent: 74,
        vibrationPerMin: 1,
        tiltDegrees: 0.9,
        online: false,
        batteryPercent: 80,
        gsmBars: 3,
        lastUpdate: now.subtract(const Duration(minutes: 44)),
        sirenOn: false,
        smsSent: 4,
        smsTotal: 4,
      ),
    StatusLevel.high => DeviceStatus(
        nodeId: 'GP‑01',
        level: StatusLevel.high,
        soilMoisturePercent: 84 + wobble,
        vibrationPerMin: 2,
        tiltDegrees: 1.1,
        online: true,
        batteryPercent: 76,
        gsmBars: 2,
        lastUpdate: now.subtract(const Duration(seconds: 4)),
        sirenOn: true,
        smsSent: 4,
        smsTotal: 4,
      ),
    StatusLevel.critical => DeviceStatus(
        nodeId: 'GP‑01',
        level: StatusLevel.critical,
        soilMoisturePercent: 93 + wobble,
        vibrationPerMin: 14,
        tiltDegrees: 3.8,
        online: true,
        batteryPercent: 74,
        gsmBars: 2,
        lastUpdate: now.subtract(const Duration(minutes: 2)),
        sirenOn: true,
        smsSent: 4,
        smsTotal: 4,
      ),
  };
}

// The sample currently being served, and how many times it was read.
// The leading underscore makes these private to this file.
StatusLevel _level = StatusLevel.stable;
int _tick = 0;

/// The current sample, slightly different on every call.
DeviceStatus currentMockStatus() => mockStatus(_level, tick: _tick++);

/// Debug menu: serve this level from now on.
void setMockLevel(StatusLevel level) => _level = level;

/// Moves the sample to the next level: stable → watch → high → critical →
/// stable…, and returns the new level.
StatusLevel cycleMockLevel() {
  _level = StatusLevel.values[(_level.index + 1) % StatusLevel.values.length];
  return _level;
}

// ---------------------------------------------------------------------------
// History, sensors, settings, notifications
// ---------------------------------------------------------------------------

DateTime _todayAt(int hour, int minute, {int daysAgo = 0}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
}

List<AlertEvent> mockAlertHistory() {
  final now = DateTime.now();
  return [
    AlertEvent(
      kind: HazardKind.combined,
      level: StatusLevel.critical,
      title: 'Combined Hazard · Critical',
      detail: 'Soil 93% · vibration 14/min · tilt 3.8°',
      time: now.subtract(const Duration(minutes: 2)),
      outputs: const [
        AlertOutput(OutputKind.siren, 'Siren'),
        AlertOutput(OutputKind.sms, 'SMS 4/4'),
        AlertOutput(OutputKind.cloud, 'Cloud'),
      ],
    ),
    AlertEvent(
      kind: HazardKind.landslide,
      level: StatusLevel.watch,
      title: 'Landslide Watch',
      detail: 'Soil passed the 70% warning level',
      time: now.subtract(const Duration(minutes: 47)),
      outputs: const [
        AlertOutput(OutputKind.buzzer, 'Buzzer'),
        AlertOutput(OutputKind.sms, 'SMS 4/4'),
        AlertOutput(OutputKind.cloud, 'Cloud queued', ok: false),
      ],
    ),
    AlertEvent(
      kind: HazardKind.earthquake,
      level: StatusLevel.high,
      title: 'Ground Vibration · High',
      detail: '9 events/min for 40 seconds',
      time: _todayAt(15, 15, daysAgo: 1),
      outputs: const [
        AlertOutput(OutputKind.buzzer, 'Buzzer'),
        AlertOutput(OutputKind.sms, 'SMS 2/4', ok: false),
      ],
    ),
    AlertEvent(
      kind: HazardKind.test,
      level: null,
      title: 'Alarm test',
      detail: 'Run by [Your name] · all outputs OK',
      time: _todayAt(9, 0, daysAgo: 1),
      outputs: const [
        AlertOutput(OutputKind.siren, 'Siren'),
        AlertOutput(OutputKind.leds, 'LEDs'),
      ],
    ),
  ];
}

/// A believable series ending at the current reading.
SensorHistory mockSensorHistory(SensorKind kind, SensorRange range, DeviceStatus status) {
  const counts = {SensorRange.hour: 30, SensorRange.sixHours: 36, SensorRange.day: 48, SensorRange.week: 42};
  final n = counts[range]!;
  final points = <double>[];
  for (var i = 0; i < n; i++) {
    final t = i / (n - 1); // 0 = oldest, 1 = now
    final rise = t * t * (3 - 2 * t); // smooth S-curve
    final wiggle = math.sin(i * 1.7) * 0.5 + math.sin(i * 0.6) * 0.4;
    points.add(switch (kind) {
      SensorKind.soil => status.soilMoisturePercent - 12 + 12 * rise + wiggle * 0.8,
      SensorKind.vibration => math.max(0, status.vibrationPerMin * rise + (i % 11 == 7 ? 7 : 0) + wiggle.abs()),
      SensorKind.tilt => math.max(0, status.tiltDegrees - 0.3 + 0.3 * rise + wiggle * 0.03),
    });
  }
  points[n - 1] = switch (kind) {
    SensorKind.soil => status.soilMoisturePercent.toDouble(),
    SensorKind.vibration => status.vibrationPerMin.toDouble(),
    SensorKind.tilt => status.tiltDegrees,
  };
  return SensorHistory(kind: kind, range: range, points: points);
}

SensorDetails mockSensorDetails(DeviceStatus status) => SensorDetails(
      tiltX: double.parse((status.tiltDegrees * 0.66).toStringAsFixed(1)),
      tiltY: double.parse((status.tiltDegrees * 0.78).toStringAsFixed(1)),
      vibrationPeakPerMin: 9,
      vibrationPeakTime: _todayAt(15, 15, daysAgo: 1),
      recentVibration: [1, 1, 0, 1, 2, 1, 9, 2, 1, 0, 1, 1, status.vibrationPerMin],
      calibratedOn: DateTime(DateTime.now().year, 10, 28),
      readEvery: const Duration(seconds: 2),
    );

DeviceInfo mockDeviceInfo() => DeviceInfo(
      name: 'GeoPulse Node GP‑01',
      board: 'ESP32',
      firmware: '[v0.1]',
      lastSirenTest: _todayAt(9, 0, daysAgo: 1),
    );

Thresholds _thresholds = const Thresholds(
  soilWatchPercent: 70,
  soilCriticalPercent: 90,
  vibrationPerMin: 5,
  sensitivity: VibrationSensitivity.medium,
  tiltDegrees: 2.0,
  sirenEnabled: true,
  ledsEnabled: true,
  autoSms: true,
  combinedAlert: true,
);
Thresholds mockThresholds() => _thresholds;
void saveMockThresholds(Thresholds value) => _thresholds = value;

const mockContacts = [
  AlertContact(
    name: 'Barangay DRRM Office',
    phone: '+63 9XX XXX XXXX',
    role: UserRole.official,
    alertLevel: ContactAlertLevel.watchAndAbove,
  ),
  AlertContact(
    name: 'MDRRMO Hotline',
    phone: '+63 9XX XXX XXXX',
    role: UserRole.responder,
    alertLevel: ContactAlertLevel.criticalOnly,
  ),
  AlertContact(
    name: '[Purok leader]',
    phone: '+63 9XX XXX XXXX',
    role: UserRole.official,
    alertLevel: ContactAlertLevel.watchAndAbove,
  ),
  AlertContact(
    name: '[Family member]',
    phone: '+63 9XX XXX XXXX',
    role: UserRole.resident,
    alertLevel: ContactAlertLevel.watchAndAbove,
  ),
];

const mockSmsPreview =
    'GEOPULSE ALERT: Combined hazard at Node GP-01 ([Site]) 10:42PM. Soil 93%, '
    'strong vibration. Move away from slopes and follow DRRM instructions.';

List<AppNotification> _notifications = _initialNotifications();

List<AppNotification> _initialNotifications() {
  final now = DateTime.now();
  return [
    AppNotification(
      id: 1,
      type: NotificationType.critical,
      title: 'Combined Hazard Alert',
      body: 'Soil 93% and strong ground vibration at Node GP‑01. Move away from '
          'slopes and go to your evacuation area.',
      time: now.subtract(const Duration(minutes: 2)),
    ),
    AppNotification(
      id: 2,
      type: NotificationType.offline,
      title: 'Node GP‑01 is offline',
      body: 'No data since the last reading. The siren and LEDs at the site still work.',
      time: now.subtract(const Duration(minutes: 46)),
    ),
    AppNotification(
      id: 3,
      type: NotificationType.watch,
      title: 'Landslide Watch',
      body: 'Soil moisture passed 70%. Prepare your go-bag and route.',
      time: now.subtract(const Duration(minutes: 47)),
      read: true,
    ),
    AppNotification(
      id: 4,
      type: NotificationType.high,
      title: 'Ground Vibration: High',
      body: '9 events/min for 40 s at Node GP‑01. If shaking: Drop, Cover, Hold On.',
      time: _todayAt(15, 15, daysAgo: 1),
      read: true,
    ),
    AppNotification(
      id: 5,
      type: NotificationType.backToStable,
      title: 'Back to Stable',
      body: 'All sensors are below warning levels again.',
      time: _todayAt(16, 2, daysAgo: 1),
      read: true,
    ),
  ];
}

List<AppNotification> mockNotifications() => List.unmodifiable(_notifications);

void setMockNotifications(List<AppNotification> list) => _notifications = list;

NotificationPrefs _prefs = const NotificationPrefs(
  warnings: true,
  backToStable: true,
  deviceOnline: true,
  lowBattery: false,
);
NotificationPrefs mockNotificationPrefs() => _prefs;
void saveMockNotificationPrefs(NotificationPrefs value) => _prefs = value;

/// Puts all mock data back to its starting state between tests.
@visibleForTesting
void resetMockData() {
  _level = StatusLevel.stable;
  _tick = 0;
  _notifications = _initialNotifications();
}
