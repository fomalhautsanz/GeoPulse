import 'package:flutter/material.dart';

import '../data/status_repository.dart';
import '../models/device_status.dart';
import '../models/sensor.dart';
import '../state/status_controller.dart';
import '../theme/app_colors.dart';
import '../utils/time_format.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/common.dart';
import '../widgets/fade_route.dart';
import '../widgets/level_chip.dart';
import '../widgets/pressable.dart';
import '../widgets/sensor_chart.dart';
import 'thresholds_screen.dart';

/// "Sensors · Live readings" in Figma: pick a sensor, see its value, trend
/// and chart, with small cards for the other two sensors.
///
/// [selected] is shared with the main shell, so tapping a card on Status
/// opens this tab on the right sensor.
class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key, required this.selected});

  final ValueNotifier<SensorKind> selected;

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  SensorRange _range = SensorRange.day;
  SensorHistory? _history;
  SensorDetails? _details;
  int _request = 0; // ignore answers to older requests

  @override
  void initState() {
    super.initState();
    widget.selected.addListener(_loadHistory);
    _loadHistory();
    getSensorDetails().then((d) {
      if (mounted) setState(() => _details = d);
    });
  }

  @override
  void dispose() {
    widget.selected.removeListener(_loadHistory);
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final id = ++_request;
    setState(() {}); // show the newly selected tab right away
    final history = await getSensorHistory(widget.selected.value, _range);
    if (mounted && id == _request) setState(() => _history = history);
  }

  @override
  Widget build(BuildContext context) {
    final status = StatusScope.of(context).status;
    final kind = widget.selected.value;
    final history = _history?.kind == kind && _history?.range == _range ? _history : null;
    final details = _details;

    return AppScaffold(
      title: 'Sensors',
      currentTab: AppTab.sensors,
      body: status == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              children: [
                SegmentedTabs<SensorKind>(
                  values: SensorKind.values,
                  selected: kind,
                  label: (k) => k.label,
                  onChanged: (k) => widget.selected.value = k,
                ),
                const SizedBox(height: 12),
                _MainCard(
                  kind: kind,
                  status: status,
                  history: history,
                  details: details,
                  range: _range,
                  onRange: (r) {
                    _range = r;
                    _loadHistory();
                  },
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final other in SensorKind.values.where((k) => k != kind)) ...[
                        if (other != SensorKind.values.firstWhere((k) => k != kind)) const SizedBox(width: 10),
                        Expanded(
                          child: _MiniCard(
                            kind: other,
                            status: status,
                            details: details,
                            onTap: () => widget.selected.value = other,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          details == null
                              ? ''
                              : 'Calibrated ${formatShortDate(details.calibratedOn)} · '
                                  'reads every ${details.readEvery.inSeconds} s',
                          style: const TextStyle(fontSize: 12, color: AppColors.ink),
                        ),
                      ),
                      Pressable(
                        onTap: () => Navigator.of(context).push(fadeRoute<void>(context, const ThresholdsScreen())),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          child: Text(
                            'Edit thresholds',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MainCard extends StatelessWidget {
  const _MainCard({
    required this.kind,
    required this.status,
    required this.history,
    required this.details,
    required this.range,
    required this.onRange,
  });

  final SensorKind kind;
  final DeviceStatus status;
  final SensorHistory? history;
  final SensorDetails? details;
  final SensorRange range;
  final ValueChanged<SensorRange> onRange;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final points = history?.points;
    final (title, value, unit, level) = switch (kind) {
      SensorKind.soil => ('Soil moisture · capacitive sensor', '${s.soilMoisturePercent}%', '', s.soilLevel),
      SensorKind.vibration => ('Ground vibration · SW‑420', '${s.vibrationPerMin}', ' events/min', s.vibrationLevel),
      SensorKind.tilt => ('Ground tilt · MPU6050', '${s.tiltDegrees.toStringAsFixed(1)}°', '', s.tiltLevel),
    };

    String? trend;
    if (points != null && points.length > 1) {
      final delta = points.last - points.first;
      final sign = delta >= 0 ? '+' : '−';
      final amount = switch (kind) {
        SensorKind.soil => '${delta.abs().round()}%',
        SensorKind.vibration => '${delta.abs().round()}/min',
        SensorKind.tilt => '${delta.abs().toStringAsFixed(1)}°',
      };
      final d = details;
      trend = kind == SensorKind.vibration && d != null
          ? 'Peak ${d.vibrationPeakPerMin}/min, ${formatRelativeDay(d.vibrationPeakTime)}'
          : '$sign$amount in the last ${_spanText(range)}';
    }

    final (minY, maxY, bands, limits) = switch (kind) {
      SensorKind.soil => (
          40.0,
          100.0,
          const [
            ChartBand(90, 100, AppColors.chartCriticalBand),
            ChartBand(70, 90, AppColors.chartWarningBand),
          ],
          const [ChartLimit(90, 'Critical 90%'), ChartLimit(70, 'Warning 70%')],
        ),
      SensorKind.vibration => (
          0.0,
          12.0,
          const [ChartBand(5, 12, AppColors.chartCriticalBand)],
          const [ChartLimit(5, 'Limit 5/min')],
        ),
      SensorKind.tilt => (
          0.0,
          4.0,
          const [ChartBand(2, 4, AppColors.chartCriticalBand)],
          const [ChartLimit(2, 'Limit 2.0°')],
        ),
    };

    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  text: value,
                  style: const TextStyle(fontSize: 40, height: 1.1, fontWeight: FontWeight.w700, color: AppColors.ink),
                  children: [
                    TextSpan(
                      text: unit,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              LevelChip(level: level),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            trend ?? ' ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.watchOn),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final r in SensorRange.values) ...[
                SelectChip(label: r.label, selected: r == range, dark: true, onTap: () => onRange(r)),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SensorChart(
            points: points ?? const [],
            minY: minY,
            maxY: maxY,
            bands: bands,
            limits: limits,
            xLabels: _xLabels(range),
            semanticLabel: points == null
                ? 'Chart loading'
                : '${kind.label} over the last ${_spanText(range)}, now $value$unit',
          ),
        ],
      ),
    );
  }

  static String _spanText(SensorRange r) => switch (r) {
        SensorRange.hour => 'hour',
        SensorRange.sixHours => '6 hours',
        SensorRange.day => '24 hours',
        SensorRange.week => '7 days',
      };

  /// Five evenly spaced time labels ending at "Now".
  static List<String> _xLabels(SensorRange r) {
    final now = DateTime.now();
    final step = r.span ~/ 4;
    return [
      for (var i = 4; i >= 1; i--)
        switch (r) {
          SensorRange.hour => '${(step * i).inMinutes} min',
          SensorRange.week => formatWeekday(now.subtract(step * i)),
          _ => formatHour(now.subtract(step * i)),
        },
      'Now',
    ];
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.kind, required this.status, required this.details, required this.onTap});

  final SensorKind kind;
  final DeviceStatus status;
  final SensorDetails? details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final d = details;
    final (title, value, unit) = switch (kind) {
      SensorKind.soil => ('Soil moisture', '${s.soilMoisturePercent}%', ''),
      SensorKind.vibration => ('Vibration', '${s.vibrationPerMin}', ' events/min'),
      SensorKind.tilt => ('Ground tilt', '${s.tiltDegrees.toStringAsFixed(1)}°', ''),
    };
    final Widget middle = switch (kind) {
      SensorKind.vibration => MiniBars(values: d?.recentVibration ?? const []),
      SensorKind.tilt => Wrap(
          spacing: 6,
          children: [
            TagChip('X ${d?.tiltX.toStringAsFixed(1) ?? '–'}°'),
            TagChip('Y ${d?.tiltY.toStringAsFixed(1) ?? '–'}°'),
          ],
        ),
      SensorKind.soil => LevelChip(level: s.soilLevel),
    };
    final caption = switch (kind) {
      SensorKind.vibration =>
        d == null ? 'SW‑420' : 'SW‑420 · peak ${d.vibrationPeakPerMin}/min, ${formatClock(d.vibrationPeakTime)}',
      SensorKind.tilt => 'MPU6050 · limit ${DeviceStatus.tiltLimitDegrees.toStringAsFixed(1)}°',
      SensorKind.soil => 'Capacitive · warning at ${DeviceStatus.soilWarningPercent}%',
    };

    return Pressable(
      onTap: onTap,
      semanticLabel: 'Show $title',
      child: OutlinedCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.ink))),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.ink),
              ],
            ),
            Text.rich(
              TextSpan(
                text: value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
                children: [TextSpan(text: unit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))],
              ),
            ),
            const SizedBox(height: 6),
            Padding(padding: const EdgeInsets.only(right: 4), child: middle),
            const SizedBox(height: 6),
            Text(caption, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
