enum CommunityReportType {
  flood,
  landslide,
  elephantMovement,
  garbageOverflow,
  roadDamage,
  crime,
  waterIssue,
  other,
  binFull,
  illegalDumping,
  damagedBin;

  String get label => switch (this) {
        CommunityReportType.flood => 'Flood',
        CommunityReportType.landslide => 'Landslide',
        CommunityReportType.elephantMovement => 'Elephant movement',
        CommunityReportType.garbageOverflow => 'Garbage overflow',
        CommunityReportType.roadDamage => 'Road damage',
        CommunityReportType.crime => 'Crime or suspicious activity',
        CommunityReportType.waterIssue => 'Water issue',
        CommunityReportType.other => 'Other issue',
        CommunityReportType.binFull => 'Bin is full',
        CommunityReportType.illegalDumping => 'Illegal dumping',
        CommunityReportType.damagedBin => 'Damaged bin',
      };

  bool get isGarbageService => switch (this) {
        CommunityReportType.garbageOverflow ||
        CommunityReportType.binFull ||
        CommunityReportType.illegalDumping ||
        CommunityReportType.damagedBin =>
          true,
        _ => false,
      };

  static CommunityReportType fromName(String value) {
    return CommunityReportType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => CommunityReportType.garbageOverflow,
    );
  }
}

enum CommunityReportStatus {
  newReport,
  reviewed,
  pending,
  assigned,
  binFreed,
  resolved;

  String get label => switch (this) {
        CommunityReportStatus.newReport => 'New',
        CommunityReportStatus.reviewed => 'Reviewed',
        CommunityReportStatus.pending => 'Pending',
        CommunityReportStatus.assigned => 'Assigned',
        CommunityReportStatus.binFreed => 'Bin freed',
        CommunityReportStatus.resolved => 'Resolved',
      };

  static CommunityReportStatus fromName(String value) {
    return CommunityReportStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CommunityReportStatus.newReport,
    );
  }
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.type,
    required this.status,
    required this.message,
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.contactNumber,
    required this.photoPath,
    required this.district,
    this.assignedOfficerId,
    this.assignedOfficerName,
    this.updatedAt,
  });

  final String id;
  final CommunityReportType type;
  final CommunityReportStatus status;
  final String message;
  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String contactNumber;
  final String photoPath;
  final String district;
  final String? assignedOfficerId;
  final String? assignedOfficerName;
  final DateTime? updatedAt;

  bool get hasGpsLocation => latitude != null && longitude != null;
  bool get hasPhotoEvidence => photoPath.trim().isNotEmpty;

  CommunityReport copyWith({
    CommunityReportStatus? status,
    String? assignedOfficerId,
    String? assignedOfficerName,
    DateTime? updatedAt,
  }) {
    return CommunityReport(
      id: id,
      type: type,
      status: status ?? this.status,
      message: message,
      createdById: createdById,
      createdByName: createdByName,
      createdAt: createdAt,
      latitude: latitude,
      longitude: longitude,
      contactNumber: contactNumber,
      photoPath: photoPath,
      district: district,
      assignedOfficerId: assignedOfficerId ?? this.assignedOfficerId,
      assignedOfficerName: assignedOfficerName ?? this.assignedOfficerName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'message': message,
        'createdById': createdById,
        'createdByName': createdByName,
        'createdAt': createdAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'contactNumber': contactNumber,
        'photoPath': photoPath,
        'district': district,
        'assignedOfficerId': assignedOfficerId,
        'assignedOfficerName': assignedOfficerName,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory CommunityReport.fromJson(Map<String, dynamic> json) {
    return CommunityReport(
      id: json['id'] as String,
      type: CommunityReportType.fromName(
        json['type'] as String? ?? CommunityReportType.garbageOverflow.name,
      ),
      status: CommunityReportStatus.fromName(
        json['status'] as String? ?? CommunityReportStatus.newReport.name,
      ),
      message: json['message'] as String? ?? '',
      createdById: json['createdById'] as String? ?? '',
      createdByName: json['createdByName'] as String? ?? 'Citizen',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      contactNumber: json['contactNumber'] as String? ?? '',
      photoPath: json['photoPath'] as String? ?? '',
      district: json['district'] as String? ?? 'Unknown area',
      assignedOfficerId: json['assignedOfficerId'] as String?,
      assignedOfficerName: json['assignedOfficerName'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
