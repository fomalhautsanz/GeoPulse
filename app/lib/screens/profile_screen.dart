import 'package:flutter/material.dart';

import '../data/auth_repository.dart' as auth;
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/fade_route.dart';
import '../widgets/sub_screen_scaffold.dart';
import 'landing_screen.dart';

/// Profile (not designed in Figma yet, so it follows the Settings style):
/// name, role, barangay, phone, and Log out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logOut(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message:
          'You won’t get app alerts on this phone until you log in again. '
          'The connected firmware does not send SMS alerts.',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !context.mounted) return;
    await auth.logOut();
    if (!context.mounted) return;
    // Back to Landing, removing every screen of the logged-in app.
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute<void>(context, const LandingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    final initials = (user?.name ?? '?')
        .replaceAll(RegExp(r'[\[\]]'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return SubScreenScaffold(
      title: 'Profile',
      bottom: AppButton(
        label: 'Log out',
        icon: Icons.logout_rounded,
        variant: AppButtonVariant.outlined,
        onPressed: () => _logOut(context),
      ),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.watchContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user?.name ?? 'Not logged in',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        if (user != null) Center(child: TagChip(user.role.label)),
        const SizedBox(height: 22),
        GroupedCard(
          children: [
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Role',
              value: user?.role.label ?? '–',
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Barangay / site',
              value: user?.barangay ?? '–',
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user?.phone ?? '–',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const InfoBanner(
          icon: Icons.info_outline_rounded,
          text:
              'Editing your profile will come later. Your role decides which alerts and '
              'device controls you see.',
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconBadge(
            icon: icon,
            background: AppColors.watchContainer,
            foreground: AppColors.brand,
            size: 36,
            iconSize: 20,
            rounded: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
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
