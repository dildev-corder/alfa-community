import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/location_profile.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key, required this.profile});

  final LocationProfile profile;

  static const _contacts = [
    _EmergencyContact('Police emergency', '119', Icons.local_police_rounded),
    _EmergencyContact(
        'Ambulance / hospital', '1990', Icons.local_hospital_rounded),
    _EmergencyContact(
      'Disaster Management Centre',
      '117',
      Icons.crisis_alert_rounded,
    ),
    _EmergencyContact('Wildlife office', '1992', Icons.forest_rounded),
    _EmergencyContact('Local council', '1919', Icons.account_balance_rounded),
    _EmergencyContact(
      'Grama Niladhari office',
      '1919',
      Icons.holiday_village_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        const Text(
          'Emergency contacts',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          profile.isLive
              ? 'Contacts shown for nearby community response.'
              : 'Core Sri Lanka emergency contacts for low-data use.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF123C2B),
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Row(
            children: [
              Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 34),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Save these contacts for police, hospital, disaster, wildlife, local council, and village officer support.',
                  style: TextStyle(color: Colors.white, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final contact in _contacts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(contact.icon)),
                title: Text(contact.label),
                subtitle: Text(contact.number),
                trailing: FilledButton.tonalIcon(
                  onPressed: () => _call(contact.number),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    await launchUrl(uri);
  }
}

class _EmergencyContact {
  const _EmergencyContact(this.label, this.number, this.icon);

  final String label;
  final String number;
  final IconData icon;
}
