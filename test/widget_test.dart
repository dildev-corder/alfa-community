import 'package:alfa_citizen/src/alfa_citizen_app.dart';
import 'package:alfa_citizen/src/models/app_user.dart';
import 'package:alfa_citizen/src/models/community_report.dart';
import 'package:alfa_citizen/src/models/location_profile.dart';
import 'package:alfa_citizen/src/models/safety_module.dart';
import 'package:alfa_citizen/src/services/auth_service.dart';
import 'package:alfa_citizen/src/services/citizen_assistant_service.dart';
import 'package:alfa_citizen/src/services/community_report_store.dart';
import 'package:alfa_citizen/src/services/local_database_service.dart';
import 'package:alfa_citizen/src/services/module_registry.dart';
import 'package:alfa_citizen/src/services/risk_engine.dart';
import 'package:alfa_citizen/src/services/risk_prediction_store.dart';
import 'package:alfa_citizen/src/models/risk_prediction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalDatabaseService.instance.clearForTest();
  });

  testWidgets('shows village login before dashboard', (tester) async {
    await tester.pumpWidget(const AlfaCitizenApp());
    await tester.pump();

    expect(find.text('WORLD CITIZEN APP'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Enter Alpha Community'), 300);
    await tester.tap(find.text('Enter Alpha Community'));
    await tester.pump();

    expect(find.text('ALPHA COMMUNITY'), findsWidgets);
    expect(find.text('Citizen'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Officer'), findsNothing);
    expect(find.text('Admin'), findsNothing);
    expect(find.text('NIC number'), findsOneWidget);
    expect(find.text('AUTOMATIC LOCATION MEASURE'), findsNothing);
  });

  testWidgets('default admin can see every safety card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const AlfaCitizenApp());
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Enter Alpha Community'), 300);
    await tester.tap(find.text('Enter Alpha Community'));
    await tester.pump();
    await tester.tap(find.text('Staff'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), 'ADMIN');
    await tester.enterText(find.byType(TextField).at(1), 'admin123');
    await tester.tap(find.text('Authenticate and enter').last);
    await tester.pump();

    expect(find.text('Alpha Community'), findsOneWidget);
    expect(find.text('Search GPS manually'), findsNothing);
    expect(find.text('Auto search when moving'), findsNothing);
    expect(find.text('Show all cards for demo'), findsNothing);
    await tester.scrollUntilVisible(find.text('Garbage Monitoring'), 250);
    expect(find.text('Garbage Monitoring'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Flood Monitoring'), 250);
    expect(find.text('Flood Monitoring'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Landslide Monitoring'), 250);
    expect(find.text('Landslide Monitoring'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Elephant Monitoring'), 250);
    expect(find.text('Elephant Monitoring'), findsOneWidget);
  });

  test('citizen NIC and officer employee ID are unique', () async {
    const auth = AuthService();

    final citizen = await auth.register(
      role: UserRole.citizen,
      displayName: 'Village Citizen',
      identifier: '200012345678',
      password: 'secret123',
    );
    final duplicateCitizen = await auth.register(
      role: UserRole.citizen,
      displayName: 'Other Citizen',
      identifier: '200012345678',
      password: 'secret123',
    );
    final officer = await auth.register(
      role: UserRole.officer,
      displayName: 'Field Officer',
      identifier: 'EMP-100',
      password: 'secret123',
    );
    final duplicateOfficer = await auth.register(
      role: UserRole.officer,
      displayName: 'Other Officer',
      identifier: 'EMP-100',
      password: 'secret123',
    );

    expect(citizen.isSuccess, isTrue);
    expect(duplicateCitizen.isSuccess, isFalse);
    expect(officer.isSuccess, isTrue);
    expect(duplicateOfficer.isSuccess, isFalse);
  });

  test('citizen login requires password after registration', () async {
    const auth = AuthService();

    await auth.register(
      role: UserRole.citizen,
      displayName: 'Village Citizen',
      identifier: '200012345678',
      password: 'secret123',
    );

    final wrongPassword = await auth.login(
      role: UserRole.citizen,
      identifier: '200012345678',
      password: 'badpass',
    );
    final correctPassword = await auth.login(
      role: UserRole.citizen,
      identifier: '200012345678',
      password: 'secret123',
    );

    expect(wrongPassword.isSuccess, isFalse);
    expect(correctPassword.isSuccess, isTrue);
  });

  test('login does not persist active role after app restart', () async {
    const auth = AuthService();

    final admin = await auth.login(
      role: UserRole.admin,
      identifier: 'ADMIN',
      password: 'admin123',
    );

    expect(admin.isSuccess, isTrue);
    expect(await auth.currentUser(), isNull);
  });

  test('staff login accepts default admin credentials', () async {
    const auth = AuthService();

    final admin = await auth.staffLogin(
      identifier: 'ADMIN',
      password: 'admin123',
    );
    final wrongAdminPassword = await auth.staffLogin(
      identifier: 'ADMIN',
      password: 'wrong123',
    );

    expect(admin.isSuccess, isTrue);
    expect(admin.user?.role, UserRole.admin);
    expect(wrongAdminPassword.isSuccess, isFalse);
    expect(wrongAdminPassword.error, 'Invalid default admin credentials.');
  });

  test('central highlands prioritize landslide over elephant module', () {
    const profile = LocationProfile(
      label: 'Kandy test point',
      latitude: 7.29,
      longitude: 80.63,
      isLive: false,
    );
    final modules = const ModuleRegistry().modulesFor(profile, demoAll: false);

    expect(
      modules.singleWhere((module) => module.id == ModuleId.landslide).enabled,
      isTrue,
    );
    expect(
      modules.singleWhere((module) => module.id == ModuleId.elephant).enabled,
      isFalse,
    );
  });

  test('citizen bin report moves through officer and admin workflow', () async {
    const store = CommunityReportStore();
    final citizen = AppUser(
      id: 'citizen-1',
      displayName: 'Village Citizen',
      identifier: '200012345678',
      role: UserRole.citizen,
      createdAt: DateTime.now(),
    );
    final officer = AppUser(
      id: 'officer-1',
      displayName: 'Bin Officer',
      identifier: 'EMP-100',
      role: UserRole.officer,
      createdAt: DateTime.now(),
    );
    final admin = AppUser(
      id: 'admin-default',
      displayName: 'Admin',
      identifier: 'ADMIN',
      role: UserRole.admin,
      createdAt: DateTime.now(),
    );

    final report = await store.createBinReport(
      citizen: citizen,
      profile: const LocationProfile(
        label: 'Village point',
        latitude: 7.29,
        longitude: 80.63,
        isLive: true,
      ),
      message: 'Bin near temple is full.',
    );
    await store.assignToOfficer(report, officer);
    final assigned = (await store.load()).first;
    await store.markBinFree(assigned, officer);
    final freed = (await store.load()).first;
    await store.resolve(freed, admin);
    final resolved = (await store.load()).first;

    expect(report.status, CommunityReportStatus.newReport);
    expect(assigned.status, CommunityReportStatus.assigned);
    expect(freed.status, CommunityReportStatus.binFreed);
    expect(resolved.status, CommunityReportStatus.resolved);
  });

  test('high flood inputs produce a high risk prototype score', () {
    final result = const RiskEngine().flood(
      rainfall24h: 220,
      waterLevel: 5,
      drainage: 10,
    );

    expect(result.level, RiskLevel.high);
    expect(result.isModelResult, isFalse);
  });

  test('prediction history persists and filters by module', () async {
    const store = RiskPredictionStore();
    await store.save(RiskPrediction(
      id: 'prediction-1',
      module: 'flood',
      createdAt: DateTime(2026),
      inputs: const {'rainfall mm': 180},
      level: RiskLevel.high,
      confidence: 0.91,
      isModelResult: true,
    ));

    final floodHistory = await store.load(module: 'flood');
    final landslideHistory = await store.load(module: 'landslide');

    expect(floodHistory, hasLength(1));
    expect(floodHistory.single.confidence, 0.91);
    expect(landslideHistory, isEmpty);
  });

  test('citizen assistant answers fully offline', () async {
    final reply =
        await CitizenAssistantService().ask('Bin is 90% full in Kandy');

    expect(reply.engineLabel, 'OFFLINE GEN AI');
    expect(reply.text, contains('Clean community guidance near Kandy'));
    expect(reply.text, isNot(contains('No internet')));
  });

  test('citizen assistant can read online answer payloads', () async {
    final service = CitizenAssistantService();

    final decoded = service.extractAnswerForTest({'answer': 'Online answer'});
    final openAiDecoded = service.extractAnswerForTest({
      'output_text': 'OpenAI response answer',
    });

    expect(decoded, 'Online answer');
    expect(openAiDecoded, 'OpenAI response answer');
    service.close();
  });
}
