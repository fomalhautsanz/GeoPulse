import 'package:flutter/material.dart';

import '../data/status_repository.dart';
import '../models/device_status.dart';
import '../models/history.dart';
import '../theme/app_colors.dart';
import '../theme/level_style.dart';
import '../utils/time_format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/common.dart';

/// "Alert history" in Figma: filter chips, this week at a glance, then past
/// alert transitions grouped by day with any output reports available.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AlertEvent>? _events; // null while loading
  Object? _error;
  HazardKind? _filter; // null = All

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await getAlertHistory();
      if (mounted) {
        setState(() {
          _events = events;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    return AppScaffold(
      title: 'History',
      currentTab: AppTab.history,
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load history: $_error'),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : events == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _load,
              child: _buildList(events),
            ),
    );
  }

  Widget _buildList(List<AlertEvent> events) {
    final shown = _filter == null
        ? events
        : events.where((e) => e.kind == _filter).toList();

    // Group by day, keeping newest first.
    final groups = <String, List<AlertEvent>>{};
    for (final e in shown..sort((a, b) => b.time.compareTo(a.time))) {
      groups.putIfAbsent(formatDayLabel(e.time), () => []).add(e);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              SelectChip(
                label: 'All',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final kind in HazardKind.values) ...[
                const SizedBox(width: 8),
                SelectChip(
                  label: kind.label,
                  selected: _filter == kind,
                  onTap: () => setState(() => _filter = kind),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _WeekCard(events: events),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No alerts of this kind yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ),
        for (final entry in groups.entries) ...[
          GroupLabel(entry.key),
          for (final e in entry.value) ...[
            _EventCard(event: e),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 12),
        AppButton(
          label: 'CSV export unavailable',
          icon: Icons.download_rounded,
          variant: AppButtonVariant.neutral,
          height: 46,
          onPressed: null,
        ),
      ],
    );
  }
}

/// "This week": one dot per day, filled with the worst level that day.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.events});

  final List<AlertEvent> events;

  @override
  Widget build(BuildContext context) {
    final today = startOfDay(DateTime.now());
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final weekEvents = events
        .where((e) => e.level != null && !e.time.isBefore(days.first))
        .toList();

    StatusLevel? worstOn(DateTime day) {
      StatusLevel? worst;
      for (final e in weekEvents) {
        if (startOfDay(e.time) == day &&
            (worst == null || e.level!.index > worst.index)) {
          worst = e.level;
        }
      }
      return worst;
    }

    final counts = <String>[
      for (final level in [
        StatusLevel.critical,
        StatusLevel.high,
        StatusLevel.watch,
      ])
        if (weekEvents.any((e) => e.level == level))
          '${weekEvents.where((e) => e.level == level).length} ${level.name}',
    ];

    return OutlinedCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'This week',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                counts.isEmpty ? 'No alerts' : counts.join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                _DayDot(
                  label: day == today ? 'Today' : formatWeekday(day)[0],
                  isToday: day == today,
                  level: worstOn(day),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.isToday,
    required this.level,
  });

  final String label;
  final bool isToday;
  final StatusLevel? level;

  @override
  Widget build(BuildContext context) {
    final l = level;
    return Semantics(
      label: '$label: ${l == null ? 'no alerts' : LevelStyle.of(l).label}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: l == null ? AppColors.surface : LevelStyle.of(l).strong,
                shape: BoxShape.circle,
                border: l == null
                    ? Border.all(color: AppColors.emptyDot)
                    : null,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? AppColors.ink : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final AlertEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final (icon, bg, fg) = switch (e.level) {
      StatusLevel.critical => (
        Icons.warning_amber_rounded,
        AppColors.criticalContainer,
        AppColors.criticalOn,
      ),
      StatusLevel.high => (
        Icons.monitor_heart_outlined,
        AppColors.brand,
        AppColors.onBrand,
      ),
      StatusLevel.watch => (
        Icons.water_drop_outlined,
        AppColors.watchContainer,
        AppColors.watchStrong,
      ),
      StatusLevel.stable => (
        Icons.shield_outlined,
        AppColors.card,
        AppColors.ink,
      ),
      null => (
        Icons.check_rounded,
        AppColors.card,
        AppColors.ink,
      ), // alarm test
    };

    return OutlinedCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, background: bg, foreground: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        e.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatClock(e.time),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  e.detail,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in e.outputs)
                      TagChip(o.label, icon: _outputIcon(o), warning: !o.ok),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _outputIcon(AlertOutput o) => switch (o.kind) {
    OutputKind.siren || OutputKind.buzzer => Icons.volume_up_outlined,
    OutputKind.sms => Icons.chat_bubble_outline_rounded,
    OutputKind.cloud => o.ok ? Icons.cloud_outlined : Icons.cloud_off_outlined,
    OutputKind.leds => Icons.wb_sunny_outlined,
  };
}
