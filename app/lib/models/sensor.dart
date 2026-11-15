/// The three sensors on a GeoPulse node.
enum SensorKind {
  soil('Soil'),
  vibration('Vibration'),
  tilt('Tilt');

  const SensorKind(this.label);
  final String label;
}

/// How far back the Sensors chart looks.
enum SensorRange {
  hour('1H', Duration(hours: 1)),
  sixHours('6H', Duration(hours: 6)),
  day('24H', Duration(hours: 24)),
  week('7D', Duration(days: 7));

  const SensorRange(this.label, this.span);
  final String label;
  final Duration span;
}

/// Readings over time for one sensor, oldest first. The last point is now.
class SensorHistory {
  const SensorHistory({required this.kind, required this.range, required this.points});

  final SensorKind kind;
  final SensorRange range;
  final List<double> points;
}

/// Extra details shown on the Sensors screen.
class SensorDetails {
  const SensorDetails({
    required this.tiltX,
    required this.tiltY,
    required this.vibrationPeakPerMin,
    required this.vibrationPeakTime,
    required this.recentVibration,
    required this.calibratedOn,
    required this.readEvery,
  });

  final double tiltX; // degrees, MPU6050 X axis
  final double tiltY; // degrees, Y axis
  final int vibrationPeakPerMin;
  final DateTime vibrationPeakTime;
  final List<int> recentVibration; // events/min, last few minutes (mini bars)
  final DateTime calibratedOn;
  final Duration readEvery;
}
