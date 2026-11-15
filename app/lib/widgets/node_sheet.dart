import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'app_button.dart';
import 'level_chip.dart';

/// Slides the node details sheet up from the bottom (300 ms, Figma curve).
/// Drag it down or tap outside to close. With animations off it appears and
/// disappears instantly.
Future<void> showNodeSheet(BuildContext context, DeviceStatus status, {VoidCallback? onViewReadings}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    enableDrag: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    sheetAnimationStyle: AppMotion.reduced(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: AppMotion.sheet,
            reverseDuration: AppMotion.sheet,
            curve: AppMotion.sheetCurve,
          ),
    builder: (_) => NodeSheet(status: status, onViewReadings: onViewReadings),
  );
}

/// The content of the map's node sheet ("Node sheet" in Figma).
class NodeSheet extends StatelessWidget {
  const NodeSheet({super.key, required this.status, this.onViewReadings});

  final DeviceStatus status;

  /// "View readings": closes the sheet, then this runs (opens Sensors).
  final VoidCallback? onViewReadings;

  void _notYet(BuildContext context, String what) {
    // Grab the messenger before closing the sheet, then show the message on
    // the screen underneath.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what isn’t available yet.')));
  }

  @override
  Widget build(BuildContext context) {
    final s = status;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 14 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Node ${s.nodeId}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Placeholder from Figma: location isn't in the data yet.
                    const Text(
                      '[Sitio / Barangay name] · 0.6 km from you',
                      style: TextStyle(fontSize: 12, height: 1.172, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              LevelChip(level: s.level),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(value: '${s.soilMoisturePercent}%', label: 'Soil', level: s.soilLevel),
              const SizedBox(width: 8),
              _Stat(value: '${s.vibrationPerMin}/min', label: 'Vibration', level: s.vibrationLevel),
              const SizedBox(width: 8),
              _Stat(value: '${s.tiltDegrees.toStringAsFixed(1)}°', label: 'Tilt', level: s.tiltLevel),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'View readings',
                  variant: AppButtonVariant.outlined,
                  height: 46,
                  onPressed: () {
                    final open = onViewReadings;
                    if (open == null) return _notYet(context, 'Sensor readings');
                    Navigator.of(context).pop();
                    open();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Route to evac area',
                  icon: Icons.navigation_outlined,
                  height: 46,
                  onPressed: () => _notYet(context, 'Routing'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.level});

  final String value;
  final String label;
  final StatusLevel level;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                height: 1.172,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                height: 1.172,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
