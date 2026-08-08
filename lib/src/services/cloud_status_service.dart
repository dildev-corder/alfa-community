import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_bootstrap.dart';

class CloudStatusService {
  const CloudStatusService();

  Future<void> markAppOpened() async {
    if (!FirebaseBootstrap.isInitialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('alpha_system_status')
          .doc('android_app')
          .set({
        'app': 'Alpha Community',
        'platform': 'android',
        'lastOpenedAt': DateTime.now().toIso8601String(),
        'status': 'connected',
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Cloud status is diagnostic only; never block app startup.
    }
  }
}
