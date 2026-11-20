import 'package:flutter_test/flutter_test.dart';
import 'package:geopulse/models/device_status.dart';

void main() {
  test('unavailable ADXL readings do not raise motion alerts', () {
    final status = DeviceStatus(
      nodeId: 'GP-01',
      level: StatusLevel.stable,
      soilMoisturePercent: 20,
      vibrationPerMin: 90,
      tiltDegrees: 20,
      adxlReady: false,
      online: true,
      lastUpdate: DateTime(2025),
    );

    expect(status.vibrationLevel, StatusLevel.stable);
    expect(status.tiltLevel, StatusLevel.stable);
  });

  test('brief vibration events do not raise a critical vibration alert', () {
    final status = DeviceStatus(
      nodeId: 'GP-01',
      level: StatusLevel.stable,
      soilMoisturePercent: 20,
      vibrationPerMin: 14,
      tiltDegrees: 0,
      adxlReady: true,
      online: true,
      lastUpdate: DateTime(2025),
    );

    expect(status.vibrationLevel, StatusLevel.stable);
  });

  test('sustained vibration above the configured count raises an alert', () {
    final status = DeviceStatus(
      nodeId: 'GP-01',
      level: StatusLevel.critical,
      soilMoisturePercent: 20,
      vibrationPerMin: 14,
      tiltDegrees: 0,
      sustainedVibration: true,
      adxlReady: true,
      online: true,
      lastUpdate: DateTime(2025),
    );

    expect(status.vibrationLevel, StatusLevel.critical);
  });

  test(
    'tilt can remain critical without classifying vibration as sustained',
    () {
      final status = DeviceStatus(
        nodeId: 'GP-01',
        level: StatusLevel.critical,
        soilMoisturePercent: 20,
        vibrationPerMin: 0,
        tiltDegrees: 3.5,
        adxlReady: true,
        online: true,
        lastUpdate: DateTime(2025),
      );

      expect(status.tiltLevel, StatusLevel.critical);
      expect(status.vibrationLevel, StatusLevel.stable);
    },
  );

  test('soil status uses the configured warning and critical thresholds', () {
    final status = DeviceStatus(
      nodeId: 'GP-01',
      level: StatusLevel.high,
      soilMoisturePercent: 70,
      vibrationPerMin: 0,
      tiltDegrees: 0,
      soilWatchThresholdPercent: 60,
      soilCriticalThresholdPercent: 80,
      online: true,
      lastUpdate: DateTime(2025),
    );

    expect(status.soilLevel, StatusLevel.high);
  });
}
