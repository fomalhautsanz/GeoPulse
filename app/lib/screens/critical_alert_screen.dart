import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../utils/alert_text.dart';
import '../utils/time_format.dart';
import '../widgets/app_button.dart';
import '../widgets/fade_route.dart';
import '../widgets/hold_to_confirm_button.dart';
import '../widgets/pressable.dart';

/// Opens the critical alert full screen: fades in and rises 8 px (250 ms).
Route<void> criticalAlertRoute(
  BuildContext context, {
  required DeviceStatus status,
  required bool silenced,
  required VoidCallback onSilenced,
}) {
  return fadeRoute<void>(
    context,
    CriticalAlertScreen(
      status: status,
      silenced: silenced,
      onSilenced: onSilenced,
    ),
    duration: AppMotion.alertIn,
    rise: AppMotion.alertRise,
    fullscreenDialog: true,
  );
}

/// "Alert · Critical" in Figma: a deep maroon header with a pulsing warning,
/// then what triggered the alert and what to do.
class CriticalAlertScreen extends StatefulWidget {
  const CriticalAlertScreen({
    super.key,
    required this.status,
    required this.silenced,
    required this.onSilenced,
  });

  final DeviceStatus status;
  final bool silenced; // already silenced on this phone?
  final VoidCallback onSilenced;

  @override
  State<CriticalAlertScreen> createState() => _CriticalAlertScreenState();
}

class _CriticalAlertScreenState extends State<CriticalAlertScreen> {
  late bool _silenced = widget.silenced;

  void _silence() {
    setState(() => _silenced = true);
    widget.onSilenced();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final insets = MediaQuery.viewPaddingOf(context);
    final top = math.max(36.0, insets.top);
    final (title, reason) = criticalHeadline(
      s,
    ); // a "record": two values at once

    return Scaffold(
      backgroundColor: AppColors.criticalContainer,
      body: Column(
        children: [
          // ---------------- Header ----------------
          Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, top + 16, 24, 40),
                child: Column(
                  children: [
                    Text(
                      'Node ${s.nodeId} · Triggered ${formatClock(s.lastUpdate)}'
                      ' · ${formatAgo(s.lastUpdate)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.172,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onCriticalMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _CriticalPulse(),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        height: 34 / 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.criticalOn,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: AppColors.onCriticalMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 8,
                top: top,
                child: Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  semanticLabel: 'Close, back to Status',
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.close,
                      size: 24,
                      color: AppColors.criticalOn,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // ---------------- White sheet ----------------
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel('Triggered by'),
                    Row(
                      children: [
                        _TriggerTile(
                          icon: Icons.water_drop_outlined,
                          label: 'Soil',
                          value: '${s.soilMoisturePercent}%',
                          limit:
                              'Critical ≥ ${s.soilCriticalThresholdPercent}%',
                          level: s.soilLevel,
                        ),
                        const SizedBox(width: 8),
                        _TriggerTile(
                          icon: Icons.monitor_heart_outlined,
                          label: 'Vibration',
                          value: s.adxlReady
                              ? '${s.vibrationPerMin}/min'
                              : 'Unavailable',
                          limit: 'Limit ≥ ${s.vibrationThresholdPerMin}/min',
                          level: s.vibrationLevel,
                        ),
                        const SizedBox(width: 8),
                        _TriggerTile(
                          icon: Icons.trending_up_rounded,
                          label: 'Tilt',
                          value: s.adxlReady
                              ? '${s.tiltDegrees.toStringAsFixed(1)}°'
                              : 'Unavailable',
                          limit:
                              'Limit ≥ ${s.tiltThresholdDegrees.toStringAsFixed(1)}°',
                          level: s.tiltLevel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    const _SectionLabel('Device outputs'),
                    Row(
                      children: [
                        _SentTile(
                          title: 'Siren / LED / SMS',
                          detail: 'Not available in firmware',
                          done: false,
                        ),
                        const SizedBox(width: 8),
                        _SentTile(
                          title: 'Firebase',
                          detail: s.online ? 'Updated online' : 'Offline',
                          done: s.online,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    const _SectionLabel('Do this now'),
                    const _Step(
                      1,
                      'Move away from slopes, riverbanks and road cuts.',
                    ),
                    const SizedBox(height: 8),
                    const _Step(
                      2,
                      'If the ground shakes: Drop, Cover and Hold On.',
                    ),
                    const SizedBox(height: 8),
                    const _Step(
                      3,
                      'Follow evacuation instructions from your barangay DRRM office.',
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Hotline unavailable',
                            icon: Icons.phone_outlined,
                            onPressed: null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: HoldToConfirmButton(
                            label: 'Silence on this phone',
                            doneLabel: 'Silenced on this phone',
                            done: _silenced,
                            onConfirmed: _silence,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'This only silences phone notifications; it does not control site hardware.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 15 / 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'GeoPulse detects risky conditions. It can’t predict exactly when a '
                      'landslide or earthquake will happen. Always follow official advisories.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 15 / 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The alert icon in a soft circle, with a ring that grows to 115% and fades,
/// every 1.2 s. With animations off the ring doesn't pulse.
class _CriticalPulse extends StatefulWidget {
  const _CriticalPulse();

  @override
  State<_CriticalPulse> createState() => _CriticalPulseState();
}

class _CriticalPulseState extends State<_CriticalPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.pulse,
  );

  // Runs when inherited settings (like "Remove animations") change.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const circle = BoxDecoration(
      color: AppColors.sirenHalo,
      shape: BoxShape.circle,
    );

    return Semantics(
      label: 'Critical alert',
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!AppMotion.reduced(context))
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(_pulse.value);
                  return Transform.scale(
                    scale: 1 + (AppMotion.pulseScale - 1) * t,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.sirenRing,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            Container(decoration: circle),
            const Icon(
              Icons.warning_amber_rounded,
              size: 44,
              color: AppColors.criticalOn,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 16 / 13,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _TriggerTile extends StatelessWidget {
  const _TriggerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.limit,
    required this.level,
  });

  final IconData icon;
  final String label;
  final String value;
  final String limit;
  final StatusLevel level;

  @override
  Widget build(BuildContext context) {
    final over = level == StatusLevel.critical;
    return Expanded(
      child: Container(
        height: 77,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: over ? AppColors.watchContainer : AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: over ? AppColors.brand : AppColors.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: _small(
                    FontWeight.w700,
                  ).copyWith(color: over ? AppColors.brand : AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                height: 26 / 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              limit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _small(FontWeight.w400)
                  .copyWith(color: over ? AppColors.watchOn : AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentTile extends StatelessWidget {
  const _SentTile({
    required this.title,
    required this.detail,
    required this.done,
  });

  final String title;
  final String detail;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 43,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? AppColors.success : AppColors.outline,
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check : Icons.schedule,
                size: 14,
                color: done ? AppColors.surface : AppColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 14 / 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _small(FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.criticalOn,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 19 / 14,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

TextStyle _small(FontWeight weight) => TextStyle(
  fontSize: 11,
  height: 13 / 11,
  fontWeight: weight,
  color: AppColors.muted,
);
