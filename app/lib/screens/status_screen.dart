import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/status_repository.dart';
import '../models/device_status.dart';
import '../models/sensor.dart';
import '../state/shell_scope.dart';
import '../state/status_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/level_style.dart';
import '../utils/alert_text.dart';
import '../utils/time_format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/pressable.dart';
import '../widgets/sensor_card.dart';
import '../widgets/status_arch.dart';

/// The Status dashboard: overall alert level, live sensor readings and the
/// local siren. Matches the Figma frames "Status · Stable / Watch (node
/// offline) / High (landslide)".
///
/// It reads the live reading from [StatusScope], so it rebuilds whenever
/// the reading changes (every 2 s).
class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StatusScope.of(context);
    final status = controller.status;

    return AppScaffold(
      title: 'Status',
      currentTab: AppTab.status,
      // The soft arch behind the icon, title and pill. It sits in the
      // screen-wide Stack because its `top: 196` is measured from the top
      // of the screen; the scrolling content is drawn on top of it.
      background: status == null ? null : StatusArch(tint: LevelStyle.of(status.level).glow),
      body: status == null
          ? (controller.error == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
              : Center(child: Text(controller.error!)))
          // RefreshIndicator adds pull-to-refresh. A refresh is a routine
          // update: same level, numbers change, no animation.
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(33, 0, 33, 24),
                children: [_Dashboard(status: status)],
              ),
            ),
    );
  }
}

/// Figma's "normal" line height for Roboto (1.172 × font size).
const double _normalLineHeight = 1.172;

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.status});

  final DeviceStatus status;

  Future<void> _testAlarm(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Test the site alarm?',
      message: 'The siren and red LED at Node ${status.nodeId} will turn on for '
          '5 seconds. People near the site will hear it.',
      confirmLabel: 'Test alarm',
    );
    if (!confirmed || !context.mounted) return;
    await testSiren();
    if (context.mounted) showMessage(context, 'Test alarm sent to Node ${status.nodeId}.');
  }

  @override
  Widget build(BuildContext context) {
    final s = status;
    final colorChange = AppMotion.levelChangeFor(context);
    final shell = ShellScope.maybeOf(context)?.actions;
    void openSensor(SensorKind kind) => shell?.selectTab(AppTab.sensors, sensor: kind);
    final lastKnown = s.online ? null : 'last known ${formatClock(s.lastUpdate)}';
    final tiltWord = s.tiltLevel == StatusLevel.stable ? 'Normal' : 'Over limit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Offline: a dark banner takes the info line's place (same height
        // overall, so nothing below moves).
        if (s.online) ...[
          const SizedBox(height: 24),
          _InfoLine(status: s),
          const SizedBox(height: 26),
        ] else ...[
          const SizedBox(height: 14),
          _OfflineBanner(since: s.lastUpdate),
          const SizedBox(height: 10),
        ],
        // Icon, title and next step crossfade in place when the level
        // changes. Keyed by level, so routine updates don't animate.
        _LevelFade(
          level: s.level,
          duration: colorChange,
          child: Center(child: SizedBox(width: 72, height: 72, child: _heroIcon(s.level))),
        ),
        const SizedBox(height: 10),
        _LevelFade(
          level: s.level,
          duration: colorChange,
          child: Text(
            statusTitle(s.level),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 34 / 30, // line height 34 px
              fontWeight: FontWeight.w700,
              color: _valueColor(s.level),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _LevelFade(
          level: s.level,
          duration: colorChange,
          child: Center(
            child: _NextStepPill(
              level: s.level,
              onTap: s.level == StatusLevel.critical ? shell?.openCriticalAlert : null,
            ),
          ),
        ),
        const SizedBox(height: 24.5),
        SectionTitle(
          'Activity Status',
          color: AppColors.brand,
          trailing: Text(
            s.online ? 'Updated ${formatAgo(s.lastUpdate)}' : 'Last data ${formatClock(s.lastUpdate)}',
            style: const TextStyle(fontSize: 11, height: _normalLineHeight, color: AppColors.muted),
          ),
        ),
        SensorCard(
          icon: _maskIcon('assets/icons/soil.png', _accent(s.soilLevel) ?? AppColors.ink),
          title: 'Soil Moisture Status',
          value: '${s.soilMoisturePercent}%',
          caption: lastKnown == null ? _soilCaption(s.soilLevel) : '${_levelWord(s.soilLevel)} · $lastKnown',
          valueColor: _valueColor(s.soilLevel),
          accentColor: _accent(s.soilLevel),
          onTap: () => openSensor(SensorKind.soil),
        ),
        const SizedBox(height: 10),
        SensorCard(
          icon: _maskIcon('assets/icons/seismic.png', _accent(s.vibrationLevel) ?? AppColors.ink),
          title: 'Seismic Activity Status',
          value: s.vibrationLevel == StatusLevel.critical ? 'Strong' : 'Normal',
          caption: lastKnown != null
              ? '${s.vibrationPerMin}/min · $lastKnown'
              : s.vibrationPerMin == 0
                  ? 'Vibration 0/min · SW‑420'
                  : 'Vibration ${s.vibrationPerMin}/min · limit ${DeviceStatus.vibrationLimitPerMin}/min',
          valueColor: _valueColor(s.vibrationLevel),
          accentColor: _accent(s.vibrationLevel),
          onTap: () => openSensor(SensorKind.vibration),
        ),
        const SizedBox(height: 10),
        SensorCard(
          icon: SvgPicture.asset(
            'assets/icons/tilt.svg',
            width: 52,
            height: 52,
            colorFilter: _accent(s.tiltLevel) == null
                ? null
                : ColorFilter.mode(_accent(s.tiltLevel)!, BlendMode.srcIn),
          ),
          title: 'Ground Movement Status',
          value: '${s.tiltDegrees.toStringAsFixed(1)}°',
          caption: lastKnown == null
              ? '$tiltWord · MPU6050 limit ${DeviceStatus.tiltLimitDegrees.toStringAsFixed(1)}°'
              : '$tiltWord · $lastKnown',
          valueColor: _valueColor(s.tiltLevel),
          accentColor: _accent(s.tiltLevel),
          onTap: () => openSensor(SensorKind.tilt),
        ),
        const SizedBox(height: 14),
        _AlarmCard(status: s, onTestAlarm: () => _testAlarm(context)),
      ],
    );
  }

  static Widget _heroIcon(StatusLevel level) => switch (level) {
        StatusLevel.stable => SvgPicture.asset('assets/icons/shield_check.svg', width: 72, height: 72),
        StatusLevel.watch || StatusLevel.high =>
          Icon(Icons.warning_rounded, size: 76, color: LevelStyle.of(level).strong),
        StatusLevel.critical => Center(
            child: SvgPicture.asset(
              'assets/icons/siren.svg',
              width: 64,
              colorFilter: const ColorFilter.mode(AppColors.criticalContainer, BlendMode.srcIn),
            ),
          ),
      };

  /// A single-colour PNG icon painted in [color].
  static Widget _maskIcon(String asset, Color color) => Image.asset(
        asset,
        width: 52,
        height: 52,
        color: color,
        colorBlendMode: BlendMode.srcIn,
      );

  /// Sensors past normal get a coloured border and icon (Figma Watch/High).
  static Color? _accent(StatusLevel level) =>
      level == StatusLevel.stable ? null : LevelStyle.of(level).strong;

  static Color _valueColor(StatusLevel level) =>
      level == StatusLevel.stable ? AppColors.ink : LevelStyle.of(level).strong;

  static String _levelWord(StatusLevel level) => switch (level) {
        StatusLevel.stable => 'Normal',
        StatusLevel.watch => 'Watch',
        StatusLevel.high => 'High',
        StatusLevel.critical => 'Critical',
      };

  static String _soilCaption(StatusLevel level) => switch (level) {
        StatusLevel.stable || StatusLevel.watch =>
          '${_levelWord(level)} · warning at ${DeviceStatus.soilWarningPercent}%',
        StatusLevel.high => 'High · critical at ${DeviceStatus.soilCriticalPercent}%',
        StatusLevel.critical => 'Critical · above ${DeviceStatus.soilCriticalPercent}%',
      };
}

/// Crossfades [child] when [level] changes: a fade in place, no movement.
class _LevelFade extends StatelessWidget {
  const _LevelFade({required this.level, required this.duration, required this.child});

  final StatusLevel level;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // AnimatedSwitcher fades between old and new children whenever the
    // child's key changes. The key is the level, so only level changes fade.
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.levelCurve,
      switchOutCurve: AppMotion.levelCurve,
      child: KeyedSubtree(key: ValueKey(level), child: child),
    );
  }
}

/// "● Node GP‑01 · Live   ·   GSM 3/4   ·   Battery 82%"
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.status});

  final DeviceStatus status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final text = 'Node ${s.nodeId} · Live'
        '   ·   GSM ${s.gsmBars}/${DeviceStatus.maxGsmBars}'
        '   ·   Battery ${s.batteryPercent}%';
    final dot = s.level == StatusLevel.stable ? null : LevelStyle.of(s.level).strong;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/icons/dot.svg',
          width: 8,
          height: 8,
          colorFilter: dot == null ? null : ColorFilter.mode(dot, BlendMode.srcIn),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: _normalLineHeight,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dark banner shown while the node is offline.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.since});

  final DateTime since;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: AppColors.banner, borderRadius: BorderRadius.circular(10)),
      child: Text(
        'Node offline since ${formatClock(since)}. The siren and LEDs at the site still '
        'work without internet.',
        style: const TextStyle(fontSize: 12, height: 14 / 12, fontWeight: FontWeight.w500, color: AppColors.surface),
      ),
    );
  }
}

/// The rounded "next step" chip under the title. Its style follows the
/// level: white (Stable), coral outline (Watch), solid red (High), maroon
/// (Critical, tappable: reopens the alert).
class _NextStepPill extends StatelessWidget {
  const _NextStepPill({required this.level, this.onTap});

  final StatusLevel level;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (String label, Widget icon, Color bg, Color fg, Color border) = switch (level) {
      StatusLevel.stable => (
          'No action needed',
          SizedBox(
            width: 16,
            height: 16,
            child: Stack(children: [
              Positioned(left: 1.567, top: 2.9, child: SvgPicture.asset('assets/icons/check.svg')),
            ]),
          ),
          AppColors.surface,
          AppColors.ink,
          AppColors.outline,
        ),
      StatusLevel.watch => (
          'Prepare your go-bag and route',
          const Icon(Icons.work_outline_rounded, size: 16, color: AppColors.watchStrong),
          AppColors.surface,
          AppColors.watchStrong,
          AppColors.watchStrong,
        ),
      StatusLevel.high => (
          'Get ready to evacuate',
          const Icon(Icons.logout_rounded, size: 16, color: AppColors.onBrand),
          AppColors.brand,
          AppColors.onBrand,
          AppColors.brand,
        ),
      StatusLevel.critical => (
          'Open alert',
          const Icon(Icons.open_in_full_rounded, size: 16, color: AppColors.criticalOn),
          AppColors.criticalContainer,
          AppColors.criticalOn,
          AppColors.criticalContainer,
        ),
    };

    final pill = Container(
      padding: const EdgeInsets.fromLTRB(16, 9, 18, 9),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, height: _normalLineHeight, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? pill : Pressable(onTap: onTap, child: pill);
  }
}

/// The "Local alarm" card: what's sounding at the site, SMS progress, and a
/// Test alarm button when all is calm.
class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.status, required this.onTestAlarm});

  final DeviceStatus status;
  final VoidCallback onTestAlarm;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final sms = 'SMS sent ${s.smsSent} of ${s.smsTotal}';
    final String text;
    if (s.sirenOn) {
      text = 'Siren on at the site · $sms';
    } else if (s.level == StatusLevel.watch) {
      text = 'Buzzer pulsing at the site · $sms';
    } else {
      text = 'Siren on standby · ${s.smsSent > 0 ? sms : 'on-site LED normal'}';
    }
    final color = s.level == StatusLevel.stable ? AppColors.ink : LevelStyle.of(s.level).strong;

    return Container(
      constraints: const BoxConstraints(minHeight: 64), // grows with big text
      padding: const EdgeInsets.fromLTRB(15, 6, 13, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/siren.svg',
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: color),
            ),
          ),
          if (s.level == StatusLevel.stable) ...[
            const SizedBox(width: 8),
            AppButton(
              label: 'Test alarm',
              variant: AppButtonVariant.outlined,
              minWidth: 88,
              horizontalPadding: 10,
              height: 36,
              fontSize: 13,
              onPressed: onTestAlarm,
            ),
          ],
        ],
      ),
    );
  }
}
