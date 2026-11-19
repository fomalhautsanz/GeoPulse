import 'package:flutter/material.dart';

import '../data/status_repository.dart';
import '../models/settings.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/pressable.dart';
import '../widgets/sub_screen_scaffold.dart';

/// "Settings · SMS alert contacts" in Figma: who gets SMS alerts from the
/// device, a preview of the message, and "Send test SMS to all".
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<AlertContact>? _contacts;
  String _preview = '';

  @override
  void initState() {
    super.initState();
    Future.wait([getContacts(), getSmsPreview()]).then((r) {
      if (!mounted) return;
      setState(() {
        _contacts = r[0] as List<AlertContact>;
        _preview = r[1] as String;
      });
    });
  }

  Future<void> _sendTest() async {
    final count = _contacts?.length ?? 0;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Send a test SMS?',
      message: 'A test message goes to all $count contacts through the device’s GSM '
          'module. Standard SMS charges may apply.',
      confirmLabel: 'Send test SMS',
    );
    if (!confirmed) return;
    await sendTestSms();
    if (mounted) showMessage(context, 'Test SMS sent to all $count contacts.');
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts;
    final length = _preview.length;
    final parts = length <= 160 ? 1 : (length / 153).ceil(); // long SMS split into 153-char parts

    return SubScreenScaffold(
      title: 'Alert Contacts',
      bottom: AppButton(
        label: 'Send test SMS to all',
        variant: AppButtonVariant.outlined,
        onPressed: contacts == null ? null : _sendTest,
      ),
      children: [
        const InfoBanner(
          icon: Icons.signal_cellular_alt_rounded,
          text: 'SMS goes out through the device’s GSM/LTE module, even without internet. '
              'It needs cellular signal at the site.',
        ),
        const SizedBox(height: 12),
        if (contacts == null)
          const Center(child: CircularProgressIndicator(color: AppColors.brand))
        else
          GroupedCard(
            children: [
              for (final c in contacts)
                ListRow(
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
                    child: Text(
                      c.initials,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ),
                  title: c.name,
                  subtitle: c.phone,
                  bottom: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [TagChip(c.role.label), TagChip(c.alertLevel.label, warning: true)],
                  ),
                  trailing: ListRow.chevron,
                  onTap: () => showNotYet(context, 'Editing contacts'),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Pressable(
          onTap: () => showNotYet(context, 'Adding contacts'),
          child: const DashedBorderBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 22, color: AppColors.ink),
                SizedBox(width: 8),
                Text('Add contact', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle('SMS preview'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
          child: Text(_preview, style: const TextStyle(fontSize: 14, height: 20 / 14, color: AppColors.ink)),
        ),
        const SizedBox(height: 6),
        Text(
          '$length / 160 characters · ${parts == 1 ? 'fits one SMS' : 'sent as $parts SMS'}',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}
