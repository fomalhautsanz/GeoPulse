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
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationPrefs? _prefs;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await getNotificationPrefs();
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _update(NotificationPrefs prefs) async {
    final previous = _prefs;
    setState(() => _prefs = prefs);
    try {
      await saveNotificationPrefs(prefs);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _prefs = previous;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    return SubScreenScaffold(
      title: 'Notification Settings',
      children: _error != null
          ? [
              Text('Could not load notification settings: $_error'),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ]
          : p == null
          ? const [
              Center(child: CircularProgressIndicator(color: AppColors.brand)),
            ]
          : [
              const SectionTitle('Alerts'),
              GroupedCard(
                children: [
                  ListRow(
                    leading: const NotificationBadge(
                      type: NotificationType.critical,
                      size: 36,
                    ),
                    title: 'Critical alerts',
                    subtitle: 'Shown on critical status changes while connected; system permission is required.',
                    trailing: const AppSwitch(
                      value: true,
                      onChanged: null,
                      locked: true,
                    ),
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
                    trailing: AppSwitch(
                      value: p.warnings,
                      onChanged: (v) => _update(p.copyWith(warnings: v)),
                    ),
                  ),
                  ListRow(
                    leading: const NotificationBadge(
                      type: NotificationType.backToStable,
                      size: 36,
                    ),
                    title: 'Back to Stable',
                    subtitle: 'Quiet notification when risk clears',
                    trailing: AppSwitch(
                      value: p.backToStable,
                      onChanged: (v) => _update(p.copyWith(backToStable: v)),
                    ),
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
                    leading: const NotificationBadge(
                      type: NotificationType.offline,
                      size: 36,
                    ),
                    title: 'Device offline or back online',
                    subtitle: 'When status changes while this app is connected',
                    trailing: AppSwitch(
                      value: p.deviceOnline,
                      onChanged: (v) => _update(p.copyWith(deviceOnline: v)),
                    ),
                  ),
                  ListRow(
                    leading: const NotificationBadge(
                      type: NotificationType.lowBattery,
                      size: 36,
                    ),
                    title: 'Low battery',
                    subtitle:
                        'Unavailable: this firmware reports no battery level',
                    trailing: const AppSwitch(
                      value: false,
                      onChanged: null,
                      locked: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const InfoBanner(
                icon: Icons.notifications_none_rounded,
                text: 'App notifications need an internet connection. This firmware does not send SMS.',
              ),
            ],
    );
  }
}
