import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/community_report.dart';
import '../services/auth_service.dart';
import '../services/community_report_store.dart';

class AdminControlScreen extends StatefulWidget {
  const AdminControlScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
  final _store = const CommunityReportStore();
  final _auth = const AuthService();
  final _officerNameController = TextEditingController();
  final _officerIdController = TextEditingController();
  final _officerPhoneController = TextEditingController();
  final _officerPasswordController = TextEditingController();
  String _officerArea = 'All areas';
  final Set<CommunityReportType> _officerTypes = {CommunityReportType.other};
  bool _creatingOfficer = false;

  @override
  void initState() {
    super.initState();
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _officerNameController.dispose();
    _officerIdController.dispose();
    _officerPhoneController.dispose();
    _officerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createOfficer() async {
    if (_creatingOfficer) return;
    setState(() => _creatingOfficer = true);
    final result = await _auth.register(
      role: UserRole.officer,
      displayName: _officerNameController.text,
      identifier: _officerIdController.text,
      password: _officerPasswordController.text,
      officerArea: _officerArea,
      officerTypes: _officerTypes.map((type) => type.name).toList(),
      phoneNumber: _officerPhoneController.text,
    );
    if (!mounted) return;
    setState(() => _creatingOfficer = false);

    if (result.isSuccess) {
      _officerNameController.clear();
      _officerIdController.clear();
      _officerPhoneController.clear();
      _officerPasswordController.clear();
      _officerTypes
        ..clear()
        ..add(CommunityReportType.other);
      _officerArea = 'All areas';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Officer account created.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Officer creation failed.')),
    );
  }

  Future<void> _resolve(CommunityReport report) async {
    await _store.resolve(report, widget.user);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin control',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  Text('Monitor citizens, officers, and bin operations.'),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _OfficerCreateCard(
          nameController: _officerNameController,
          idController: _officerIdController,
          phoneController: _officerPhoneController,
          passwordController: _officerPasswordController,
          area: _officerArea,
          selectedTypes: _officerTypes,
          onAreaChanged: (value) => setState(() => _officerArea = value),
          onTypeChanged: (type, selected) => setState(() {
            if (selected) {
              _officerTypes.add(type);
            } else if (_officerTypes.length > 1) {
              _officerTypes.remove(type);
            }
          }),
          busy: _creatingOfficer,
          onCreate: _createOfficer,
        ),
        const SizedBox(height: 18),
        StreamBuilder<List<CommunityReport>>(
          stream: _store.watch(viewer: widget.user),
          builder: (context, snapshot) {
            final reports = snapshot.data ?? const [];
            final newReports = reports
                .where((report) =>
                    report.status == CommunityReportStatus.newReport)
                .length;
            final reviewed = reports
                .where(
                    (report) => report.status == CommunityReportStatus.reviewed)
                .length;
            final assigned = reports
                .where(
                    (report) => report.status == CommunityReportStatus.assigned)
                .length;
            final freed = reports
                .where(
                    (report) => report.status == CommunityReportStatus.binFreed)
                .length;
            final resolved = reports
                .where(
                    (report) => report.status == CommunityReportStatus.resolved)
                .length;

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _MetricCard(label: 'New', value: newReports)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _MetricCard(label: 'Reviewed', value: reviewed)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _MetricCard(label: 'Assigned', value: assigned)),
                    const SizedBox(width: 8),
                    Expanded(child: _MetricCard(label: 'Freed', value: freed)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _MetricCard(label: 'Resolved', value: resolved)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: 'All reports',
                        value: reports.length,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (reports.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No community reports yet.'),
                    ),
                  )
                else
                  for (final report in reports)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.rule_folder_rounded),
                          title: Text(report.type.label),
                          subtitle: Text(
                            '${report.status.label} | ${report.district} | ${report.createdByName}\n${report.message}',
                          ),
                          isThreeLine: true,
                          trailing:
                              report.status == CommunityReportStatus.resolved
                                  ? null
                                  : TextButton(
                                      onPressed: () => _resolve(report),
                                      child: const Text('Close'),
                                    ),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OfficerCreateCard extends StatelessWidget {
  const _OfficerCreateCard({
    required this.nameController,
    required this.idController,
    required this.phoneController,
    required this.passwordController,
    required this.area,
    required this.selectedTypes,
    required this.onAreaChanged,
    required this.onTypeChanged,
    required this.busy,
    required this.onCreate,
  });

  final TextEditingController nameController;
  final TextEditingController idController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final String area;
  final Set<CommunityReportType> selectedTypes;
  final ValueChanged<String> onAreaChanged;
  final void Function(CommunityReportType type, bool selected) onTypeChanged;
  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFEAF3EA),
                child: Icon(
                  Icons.badge_rounded,
                  color: Color(0xFF194D36),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create officer account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('Only admin can add field officers.'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Officer full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: idController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Employee ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Officer mobile number',
              helperText: 'Use country code, example +94771234567.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onCreate(),
            decoration: const InputDecoration(
              labelText: 'Temporary password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: area,
            items: const [
              'All areas',
              'Kandy',
              'Colombo',
              'Badulla',
              'Nuwara Eliya',
              'Rathnapura',
              'Ampara',
              'Mahiyanganaya',
            ]
                .map(
                  (area) => DropdownMenuItem(
                    value: area,
                    child: Text(area),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onAreaChanged(value);
            },
            decoration: const InputDecoration(
              labelText: 'Allocated officer area',
              prefixIcon: Icon(Icons.map_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Officer responsibility type',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in CommunityReportType.values)
                FilterChip(
                  label: Text(type.label),
                  selected: selectedTypes.contains(type),
                  onSelected: (selected) => onTypeChanged(type, selected),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onCreate,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create officer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
