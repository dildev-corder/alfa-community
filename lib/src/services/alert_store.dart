import 'package:shared_preferences/shared_preferences.dart';

import '../models/safety_alert.dart';

class AlertStore {
  static const _key = 'safety_alerts';

  Future<List<SafetyAlert>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_key);
    if (source == null || source.isEmpty) return [];
    return SafetyAlert.decodeList(source);
  }

  Future<void> add(SafetyAlert alert) async {
    final preferences = await SharedPreferences.getInstance();
    final alerts = await load();
    alerts.insert(0, alert);
    await preferences.setString(
      _key,
      SafetyAlert.encodeList(alerts.take(50).toList()),
    );
  }
}
