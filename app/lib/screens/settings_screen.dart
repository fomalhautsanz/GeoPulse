import 'package:flutter/material.dart';

import '../data/auth_repository.dart' as auth;
import '../data/status_repository.dart';
import '../models/device_status.dart';
import '../models/notifications.dart';
import '../models/settings.dart';
import '../services/alert_sound_service.dart';
import '../state/status_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/common.dart';
import '../widgets/fade_route.dart';
import 'contacts_screen.dart';
import 'notification_settings_screen.dart';
import 'profile_screen.dart';
import 'thresholds_screen.dart';

/// "Settings · Device and connectivity" in Figma: the node's health at the
/// top, then rows that open the other settings screens.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DeviceInfo? _info;
  Thresholds? _thresholds;
  int? _contactCount;
  NotificationPrefs? _prefs;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        getDeviceInfo(),
        getThresholds(),
        getContacts(),
        getNotificationPrefs(),
      ]);
      if (!mounted) return;
      setState(() {
        _info = results[0] as DeviceInfo;
        _thresholds = results[1] as Thresholds;
        _contactCount = (results[2] as List).length;
        _prefs = results[3] as NotificationPrefs;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// Opens [screen], then reloads (its settings may have changed).
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(fadeRoute<void>(context, screen));
    _load();
  }

  Future<void> _testLaptopAlertSound() async {
    try {
      await AlertSoundService.playTestSound();
      if (mounted) {
        showMessage(context, 'Laptop alert sound played.');
      }
    } catch (e, stackTrace) {
      debugPrint('Test laptop alert sound failed: $e\n$stackTrace');
      if (mounted) {
        showMessage(
          context,
          'Could not play sound. Check the laptop volume and browser permissions.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = StatusScope.of(context).status;
    final t = _thresholds;
    final user = auth.currentUser;

    Widget tile(IconData icon) => IconBadge(
      icon: icon,
      background: AppColors.watchContainer,
      foreground: AppColors.brand,
      size: 36,
      iconSize: 20,
      rounded: true,
    );

    return AppScaffold(
      title: 'Settings',
      currentTab: AppTab.settings,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          _DeviceCard(info: _info, status: status),
          if (_error != null) ...[
            const SizedBox(height: 8),
            InfoBanner(
              icon: Icons.error_outline_rounded,
              warning: true,
              text: 'Could not load settings: $_error',
            ),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
          const SizedBox(height: 14),
          GroupedCard(
            children: [
              ListRow(
                leading: tile(Icons.speed_rounded),
                title: 'Alert thresholds',
                subtitle: t == null
                    ? ' '
                    : 'Soil ${t.soilWatchPercent}/${t.soilCriticalPercent}% · vibration '
                          '${t.vibrationPerMin}/min · tilt ${t.tiltDegrees.toStringAsFixed(1)}°',
                trailing: ListRow.chevron,
                onTap: () => _open(const ThresholdsScreen()),
              ),
              ListRow(
                leading: tile(Icons.chat_bubble_outline_rounded),
                title: 'SMS alert contacts',
                subtitle: _contactCount == null
                    ? ' '
                    : '$_contactCount stored · SMS unsupported',
                trailing: ListRow.chevron,
                onTap: () => _open(const ContactsScreen()),
              ),
              ListRow(
                leading: tile(Icons.notifications_none_rounded),
                title: 'Notifications',
                subtitle: _prefs == null
                    ? ' '
                    : 'Critical on · warnings ${_prefs!.warnings ? 'on' : 'off'}',
                trailing: ListRow.chevron,
                onTap: () => _open(const NotificationSettingsScreen()),
              ),
              if (AlertSoundService.isSupported)
                ListRow(
                  leading: tile(Icons.volume_up_outlined),
                  title: 'Test laptop alert sound',
                  subtitle:
                      'Test and enable sound for Watch or higher soil readings',
                  trailing: ListRow.chevron,
                  onTap: _testLaptopAlertSound,
                ),
              ListRow(
                leading: tile(Icons.person_outline_rounded),
                title: 'Profile and role',
                subtitle: user == null
                    ? 'Not logged in'
                    : '${user.role.label} · ${user.barangay}',
                trailing: ListRow.chevron,
                onTap: () => _open(const ProfileScreen()),
              ),
              ListRow(
                leading: tile(Icons.menu_book_outlined),
                title: 'Safety guide',
                subtitle: 'Not available in this app build',
                trailing: ListRow.chevron,
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.info, required this.status});

  final DeviceInfo? info;
  final DeviceStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final online = s?.online ?? false;
    final battery = s?.batteryPercent;
    final wifiBars = s?.wifiBars;

    return OutlinedCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.memory,
                background: AppColors.ink,
                foreground: AppColors.surface,
                size: 44,
                iconSize: 24,
                rounded: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info?.name ?? 'GeoPulse Node',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      info == null
                          ? ' '
                          : '${info!.board} · firmware ${info!.firmware}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: online ? AppColors.card : AppColors.watchContainer,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Text(
                  online ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: online ? AppColors.ink : AppColors.watchOn,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatTile(
                icon: Icons.battery_5_bar_rounded,
                label: 'Battery',
                value: battery == null ? 'Not reported' : '$battery%',
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.wifi_rounded,
                label: 'Wi-Fi',
                value: wifiBars == null
                    ? 'Not reported'
                    : '$wifiBars of ${DeviceStatus.maxWifiBars} bars',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatTile(
                icon: online ? Icons.cloud_outlined : Icons.cloud_off_outlined,
                label: 'Firebase',
                value: s == null
                    ? 'No data'
                    : online
                    ? 'Connected'
                    : 'Offline',
              ),
              const SizedBox(width: 8),
              const _StatTile(
                icon: Icons.volume_up_outlined,
                label: 'Site outputs',
                value: 'Not reported',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.ink),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Battery level and on-site alarm hardware are not monitored by this firmware.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 17 / 12,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
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
