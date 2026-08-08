import 'dart:async';

import 'package:flutter/material.dart';

import 'src/alfa_citizen_app.dart';
import 'src/services/auth_service.dart';
import 'src/services/cloud_status_service.dart';
import 'src/services/community_report_store.dart';
import 'src/services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const AlfaCitizenApp());
  unawaited(_syncCloudInBackground());
}

Future<void> _syncCloudInBackground() async {
  try {
    await const CloudStatusService().markAppOpened();
    await const AuthService().syncPendingUsers();
    await const CommunityReportStore().syncPendingReports();
  } catch (_) {
    // The app must remain usable even when cloud sync is unavailable.
  }
}
