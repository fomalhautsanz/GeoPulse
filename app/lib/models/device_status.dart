/// The overall alert level of a sensor node, calmest first.
enum StatusLevel { stable, watch, high, critical }

/// One snapshot of everything a GeoPulse sensor node reports.
///
/// This is a plain data class: it holds values and has no logic for fetching
/// them. `final` fields can't change after the object is created; to show new
/// data, the app asks for a new [DeviceStatus].
class DeviceStatus {
  const DeviceStatus({
    required this.nodeId,
    required this.level,
    required this.soilMoisturePercent,
    required this.vibrationPerMin,
    required this.tiltDegrees,
    this.tiltX,
    this.tiltY,
    this.sustainedVibration = false,
    this.adxlReady = false,
    this.soilWatchThresholdPercent = soilWarningPercent,
    this.soilCriticalThresholdPercent = soilCriticalPercent,
    this.vibrationThresholdPerMin = vibrationLimitPerMin,
    this.tiltThresholdDegrees = tiltLimitDegrees,
    required this.online,
    this.batteryPercent,
    this.wifiBars,
    required this.lastUpdate,
  });

  /// Sensor limits shown on the cards. `static` means they belong to the
  /// class itself, not to each snapshot.
  static const int soilWarningPercent = 70; // Watch from here
  static const int soilCriticalPercent = 90;
  static const int vibrationLimitPerMin = 5;
  static const double tiltLimitDegrees = 2.0;
  static const int maxWifiBars = 4;

  final String nodeId; // e.g. "GP‑01"
  final StatusLevel level;
  final int soilMoisturePercent; // 0–100
  final int vibrationPerMin; // ADXL345 vibration events per minute
  final double tiltDegrees; // ADXL345 ground tilt from the startup reference
  final double? tiltX;
  final double? tiltY;
  final bool sustainedVibration;
  final bool adxlReady;
  final int soilWatchThresholdPercent;
  final int soilCriticalThresholdPercent;
  final int vibrationThresholdPerMin;
  final double tiltThresholdDegrees;
  final bool online;
  final int? batteryPercent; // null when the node has no battery sensor
  final int? wifiBars; // 0–[maxWifiBars], derived from Wi-Fi RSSI
  final DateTime lastUpdate;

  // A `get`ter is a value computed from other fields, used like a field:
  // `status.soilLevel`.

  /// How worrying the soil reading is on its own.
  int get soilHighThreshold =>
      (soilWatchThresholdPercent + soilCriticalThresholdPercent + 1) ~/ 2;

  StatusLevel get soilLevel {
    if (soilMoisturePercent >= soilCriticalThresholdPercent) {
      return StatusLevel.critical;
    }
    if (soilMoisturePercent >= soilHighThreshold) return StatusLevel.high;
    if (soilMoisturePercent >= soilWatchThresholdPercent) {
      return StatusLevel.watch;
    }
    return StatusLevel.stable;
  }

  /// How worrying the vibration reading is on its own.
  StatusLevel get vibrationLevel =>
      adxlReady &&
          sustainedVibration &&
          vibrationPerMin >= vibrationThresholdPerMin
      ? StatusLevel.critical
      : StatusLevel.stable;

  /// How worrying the tilt reading is on its own.
  StatusLevel get tiltLevel => adxlReady && tiltDegrees >= tiltThresholdDegrees
      ? StatusLevel.critical
      : StatusLevel.stable;

  DeviceStatus copyWith({bool? online}) => DeviceStatus(
    nodeId: nodeId,
    level: level,
    soilMoisturePercent: soilMoisturePercent,
    vibrationPerMin: vibrationPerMin,
    tiltDegrees: tiltDegrees,
    tiltX: tiltX,
    tiltY: tiltY,
    sustainedVibration: sustainedVibration,
    adxlReady: adxlReady,
    soilWatchThresholdPercent: soilWatchThresholdPercent,
    soilCriticalThresholdPercent: soilCriticalThresholdPercent,
    vibrationThresholdPerMin: vibrationThresholdPerMin,
    tiltThresholdDegrees: tiltThresholdDegrees,
    online: online ?? this.online,
    batteryPercent: batteryPercent,
    wifiBars: wifiBars,
    lastUpdate: lastUpdate,
  );
}
