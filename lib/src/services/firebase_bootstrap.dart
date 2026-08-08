import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool _initialized = false;
  static Object? _error;

  static bool get isInitialized => _initialized;
  static Object? get error => _error;

  static Future<void> initialize() async {
    if (_initialized || _error != null) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
    } catch (error) {
      _error = error;
    }
  }
}
