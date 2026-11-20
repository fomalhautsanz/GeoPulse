import 'package:flutter/material.dart';

import '../data/status_repository.dart';
import '../models/notifications.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/time_format.dart';
import '../widgets/common.dart';
import '../widgets/notification_badge.dart';
import '../widgets/pressable.dart';
import '../widgets/sub_screen_scaffold.dart';

/// "Notifications · In-app list" in Figma, opened from the bell. Unread
/// items are grey with a red dot; tapping one marks it read, and a critical
/// one opens the Critical alert.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await getNotifications();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _open(AppNotification n) async {
    try {
      await markNotificationRead(n.id);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update notification: $error')),
        );
      }
      return;
    }
    if (n.type == NotificationType.critical) {
      // The same action as tapping a critical system notification.
      (NotificationService.onOpenCritical ??
              NotificationService.fallbackOpenCritical)
          ?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final unread = items?.where((n) => !n.read).length ?? 0;
    final groups = <String, List<AppNotification>>{};
    for (final n in items ?? const <AppNotification>[]) {
      groups.putIfAbsent(formatDayLabel(n.time), () => []).add(n);
    }

    return SubScreenScaffold(
      title: 'Notifications',
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        if (_error != null)
          Column(
            children: [
              Text('Could not load notifications: $_error'),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else if (items == null)
          const Center(child: CircularProgressIndicator(color: AppColors.brand))
        else ...[
          Row(
            children: [
              Text(
                unread == 0 ? 'All caught up' : '$unread unread',
                style: const TextStyle(fontSize: 13, color: AppColors.ink),
              ),
              const Spacer(),
              if (unread > 0)
                Pressable(
                  onTap: () async {
                    try {
                      await markAllNotificationsRead();
                      await _load();
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not update notifications: $error',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('No notifications yet.', textAlign: TextAlign.center),
            ),
          for (final entry in groups.entries) ...[
            GroupLabel(entry.key),
            for (final n in entry.value) ...[
              _NotificationCard(item: n, onTap: () => _open(n)),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = item;
    return Semantics(
      label: n.read ? null : 'Unread',
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: n.read ? AppColors.surface : AppColors.card,
            border: n.read ? Border.all(color: AppColors.outline) : null,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotificationBadge(type: n.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatClock(n.time),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        if (!n.read) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.unreadDot,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
