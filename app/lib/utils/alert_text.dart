import '../models/device_status.dart';

/// Shared wording for alerts, so the alert screen, the notifications and
/// the in-app list always say the same thing.

/// The alert title and reason, picked from which sensors are past their limit.
(String, String) criticalHeadline(DeviceStatus s) {
  final soil = s.soilLevel == StatusLevel.critical;
  final shaking = s.vibrationLevel == StatusLevel.critical;
  final tilt = s.tiltLevel == StatusLevel.critical;
  if (soil && (shaking || tilt)) {
    return (
      'Combined Hazard Alert',
      'Critical · saturated soil and ground movement detected',
    );
  }
  if (soil) {
    return ('Landslide Alert', 'Critical · the soil is saturated');
  }
  if (shaking) {
    return ('Strong Vibration Alert', 'Critical · strong ground vibration');
  }
  if (tilt) {
    return (
      'Ground Movement Alert',
      'Critical · the ground is tilting past its limit',
    );
  }
  return ('Critical Alert', 'Critical · follow official advisories');
}

/// The big title on the Status screen for each level.
String statusTitle(StatusLevel level) => switch (level) {
  StatusLevel.stable => 'Conditions Stable',
  StatusLevel.watch => 'Landslide Watch',
  StatusLevel.high => 'Landslide Risk: High',
  StatusLevel.critical => 'Critical Alert',
};
