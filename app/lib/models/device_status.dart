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
    required this.online,
    required this.batteryPercent,
    required this.gsmBars,
    required this.lastUpdate,
    required this.sirenOn,
    required this.smsSent,
    required this.smsTotal,
  });

  /// Sensor limits shown on the cards. `static` means they belong to the
  /// class itself, not to each snapshot.
  static const int soilWarningPercent = 70; // Watch from here
  static const int soilHighPercent = 80;
  static const int soilCriticalPercent = 90;
  static const int vibrationLimitPerMin = 5;
  static const double tiltLimitDegrees = 2.0;
  static const int maxGsmBars = 4;

  final String nodeId; // e.g. "GP‑01"
  final StatusLevel level;
  final int soilMoisturePercent; // 0–100
  final int vibrationPerMin; // SW‑420 vibration events per minute
  final double tiltDegrees; // MPU6050 ground tilt
  final bool online;
  final int batteryPercent; // 0–100
  final int gsmBars; // 0–[maxGsmBars]
  final DateTime lastUpdate;
  final bool sirenOn; // true = siren sounding, false = standby
  final int smsSent; // alert SMS messages sent so far…
  final int smsTotal; // …out of this many contacts

  // A `get`ter is a value computed from other fields, used like a field:
  // `status.soilLevel`.

  /// How worrying the soil reading is on its own.
  StatusLevel get soilLevel {
    if (soilMoisturePercent >= soilCriticalPercent) return StatusLevel.critical;
    if (soilMoisturePercent >= soilHighPercent) return StatusLevel.high;
    if (soilMoisturePercent >= soilWarningPercent) return StatusLevel.watch;
    return StatusLevel.stable;
  }

  /// How worrying the vibration reading is on its own.
  StatusLevel get vibrationLevel =>
      vibrationPerMin >= vibrationLimitPerMin ? StatusLevel.critical : StatusLevel.stable;

  /// How worrying the tilt reading is on its own.
  StatusLevel get tiltLevel =>
      tiltDegrees >= tiltLimitDegrees ? StatusLevel.critical : StatusLevel.stable;
}
