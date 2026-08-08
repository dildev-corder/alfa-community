enum UserRole {
  admin,
  officer,
  citizen;

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.officer => 'Officer',
        UserRole.citizen => 'Citizen',
      };

  bool get canSeeEveryCard =>
      this == UserRole.admin || this == UserRole.officer;

  static UserRole fromName(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.citizen,
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.identifier,
    required this.role,
    required this.createdAt,
    this.passwordHash,
    this.officerArea,
    this.officerTypes = const [],
    this.phoneNumber,
  });

  final String id;
  final String displayName;
  final String identifier;
  final UserRole role;
  final DateTime createdAt;
  final String? passwordHash;
  final String? officerArea;
  final List<String> officerTypes;
  final String? phoneNumber;

  bool get canSeeEveryCard => role.canSeeEveryCard;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'identifier': identifier,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
        if (passwordHash != null) 'passwordHash': passwordHash,
        if (officerArea != null && officerArea!.trim().isNotEmpty)
          'officerArea': officerArea,
        if (officerTypes.isNotEmpty) 'officerTypes': officerTypes,
        if (phoneNumber != null && phoneNumber!.trim().isNotEmpty)
          'phoneNumber': phoneNumber,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      identifier: json['identifier'] as String,
      role: UserRole.fromName(json['role'] as String? ?? UserRole.citizen.name),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      passwordHash: json['passwordHash'] as String?,
      officerArea: json['officerArea'] as String?,
      officerTypes: [
        for (final type in (json['officerTypes'] as List? ?? const []))
          type.toString(),
      ],
      phoneNumber: json['phoneNumber'] as String?,
    );
  }
}
