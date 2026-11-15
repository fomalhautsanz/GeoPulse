import 'user_profile.dart';

/// The sensor node's hardware and firmware.
class DeviceInfo {
  const DeviceInfo({
    required this.name,
    required this.board,
    required this.firmware,
    required this.lastSirenTest,
  });

  final String name; // "GeoPulse Node GP‑01"
  final String board; // "ESP32"
  final String firmware; // "[v0.1]"
  final DateTime lastSirenTest;
}

enum VibrationSensitivity {
  low('Low'),
  medium('Med'),
  high('High');

  const VibrationSensitivity(this.label);
  final String label;
}

/// When the device raises alerts, and which outputs it uses.
class Thresholds {
  const Thresholds({
    required this.soilWatchPercent,
    required this.soilCriticalPercent,
    required this.vibrationPerMin,
    required this.sensitivity,
    required this.tiltDegrees,
    required this.sirenEnabled,
    required this.ledsEnabled,
    required this.autoSms,
    required this.combinedAlert,
  });

  final int soilWatchPercent;
  final int soilCriticalPercent;
  final int vibrationPerMin;
  final VibrationSensitivity sensitivity;
  final double tiltDegrees;
  final bool sirenEnabled;
  final bool ledsEnabled;
  final bool autoSms; // SMS at Watch and above
  final bool combinedAlert; // alert when 2 sensors trigger

  /// A copy with some values changed: `t.copyWith(autoSms: false)`.
  Thresholds copyWith({
    int? soilWatchPercent,
    int? soilCriticalPercent,
    int? vibrationPerMin,
    VibrationSensitivity? sensitivity,
    double? tiltDegrees,
    bool? sirenEnabled,
    bool? ledsEnabled,
    bool? autoSms,
    bool? combinedAlert,
  }) {
    return Thresholds(
      soilWatchPercent: soilWatchPercent ?? this.soilWatchPercent,
      soilCriticalPercent: soilCriticalPercent ?? this.soilCriticalPercent,
      vibrationPerMin: vibrationPerMin ?? this.vibrationPerMin,
      sensitivity: sensitivity ?? this.sensitivity,
      tiltDegrees: tiltDegrees ?? this.tiltDegrees,
      sirenEnabled: sirenEnabled ?? this.sirenEnabled,
      ledsEnabled: ledsEnabled ?? this.ledsEnabled,
      autoSms: autoSms ?? this.autoSms,
      combinedAlert: combinedAlert ?? this.combinedAlert,
    );
  }
}

/// Which alerts a contact gets by SMS.
enum ContactAlertLevel {
  watchAndAbove('Watch and above'),
  criticalOnly('Critical only');

  const ContactAlertLevel(this.label);
  final String label;
}

/// Someone who receives SMS alerts from the device.
class AlertContact {
  const AlertContact({
    required this.name,
    required this.phone,
    required this.role,
    required this.alertLevel,
  });

  final String name;
  final String phone;
  final UserRole role;
  final ContactAlertLevel alertLevel;

  /// "Barangay DRRM Office" → "BD".
  String get initials {
    final words = name.replaceAll(RegExp(r'[\[\]]'), '').split(' ').where((w) => w.isNotEmpty).toList();
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}
