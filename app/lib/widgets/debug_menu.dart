import 'package:flutter/material.dart';

import '../data/status_repository.dart';
import '../models/device_status.dart';
import '../models/notifications.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/level_style.dart';
import 'app_button.dart';
import 'common.dart';
import 'pressable.dart';

/// TEMPORARY (debug builds only): a small floating "DEBUG" button that opens
/// a menu to switch the mock risk level and send test notifications.
/// Delete this file and its one use in `main_shell.dart` before release.
class DebugMenuButton extends StatelessWidget {
  const DebugMenuButton({super.key, required this.level, required this.onSetLevel});

  final StatusLevel? level;
  final ValueChanged<StatusLevel> onSetLevel;

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Debug menu (temporary)',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Debug builds only. Changes the sample data.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            const SectionTitle('Risk level'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in StatusLevel.values)
                  SelectChip(
                    key: ValueKey('debug-level-${l.name}'),
                    label: LevelStyle.of(l).label,
                    selected: l == level,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onSetLevel(l);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const SectionTitle('Notifications'),
            AppButton(
              label: 'Send test critical alert',
              icon: Icons.notifications_active_outlined,
              onPressed: () => _sendTest(sheetContext, NotificationType.critical),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Send test warning',
              variant: AppButtonVariant.outlined,
              onPressed: () => _sendTest(sheetContext, NotificationType.high),
            ),
            if (!NotificationService.isSupported)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'System notifications only work on an Android phone. The test still '
                  'appears in the in-app Notifications list.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTest(BuildContext context, NotificationType type) async {
    final critical = type == NotificationType.critical;
    final title = critical ? 'TEST · Combined Hazard Alert' : 'TEST · Landslide Risk: High';
    const body = 'This is a test from the debug menu. No action needed.';
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await addNotification(type: type, title: title, body: body);
    await NotificationService.show(type, title, body);
    messenger.showSnackBar(const SnackBar(content: Text('Test notification sent.')));
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const ValueKey('debug-menu'),
      onTap: () => _open(context),
      semanticLabel: 'Debug menu',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.debug,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'DEBUG · ${level?.name ?? '…'}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onBrand),
        ),
      ),
    );
  }
}
