import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/community_report.dart';
import '../models/location_profile.dart';
import '../services/community_report_store.dart';
import '../services/location_name_service.dart';

class CitizenWorkScreen extends StatefulWidget {
  const CitizenWorkScreen({
    super.key,
    required this.user,
    required this.profile,
  });

  final AppUser user;
  final LocationProfile profile;

  @override
  State<CitizenWorkScreen> createState() => _CitizenWorkScreenState();
}

class _CitizenWorkScreenState extends State<CitizenWorkScreen> {
  final _store = const CommunityReportStore();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _picker = ImagePicker();
  final _locationNames = const LocationNameService();
  CommunityReportType _type = CommunityReportType.garbageOverflow;
  late LocationProfile _selectedProfile;
  String? _photoPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedProfile = widget.profile;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 68,
      maxWidth: 1280,
    );
    if (image == null || !mounted) return;
    setState(() => _photoPath = image.path);
  }

  Future<void> _submitReport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final report = await _store.createIssueReport(
        citizen: widget.user,
        profile: _selectedProfile,
        type: _type,
        description: _descriptionController.text,
        contactNumber: _contactController.text,
        photoPath: _photoPath ?? '',
      );
      _descriptionController.clear();
      _contactController.clear();
      if (!mounted) return;
      setState(() {
        _photoPath = null;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report ${report.id} sent to officers.')),
      );
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    }
  }

  void _useLowDataPhotoFallback() {
    setState(() => _photoPath = 'Text-only low-data report');
  }

  @override
  Widget build(BuildContext context) {
    final hasGps = widget.profile.latitude != null &&
        widget.profile.longitude != null &&
        widget.profile.isLive;
    final selectedHasGps =
        _selectedProfile.latitude != null && _selectedProfile.longitude != null;
    final selectedArea = _locationNames.nameForProfile(_selectedProfile);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        const Text(
          'Public issue reporting',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text('Simple guided reporting for citizen safety response.'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepTitle(
                number: '1',
                title: 'Choose issue type',
                subtitle: 'Matches the survey requirement categories.',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<CommunityReportType>(
                initialValue: _type,
                items: [
                  for (final type in CommunityReportType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_rounded),
                ),
              ),
              const SizedBox(height: 18),
              const _StepTitle(
                number: '2',
                title: 'Describe what happened',
                subtitle: 'Officers need a clear description and contact.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Example: Road edge damaged near school bridge.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact number',
                  prefixIcon: Icon(Icons.call_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              const _StepTitle(
                number: '3',
                title: 'Pin location and add evidence',
                subtitle: 'Move the pin to the exact disaster or issue place.',
              ),
              const SizedBox(height: 10),
              _ReportPinMap(
                profile: _selectedProfile,
                areaName: selectedArea,
                onChanged: (profile) => setState(() {
                  _selectedProfile = profile;
                }),
              ),
              const SizedBox(height: 12),
              _RequirementRow(
                icon: selectedHasGps
                    ? Icons.location_on_rounded
                    : Icons.location_off_rounded,
                label: 'Pinned area',
                value: selectedHasGps
                    ? '$selectedArea (${_selectedProfile.coordinates})'
                    : 'Select a pin location',
                ok: selectedHasGps,
              ),
              if (!hasGps)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Live GPS unavailable. You can still place the pin manually.',
                    style: TextStyle(color: Color(0xFF8A5A00)),
                  ),
                ),
              _RequirementRow(
                icon: Icons.schedule_rounded,
                label: 'Date and time',
                value: DateTime.now().toLocal().toString(),
                ok: true,
              ),
              _RequirementRow(
                icon: Icons.photo_camera_rounded,
                label: 'Photo evidence',
                value: _photoPath ?? 'Required before submit',
                ok: _photoPath != null,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Capture photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _useLowDataPhotoFallback,
                    icon: const Icon(Icons.sms_rounded),
                    label: const Text('Low-data fallback'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submitReport,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Submit public issue report'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'My reports',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<CommunityReport>>(
          stream: _store.watch(viewer: widget.user, onlyMine: true),
          builder: (context, snapshot) {
            final reports = snapshot.data ?? const [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (reports.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No reports yet.'),
                ),
              );
            }
            return Column(
              children: [
                for (final report in reports)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReportTile(report: report),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReportPinMap extends StatelessWidget {
  const _ReportPinMap({
    required this.profile,
    required this.areaName,
    required this.onChanged,
  });

  final LocationProfile profile;
  final String areaName;
  final ValueChanged<LocationProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final lat = profile.latitude ?? 7.2906;
    final lng = profile.longitude ?? 80.6337;
    final normalizedX = ((lng - 79.6) / 2.6).clamp(0.08, 0.92);
    final normalizedY = (1 - ((lat - 5.9) / 3.9)).clamp(0.08, 0.92);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 210.0;
        return GestureDetector(
          onTapDown: (details) {
            final x = (details.localPosition.dx / width).clamp(0.0, 1.0);
            final y = (details.localPosition.dy / height).clamp(0.0, 1.0);
            final nextLng = 79.6 + x * 2.6;
            final nextLat = 5.9 + (1 - y) * 3.9;
            onChanged(
              LocationProfile(
                label: const LocationNameService().nameForCoordinates(
                  nextLat,
                  nextLng,
                  fallback: 'Pinned community location',
                ),
                latitude: nextLat,
                longitude: nextLng,
                isLive: false,
              ),
            );
          },
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDDF4E7), Color(0xFFEAF3FF)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFD6E5DD)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 22,
                  top: 18,
                  child: Text(
                    'Tap map to locate report pin',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Positioned(
                  right: 22,
                  bottom: 18,
                  child: Text(
                    areaName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                for (final marker in const [
                  ('Kandy', 0.40, 0.45),
                  ('Badulla', 0.58, 0.55),
                  ('Rathnapura', 0.36, 0.70),
                  ('Colombo', 0.18, 0.65),
                ])
                  Positioned(
                    left: marker.$2 * width,
                    top: marker.$3 * height,
                    child: Text(
                      marker.$1,
                      style: const TextStyle(
                        color: Color(0xFF527065),
                        fontSize: 11,
                      ),
                    ),
                  ),
                Positioned(
                  left: normalizedX * width - 18,
                  top: normalizedY * height - 34,
                  child: const Icon(
                    Icons.location_pin,
                    color: Color(0xFFC84630),
                    size: 42,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: const Color(0xFF194D36),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF667168)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: ok ? const Color(0xFF1D6B49) : Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$label: $value', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final CommunityReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(_iconFor(report.type)),
        title: Text(report.type.label),
        subtitle: Text(
          '${report.message}\n${report.district} | ${report.status.label}',
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _iconFor(CommunityReportType type) => switch (type) {
        CommunityReportType.flood => Icons.flood_rounded,
        CommunityReportType.landslide => Icons.terrain_rounded,
        CommunityReportType.elephantMovement => Icons.forest_rounded,
        CommunityReportType.garbageOverflow ||
        CommunityReportType.binFull ||
        CommunityReportType.illegalDumping ||
        CommunityReportType.damagedBin =>
          Icons.delete_sweep_rounded,
        CommunityReportType.roadDamage => Icons.add_road_rounded,
        CommunityReportType.crime => Icons.local_police_rounded,
        CommunityReportType.waterIssue => Icons.water_drop_rounded,
        CommunityReportType.other => Icons.report_problem_rounded,
      };
}
