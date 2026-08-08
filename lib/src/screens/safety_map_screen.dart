import 'package:flutter/material.dart';

import '../models/community_report.dart';
import '../models/location_profile.dart';
import '../services/community_report_store.dart';
import '../services/location_name_service.dart';

class SafetyMapScreen extends StatelessWidget {
  const SafetyMapScreen({super.key, required this.profile});

  final LocationProfile profile;
  static const _store = CommunityReportStore();

  static const _hotspots = [
    _SafetyHotspot(
      district: 'Ampara',
      title: 'Elephant movement and rural road safety',
      severity: 'High',
      color: Color(0xFF008956),
      icon: Icons.forest_rounded,
    ),
    _SafetyHotspot(
      district: 'Mahiyanganaya',
      title: 'Elephant alerts and rural road safety',
      severity: 'High',
      color: Color(0xFF008956),
      icon: Icons.forest_rounded,
    ),
    _SafetyHotspot(
      district: 'Nuwara Eliya',
      title: 'Landslide and mountain road warnings',
      severity: 'High',
      color: Color(0xFFB47A42),
      icon: Icons.terrain_rounded,
    ),
    _SafetyHotspot(
      district: 'Badulla',
      title: 'Landslide and mountain road warnings',
      severity: 'High',
      color: Color(0xFFB47A42),
      icon: Icons.terrain_rounded,
    ),
    _SafetyHotspot(
      district: 'Rathnapura',
      title: 'Flood and river overflow alerts',
      severity: 'High',
      color: Color(0xFF006EBC),
      icon: Icons.flood_rounded,
    ),
    _SafetyHotspot(
      district: 'Colombo',
      title: 'Garbage overflow, urban flood, traffic, and safety',
      severity: 'Medium',
      color: Color(0xFFE78A00),
      icon: Icons.location_city_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityReport>>(
      stream: _store.watch(),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const [];
        final activeReports = reports
            .where((report) => report.status != CommunityReportStatus.resolved)
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const Text(
              'Safety map',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text('Live citizen pins, disaster reports, and risk areas.'),
            const SizedBox(height: 18),
            _LiveSafetyMap(profile: profile, reports: activeReports),
            const SizedBox(height: 18),
            const Text(
              'Live citizen reports',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (activeReports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No live citizen pins yet.'),
                ),
              )
            else
              for (final report in activeReports)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReportPinCard(report: report),
                ),
            const SizedBox(height: 10),
            const Text(
              'Regional priority areas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final hotspot in _hotspots)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HotspotCard(hotspot: hotspot),
              ),
          ],
        );
      },
    );
  }
}

class _LiveSafetyMap extends StatelessWidget {
  const _LiveSafetyMap({required this.profile, required this.reports});

  final LocationProfile profile;
  final List<CommunityReport> reports;

  @override
  Widget build(BuildContext context) {
    final area = const LocationNameService().nameForProfile(profile);
    return Container(
      height: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123C2B), Color(0xFF1D6B49)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33123C2B),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 12,
            top: 16,
            child: _MapMarker(label: 'Ampara', color: Color(0xFF00C77B)),
          ),
          const Positioned(
            right: 28,
            top: 58,
            child: _MapMarker(label: 'Mahiyanganaya', color: Color(0xFF00C77B)),
          ),
          const Positioned(
            left: 92,
            top: 94,
            child: _MapMarker(label: 'Badulla', color: Color(0xFFFFC857)),
          ),
          const Positioned(
            right: 78,
            top: 130,
            child: _MapMarker(label: 'Nuwara Eliya', color: Color(0xFFFFC857)),
          ),
          const Positioned(
            left: 38,
            bottom: 44,
            child: _MapMarker(label: 'Rathnapura', color: Color(0xFF4FC3F7)),
          ),
          const Positioned(
            right: 18,
            bottom: 28,
            child: _MapMarker(label: 'Colombo', color: Color(0xFFFFA726)),
          ),
          for (final report in reports.take(12)) _ReportMapPin(report: report),
          Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              profile.isLive
                  ? 'Nearby area: $area'
                  : 'Live GPS will personalize nearby markers.',
              style: const TextStyle(color: Color(0xFFE7F2DA)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMapPin extends StatelessWidget {
  const _ReportMapPin({required this.report});

  final CommunityReport report;

  @override
  Widget build(BuildContext context) {
    final lat = report.latitude ?? 7.2;
    final lng = report.longitude ?? 80.7;
    final x = ((lng - 79.6) / 2.6).clamp(0.12, 0.88);
    final y = (1 - ((lat - 5.9) / 3.9)).clamp(0.12, 0.82);
    return Positioned(
      left: x * 300,
      top: y * 230,
      child: Icon(
        _iconFor(report.type),
        color: Colors.white,
        size: 30,
      ),
    );
  }
}

class _ReportPinCard extends StatelessWidget {
  const _ReportPinCard({required this.report});

  final CommunityReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconFor(report.type))),
        title: Text('${report.type.label} in ${report.district}'),
        subtitle: Text(
          '${report.message}\nPhoto: ${report.hasPhotoEvidence ? 'attached' : 'missing'} | Status: ${report.status.label}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _SafetyHotspot {
  const _SafetyHotspot({
    required this.district,
    required this.title,
    required this.severity,
    required this.color,
    required this.icon,
  });

  final String district;
  final String title;
  final String severity;
  final Color color;
  final IconData icon;
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.location_on_rounded, color: color, size: 34),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HotspotCard extends StatelessWidget {
  const _HotspotCard({required this.hotspot});

  final _SafetyHotspot hotspot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hotspot.color.withValues(alpha: 0.14),
          child: Icon(hotspot.icon, color: hotspot.color),
        ),
        title: Text(hotspot.district),
        subtitle: Text(hotspot.title),
        trailing: Chip(label: Text(hotspot.severity)),
      ),
    );
  }
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
