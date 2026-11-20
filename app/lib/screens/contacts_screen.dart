import 'package:flutter/material.dart';

import '../data/status_repository.dart';
import '../models/settings.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/sub_screen_scaffold.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<AlertContact>? _contacts;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final contacts = await getContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts;
    return SubScreenScaffold(
      title: 'Alert Contacts',
      children: [
        const InfoBanner(
          icon: Icons.info_outline_rounded,
          warning: true,
          text: 'This firmware has no GSM/SMS service. Stored contacts will not receive device alerts.',
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Column(
            children: [
              Text('Could not load contacts: $_error'),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else if (contacts == null)
          const Center(child: CircularProgressIndicator(color: AppColors.brand))
        else if (contacts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No contacts are stored for this node.',
              textAlign: TextAlign.center,
            ),
          )
        else
          GroupedCard(
            children: [
              for (final contact in contacts)
                ListRow(
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      contact.initials,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  title: contact.name,
                  subtitle: contact.phone,
                  bottom: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      TagChip(contact.role.label),
                      TagChip(contact.alertLevel.label),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
