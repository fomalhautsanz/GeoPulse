import 'package:geopulse/models/device_status.dart';

DeviceStatus mockStatus(StatusLevel level) {
  final soil = switch (level) {
    StatusLevel.stable => 49,
    StatusLevel.watch => 74,
    StatusLevel.high => 84,
    StatusLevel.critical => 93,
  };
  final motion = level == StatusLevel.critical;
  return DeviceStatus(
    nodeId: 'GP-01',
    level: level,
    soilMoisturePercent: soil,
    vibrationPerMin: motion ? 14 : 0,
    tiltDegrees: motion ? 3.8 : 0.4,
    sustainedVibration: motion,
    adxlReady: true,
    online: true,
    lastUpdate: DateTime.now(),
  );
}
