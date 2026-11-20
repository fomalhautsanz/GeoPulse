import 'user_profile.dart';

/// The sensor node's hardware and firmware.
class DeviceInfo {
  const DeviceInfo({
    required this.name,
    required this.board,
    required this.firmware,
  });

  final String name; // "GeoPulse Node GP‑01"
  final String board; // "ESP32"
  final String firmware; // "[v0.1]"
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
  });

  final int soilWatchPercent;
  final int soilCriticalPercent;
  final int vibrationPerMin;
  final VibrationSensitivity sensitivity;
  final double tiltDegrees;

  /// A copy with some values changed: `t.copyWith(soilWatchPercent: 65)`.
  Thresholds copyWith({
    int? soilWatchPercent,
    int? soilCriticalPercent,
    int? vibrationPerMin,
    VibrationSensitivity? sensitivity,
    double? tiltDegrees,
  }) {
    return Thresholds(
      soilWatchPercent: soilWatchPercent ?? this.soilWatchPercent,
      soilCriticalPercent: soilCriticalPercent ?? this.soilCriticalPercent,
      vibrationPerMin: vibrationPerMin ?? this.vibrationPerMin,
      sensitivity: sensitivity ?? this.sensitivity,
      tiltDegrees: tiltDegrees ?? this.tiltDegrees,
    );
  }
}

const defaultThresholds = Thresholds(
  soilWatchPercent: 70,
  soilCriticalPercent: 90,
  vibrationPerMin: 5,
  sensitivity: VibrationSensitivity.medium,
  tiltDegrees: 2.0,
);

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
    final words = name
        .replaceAll(RegExp(r'[\[\]]'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}
