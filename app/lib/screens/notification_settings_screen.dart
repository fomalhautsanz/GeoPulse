import 'package:flutter/material.dart';

import '../data/status_repository.dart';
import '../models/notifications.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/notification_badge.dart';
import '../widgets/sub_screen_scaffold.dart';

/// "Notifications · Notification Settings" in Figma. Critical alerts are
/// always on; the rest can be switched off. Changes save immediately.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    getNotificationPrefs().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  void _update(NotificationPrefs prefs) {
    setState(() => _prefs = prefs);
    saveNotificationPrefs(prefs);
  }

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    return SubScreenScaffold(
      title: 'Notification Settings',
      children: p == null
          ? const [Center(child: CircularProgressIndicator(color: AppColors.brand))]
          : [
              const SectionTitle('Alerts'),
              GroupedCard(
                children: [
                  ListRow(
                    leading: const NotificationBadge(type: NotificationType.critical, size: 36),
                    title: 'Critical alerts',
                    subtitle: 'Always on. Alarm sound, ignores silent mode and Do Not Disturb.',
                    trailing: const AppSwitch(value: true, onChanged: null, locked: true),
                  ),
                  ListRow(
                    leading: const IconBadge(
                      icon: Icons.warning_amber_rounded,
                      background: AppColors.brand,
                      foreground: AppColors.onBrand,
                      size: 36,
                    ),
                    title: 'Warnings (Watch and High)',
                    subtitle: 'Sound and vibration',
                    trailing: AppSwitch(value: p.warnings, onChanged: (v) => _update(p.copyWith(warnings: v))),
                  ),
                  ListRow(
                    leading: const NotificationBadge(type: NotificationType.backToStable, size: 36),
                    title: 'Back to Stable',
                    subtitle: 'Quiet notification when risk clears',
                    trailing: AppSwitch(value: p.backToStable, onChanged: (v) => _update(p.copyWith(backToStable: v))),
                  ),
                  // Android 14+ asks separately before an app may show
                  // full-screen alarms over the lock screen.
                  if (NotificationService.isSupported)
                    ListRow(
                      leading: const IconBadge(
                        icon: Icons.screen_lock_portrait_outlined,
                        background: AppColors.card,
                        foreground: AppColors.ink,
                        size: 36,
                      ),
                      title: 'Full-screen critical alarms',
                      subtitle: 'Let critical alerts open over the lock screen',
                      trailing: ListRow.chevron,
                      onTap: NotificationService.requestFullScreenPermission,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionTitle('Device'),
              GroupedCard(
                children: [
                  ListRow(
                    leading: const NotificationBadge(type: NotificationType.offline, size: 36),
                    title: 'Device offline or back online',
                    subtitle: 'For DRRM personnel and device keepers',
                    trailing: AppSwitch(value: p.deviceOnline, onChanged: (v) => _update(p.copyWith(deviceOnline: v))),
                  ),
                  ListRow(
                    leading: const NotificationBadge(type: NotificationType.lowBattery, size: 36),
                    title: 'Low battery',
                    subtitle: 'At 20% and 10%',
                    trailing: AppSwitch(value: p.lowBattery, onChanged: (v) => _update(p.copyWith(lowBattery: v))),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const InfoBanner(
                icon: Icons.notifications_none_rounded,
                text: 'App notifications need internet. SMS alerts from the device still arrive without it.',
              ),
            ],
    );
  }
}
