import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/risk_prediction.dart';

class RiskPredictionStore {
  const RiskPredictionStore();

  static const _key = 'risk_prediction_history_v1';

  Future<List<RiskPrediction>> load({String? module}) async {
    final preferences = await SharedPreferences.getInstance();
    final records = preferences.getStringList(_key) ?? const [];
    final predictions = records
        .map((item) => RiskPrediction.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            ))
        .where((item) => module == null || item.module == module)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return predictions;
  }

  Future<void> save(RiskPrediction prediction) async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getStringList(_key) ?? <String>[];
    final updated = [jsonEncode(prediction.toJson()), ...existing].take(50);
    await preferences.setStringList(_key, updated.toList());
  }

  Future<void> clear({String? module}) async {
    final preferences = await SharedPreferences.getInstance();
    if (module == null) {
      await preferences.remove(_key);
      return;
    }
    final existing = await load();
    final retained = existing
        .where((item) => item.module != module)
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await preferences.setStringList(_key, retained);
  }
}
