import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/community_report.dart';
import '../services/community_report_store.dart';

class OfficerWorkScreen extends StatefulWidget {
  const OfficerWorkScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<OfficerWorkScreen> createState() => _OfficerWorkScreenState();
}

class _OfficerWorkScreenState extends State<OfficerWorkScreen> {
  final _store = const CommunityReportStore();

  void _refresh() => setState(() {});

  Future<void> _assign(CommunityReport report) async {
    await _store.assignToOfficer(report, widget.user);
  }

  Future<void> _review(CommunityReport report) async {
    await _store.markReviewed(report, widget.user);
  }

  Future<void> _markFree(CommunityReport report) async {
    await _store.markBinFree(report, widget.user);
  }

  Future<void> _resolve(CommunityReport report) async {
    await _store.resolve(report, widget.user);
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
                    'Officer work',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  Text('Live reports filtered by officer area and duty type.'),
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
        _OfficerScopeCard(user: widget.user),
        const SizedBox(height: 12),
        StreamBuilder<List<CommunityReport>>(
          stream: _store.watch(viewer: widget.user),
          builder: (context, snapshot) {
            final reports = snapshot.data ?? const [];
            final active = reports
                .where(
                    (report) => report.status != CommunityReportStatus.resolved)
                .toList();
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (active.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No active citizen reports.'),
                ),
              );
            }
            return Column(
              children: [
                for (final report in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OfficerReportCard(
                      report: report,
                      onReview: () => _review(report),
                      onAssign: () => _assign(report),
                      onMarkFree: () => _markFree(report),
                      onResolve: () => _resolve(report),
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

class _OfficerReportCard extends StatelessWidget {
  const _OfficerReportCard({
    required this.report,
    required this.onReview,
    required this.onAssign,
    required this.onMarkFree,
    required this.onResolve,
  });

  final CommunityReport report;
  final VoidCallback onReview;
  final VoidCallback onAssign;
  final VoidCallback onMarkFree;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(_iconFor(report.type))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.type.label,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text('Status: ${report.status.label}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(report.message),
            const SizedBox(height: 6),
            Text('Citizen: ${report.createdByName} | ${report.contactNumber}'),
            Text('Area: ${report.district}'),
            if (report.hasGpsLocation)
              Text(
                'Pinned location: ${report.latitude!.toStringAsFixed(5)}, ${report.longitude!.toStringAsFixed(5)}',
              ),
            Text('Photo: ${report.photoPath}'),
            if (report.assignedOfficerName != null)
              Text('Assigned: ${report.assignedOfficerName}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: report.status == CommunityReportStatus.newReport
                      ? onReview
                      : null,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Review'),
                ),
                OutlinedButton.icon(
                  onPressed: report.status == CommunityReportStatus.reviewed ||
                          report.status == CommunityReportStatus.newReport
                      ? onAssign
                      : null,
                  icon: const Icon(Icons.assignment_ind_rounded),
                  label: const Text('Assign to me'),
                ),
                if (report.type.isGarbageService)
                  FilledButton.icon(
                    onPressed: report.status == CommunityReportStatus.assigned
                        ? onMarkFree
                        : null,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Mark bin free'),
                  ),
                OutlinedButton.icon(
                  onPressed: report.status == CommunityReportStatus.binFreed ||
                          report.status == CommunityReportStatus.assigned
                      ? onResolve
                      : null,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Resolve'),
                ),
              ],
            ),
          ],
        ),
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

class _OfficerScopeCard extends StatelessWidget {
  const _OfficerScopeCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final area = user.officerArea?.trim().isNotEmpty == true
        ? user.officerArea!
        : 'All areas';
    final types = user.officerTypes.isEmpty
        ? 'All report types'
        : user.officerTypes
            .map((name) => CommunityReportType.fromName(name).label)
            .join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.assignment_ind_rounded)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Allocated area: $area\nDuty type: $types',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
