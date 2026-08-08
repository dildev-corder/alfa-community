import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/app_user.dart';
import 'firebase_bootstrap.dart';
import 'local_database_service.dart';

class AuthResult {
  const AuthResult.success(this.user) : error = null;
  const AuthResult.failure(this.error) : user = null;

  final AppUser? user;
  final String? error;

  bool get isSuccess => user != null;
}

class AuthService {
  const AuthService();

  static const _adminId = 'ADMIN';
  static const _adminPassword = 'admin123';

  Future<AppUser?> currentUser() async {
    return null;
  }

  Future<void> signOut() async {}

  Future<AuthResult> login({
    required UserRole role,
    required String identifier,
    required String password,
  }) async {
    final normalizedId = _normalizeIdentifier(identifier);
    if (normalizedId.isEmpty) {
      return const AuthResult.failure('Enter your ID.');
    }

    if (role == UserRole.admin) {
      if (normalizedId == _adminId && password == _adminPassword) {
        final admin = AppUser(
          id: 'admin-default',
          displayName: 'Alpha Community Admin',
          identifier: _adminId,
          role: UserRole.admin,
          createdAt: DateTime.now(),
        );
        return AuthResult.success(admin);
      }
      return const AuthResult.failure('Invalid default admin credentials.');
    }

    if (password.length < 6) {
      return const AuthResult.failure('Enter your password.');
    }

    final localUser = await _findLocalUser(role, normalizedId);
    if (localUser != null) {
      if (!_passwordMatches(localUser, password)) {
        return const AuthResult.failure('Invalid password.');
      }
      return AuthResult.success(localUser);
    }

    final remoteUser = await _findRemoteUser(role, normalizedId);
    if (remoteUser != null) {
      if (!_passwordMatches(remoteUser, password)) {
        return const AuthResult.failure('Invalid password.');
      }
      await LocalDatabaseService.instance.upsertUser(
        remoteUser,
        syncPending: false,
      );
      return AuthResult.success(remoteUser);
    }

    return AuthResult.failure(
      role == UserRole.officer
          ? 'Employee ID not registered.'
          : 'NIC not registered.',
    );
  }

  Future<AuthResult> staffLogin({
    required String identifier,
    required String password,
  }) async {
    final normalizedId = _normalizeIdentifier(identifier);
    if (normalizedId == _adminId) {
      return login(
        role: UserRole.admin,
        identifier: identifier,
        password: password,
      );
    }

    final admin = await login(
      role: UserRole.admin,
      identifier: identifier,
      password: password,
    );
    if (admin.isSuccess) return admin;

    final officer = await login(
      role: UserRole.officer,
      identifier: identifier,
      password: password,
    );
    if (officer.isSuccess) return officer;

    return const AuthResult.failure(
      'Officer account not found. Login with ADMIN first and create the officer account.',
    );
  }

  Future<AuthResult> register({
    required UserRole role,
    required String displayName,
    required String identifier,
    required String password,
    String? officerArea,
    List<String> officerTypes = const [],
    String? phoneNumber,
  }) async {
    if (role == UserRole.admin) {
      return const AuthResult.failure('Default admin already exists.');
    }

    final normalizedId = _normalizeIdentifier(identifier);
    final trimmedName = displayName.trim();
    if (trimmedName.length < 2) {
      return const AuthResult.failure('Enter a valid name.');
    }
    if (!_validIdentifier(role, normalizedId)) {
      return AuthResult.failure(
        role == UserRole.officer
            ? 'Enter a valid employee ID.'
            : 'Enter a valid NIC.',
      );
    }
    if (!_validPassword(password)) {
      return const AuthResult.failure(
        'Password must have at least 6 characters.',
      );
    }

    if (await _findLocalUser(role, normalizedId) != null ||
        await _findRemoteUser(role, normalizedId) != null) {
      return AuthResult.failure(
        role == UserRole.officer
            ? 'This employee ID is already used.'
            : 'This NIC is already used.',
      );
    }

    final user = AppUser(
      id: '${role.name}-$normalizedId',
      displayName: trimmedName,
      identifier: normalizedId,
      role: role,
      createdAt: DateTime.now(),
      passwordHash: _hashPassword(role, normalizedId, password),
      officerArea: role == UserRole.officer ? officerArea?.trim() : null,
      officerTypes: role == UserRole.officer
          ? officerTypes.where((type) => type.trim().isNotEmpty).toList()
          : const [],
      phoneNumber: _normalizePhone(phoneNumber),
    );
    await LocalDatabaseService.instance.upsertUser(user);
    await _saveRemoteUser(user);
    return AuthResult.success(user);
  }

  Future<AppUser?> _findLocalUser(UserRole role, String identifier) async {
    return LocalDatabaseService.instance.findUser(role, identifier);
  }

  Future<AppUser?> _findRemoteUser(UserRole role, String identifier) async {
    if (!FirebaseBootstrap.isInitialized) return null;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('alpha_users')
          .where('role', isEqualTo: role.name)
          .where('identifier', isEqualTo: identifier)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return AppUser.fromJson(snapshot.docs.first.data());
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveRemoteUser(AppUser user) async {
    if (!FirebaseBootstrap.isInitialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('alpha_users')
          .doc(user.id)
          .set(user.toJson());
      await LocalDatabaseService.instance.markUserSynced(user.id);
    } catch (_) {
      // Local sign-in remains available when cloud sync is unavailable.
    }
  }

  Future<void> syncPendingUsers() async {
    if (!FirebaseBootstrap.isInitialized) return;
    for (final user in await LocalDatabaseService.instance.pendingUsers()) {
      await _saveRemoteUser(user);
    }
  }

  bool _validIdentifier(UserRole role, String identifier) {
    if (role == UserRole.officer) return identifier.length >= 4;
    final oldNic = RegExp(r'^\d{9}[VX]$');
    final newNic = RegExp(r'^\d{12}$');
    return oldNic.hasMatch(identifier) || newNic.hasMatch(identifier);
  }

  String _normalizeIdentifier(String value) {
    return value.trim().toUpperCase().replaceAll(' ', '');
  }

  String? _normalizePhone(String? value) {
    final phone = value?.trim().replaceAll(' ', '');
    if (phone == null || phone.isEmpty) return null;
    return phone.startsWith('+') ? phone : '+$phone';
  }

  bool _validPassword(String password) => password.trim().length >= 6;

  bool _passwordMatches(AppUser user, String password) {
    final storedHash = user.passwordHash;
    if (storedHash == null || storedHash.isEmpty) return password.isEmpty;
    return storedHash == _hashPassword(user.role, user.identifier, password);
  }

  String _hashPassword(UserRole role, String identifier, String password) {
    final normalizedId = _normalizeIdentifier(identifier);
    final bytes = utf8.encode('${role.name}|$normalizedId|${password.trim()}');
    return sha256.convert(bytes).toString();
  }
}
