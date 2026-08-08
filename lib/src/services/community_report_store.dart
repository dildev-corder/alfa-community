import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/community_report.dart';
import '../models/location_profile.dart';
import 'firebase_bootstrap.dart';
import 'local_database_service.dart';
import 'location_name_service.dart';
import 'twilio_alert_service.dart';

class CommunityReportStore {
  const CommunityReportStore();

  static const _collection = 'alpha_community_reports';
  static const _locationNames = LocationNameService();
  static const _twilioAlerts = TwilioAlertService();

  Stream<List<CommunityReport>> watch({
    AppUser? viewer,
    bool onlyMine = false,
  }) async* {
    await syncPendingReports();
    if (!FirebaseBootstrap.isInitialized) {
      final reports = await LocalDatabaseService.instance.reports();
      yield _filterForViewer(reports, viewer: viewer, onlyMine: onlyMine);
      return;
    }
    yield* FirebaseFirestore.instance
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap((snapshot) async {
      final reports = [
        for (final doc in snapshot.docs) CommunityReport.fromJson(doc.data()),
      ];
      for (final report in reports) {
        await LocalDatabaseService.instance.upsertReport(
          report,
          syncPending: false,
        );
      }
      return _filterForViewer(reports, viewer: viewer, onlyMine: onlyMine);
    });
  }

  Future<List<CommunityReport>> load() async {
    await syncPendingReports();
    final remote = await _loadRemoteReports();
    if (remote.isNotEmpty) {
      for (final report in remote) {
        await LocalDatabaseService.instance.upsertReport(
          report,
          syncPending: false,
        );
      }
      return remote;
    }
    return LocalDatabaseService.instance.reports();
  }

  Future<CommunityReport> createBinReport({
    required AppUser citizen,
    required LocationProfile profile,
    required String message,
  }) async {
    return createIssueReport(
      citizen: citizen,
      profile: profile,
      type: CommunityReportType.garbageOverflow,
      description: message.trim().isEmpty
          ? 'Citizen reported that the community bin is full.'
          : message,
      contactNumber: 'Not provided',
      photoPath: 'Photo evidence pending',
    );
  }

  Future<CommunityReport> createIssueReport({
    required AppUser citizen,
    required LocationProfile profile,
    required CommunityReportType type,
    required String description,
    required String contactNumber,
    required String photoPath,
  }) async {
    final trimmedDescription = description.trim();
    final trimmedContact = contactNumber.trim();
    final trimmedPhotoPath = photoPath.trim();

    if (trimmedDescription.length < 8) {
      throw ArgumentError('Description is required.');
    }
    if (trimmedContact.length < 6) {
      throw ArgumentError('Contact number is required.');
    }
    if (profile.latitude == null || profile.longitude == null) {
      throw ArgumentError('GPS location is required.');
    }
    if (trimmedPhotoPath.isEmpty) {
      throw ArgumentError('Photo evidence is required.');
    }

    final report = CommunityReport(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      status: CommunityReportStatus.newReport,
      message: trimmedDescription,
      createdById: citizen.id,
      createdByName: citizen.displayName,
      createdAt: DateTime.now(),
      latitude: profile.latitude,
      longitude: profile.longitude,
      contactNumber: trimmedContact,
      photoPath: trimmedPhotoPath,
      district: _locationNames.districtForCoordinates(
        profile.latitude!,
        profile.longitude!,
        fallback: profile.label,
      ),
    );
    await upsert(report);
    await _upsertCitizenAlertSubscription(citizen, report);
    await _twilioAlerts.sendReportAlert(report);
    return report;
  }

  Future<void> upsert(CommunityReport report) async {
    await LocalDatabaseService.instance.upsertReport(report);
    await _saveRemote(report);
  }

  Future<void> assignToOfficer(CommunityReport report, AppUser officer) async {
    await upsert(
      report.copyWith(
        status: CommunityReportStatus.assigned,
        assignedOfficerId: officer.id,
        assignedOfficerName: officer.displayName,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> markReviewed(CommunityReport report, AppUser officer) async {
    await upsert(
      report.copyWith(
        status: CommunityReportStatus.reviewed,
        assignedOfficerId: officer.id,
        assignedOfficerName: officer.displayName,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> markBinFree(CommunityReport report, AppUser officer) async {
    await upsert(
      report.copyWith(
        status: CommunityReportStatus.binFreed,
        assignedOfficerId: report.assignedOfficerId ?? officer.id,
        assignedOfficerName: report.assignedOfficerName ?? officer.displayName,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> resolve(CommunityReport report, AppUser actor) async {
    await upsert(
      report.copyWith(
        status: CommunityReportStatus.resolved,
        assignedOfficerId: report.assignedOfficerId ??
            (actor.role == UserRole.officer ? actor.id : null),
        assignedOfficerName: report.assignedOfficerName ??
            (actor.role == UserRole.officer ? actor.displayName : null),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<List<CommunityReport>> _loadRemoteReports() async {
    if (!FirebaseBootstrap.isInitialized) return const [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      return [
        for (final doc in snapshot.docs) CommunityReport.fromJson(doc.data()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveRemote(CommunityReport report) async {
    if (!FirebaseBootstrap.isInitialized) return;
    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(report.id)
          .set(report.toJson());
      await LocalDatabaseService.instance.markReportSynced(report.id);
    } catch (_) {
      // Local workflow remains available when cloud sync is unavailable.
    }
  }

  Future<void> _upsertCitizenAlertSubscription(
    AppUser citizen,
    CommunityReport report,
  ) async {
    if (!FirebaseBootstrap.isInitialized) return;
    final phone = report.contactNumber.trim().isNotEmpty
        ? report.contactNumber.trim()
        : citizen.phoneNumber?.trim();
    if (phone == null || phone.isEmpty || phone == 'Not provided') return;
    try {
      await FirebaseFirestore.instance
          .collection('alpha_alert_subscriptions')
          .doc(citizen.id)
          .set({
        'userId': citizen.id,
        'name': citizen.displayName,
        'phone': phone.startsWith('+') ? phone : '+$phone',
        'area': report.district,
        'alertTypes': FieldValue.arrayUnion([report.type.name]),
        'enabled': true,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Report submission still succeeds if alert subscription sync fails.
    }
  }

  Future<void> syncPendingReports() async {
    if (!FirebaseBootstrap.isInitialized) return;
    for (final report in await LocalDatabaseService.instance.pendingReports()) {
      await _saveRemote(report);
    }
  }

  List<CommunityReport> _filterForViewer(
    List<CommunityReport> reports, {
    AppUser? viewer,
    bool onlyMine = false,
  }) {
    if (viewer == null) return reports;
    if (onlyMine) {
      return reports
          .where((report) => report.createdById == viewer.id)
          .toList();
    }
    if (viewer.role != UserRole.officer) return reports;

    final officerArea = viewer.officerArea?.trim().toLowerCase();
    final officerTypes = viewer.officerTypes.map((type) => type.trim()).toSet();
    return reports.where((report) {
      final areaOk = officerArea == null ||
          officerArea.isEmpty ||
          officerArea == 'all areas' ||
          report.district.toLowerCase().contains(officerArea) ||
          officerArea.contains(report.district.toLowerCase());
      final typeOk =
          officerTypes.isEmpty || officerTypes.contains(report.type.name);
      return areaOk && typeOk;
    }).toList();
  }
}
