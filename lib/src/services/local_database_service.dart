import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/app_user.dart';
import '../models/community_report.dart';

class LocalDatabaseService {
  LocalDatabaseService._();

  static final instance = LocalDatabaseService._();
  static Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final dbPath = await getDatabasesPath();
    final database = await openDatabase(
      path.join(dbPath, 'alpha_community.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            role TEXT NOT NULL,
            identifier TEXT NOT NULL,
            json TEXT NOT NULL,
            syncPending INTEGER NOT NULL DEFAULT 1,
            UNIQUE(role, identifier)
          )
        ''');
        await db.execute('''
          CREATE TABLE community_reports (
            id TEXT PRIMARY KEY,
            status TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            json TEXT NOT NULL,
            syncPending INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    );
    _database = database;
    return database;
  }

  Future<void> upsertUser(AppUser user, {bool syncPending = true}) async {
    final db = await database;
    await db.insert(
      'users',
      {
        'id': user.id,
        'role': user.role.name,
        'identifier': user.identifier,
        'json': jsonEncode(user.toJson()),
        'syncPending': syncPending ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppUser?> findUser(UserRole role, String identifier) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'role = ? AND identifier = ?',
      whereArgs: [role.name, identifier],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromJson(jsonDecode(rows.first['json'] as String));
  }

  Future<List<AppUser>> pendingUsers() async {
    final db = await database;
    final rows = await db.query('users', where: 'syncPending = 1');
    return [
      for (final row in rows)
        AppUser.fromJson(jsonDecode(row['json'] as String)),
    ];
  }

  Future<void> markUserSynced(String id) async {
    final db = await database;
    await db.update(
      'users',
      {'syncPending': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> upsertReport(
    CommunityReport report, {
    bool syncPending = true,
  }) async {
    final db = await database;
    await db.insert(
      'community_reports',
      {
        'id': report.id,
        'status': report.status.name,
        'createdAt': report.createdAt.toIso8601String(),
        'json': jsonEncode(report.toJson()),
        'syncPending': syncPending ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CommunityReport>> reports() async {
    final db = await database;
    final rows = await db.query(
      'community_reports',
      orderBy: 'createdAt DESC',
      limit: 100,
    );
    return [
      for (final row in rows)
        CommunityReport.fromJson(jsonDecode(row['json'] as String)),
    ];
  }

  Future<List<CommunityReport>> pendingReports() async {
    final db = await database;
    final rows = await db.query(
      'community_reports',
      where: 'syncPending = 1',
      orderBy: 'createdAt ASC',
    );
    return [
      for (final row in rows)
        CommunityReport.fromJson(jsonDecode(row['json'] as String)),
    ];
  }

  Future<void> markReportSynced(String id) async {
    final db = await database;
    await db.update(
      'community_reports',
      {'syncPending': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearForTest() async {
    final db = await database;
    await db.delete('users');
    await db.delete('community_reports');
  }
}
