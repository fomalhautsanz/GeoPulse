import 'device_status.dart';

/// What kind of hazard an alert was about. Used by the History filters.
enum HazardKind {
  landslide('Landslide'),
  earthquake('Earthquake'),
  groundMovement('Ground movement'),
  combined('Combined'),
  test('Tests');

  const HazardKind(this.label);
  final String label;
}

/// One warning output an alert used (siren, SMS, cloud…).
enum OutputKind { siren, buzzer, sms, cloud, leds }

/// An output and whether it worked, e.g. "SMS 2/4" that didn't all send.
class AlertOutput {
  const AlertOutput(this.kind, this.label, {this.ok = true});

  final OutputKind kind;
  final String label; // "SMS 4/4", "Cloud queued"
  final bool ok; // false = show it as a problem
}

/// One past alert in History.
class AlertEvent {
  const AlertEvent({
    required this.kind,
    required this.level,
    required this.title,
    required this.detail,
    required this.time,
    required this.outputs,
  });

  final HazardKind kind;
  final StatusLevel? level; // null for an alarm test
  final String title;
  final String detail;
  final DateTime time;
  final List<AlertOutput> outputs;
}
