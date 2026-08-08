import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_bootstrap.dart';

class ElephantBeamReading {
  const ElephantBeamReading({
    required this.deviceId,
    required this.beamBroken,
    required this.risk,
    required this.updatedAt,
  });

  final String deviceId;
  final bool beamBroken;
  final String risk;
  final DateTime updatedAt;

  bool get isHighRisk => beamBroken || risk.toLowerCase() == 'high';
}

class EnvironmentSensorReading {
  const EnvironmentSensorReading({
    required this.deviceId,
    required this.rainAnalog,
    required this.rainDigital,
    required this.waterLevelRaw,
    required this.soilMoistureRaw,
    required this.vibrationDigital,
    required this.vibrationAnalog,
    required this.tiltMagnitude,
    required this.updatedAt,
  });

  final String deviceId;
  final int rainAnalog;
  final bool rainDigital;
  final int waterLevelRaw;
  final int soilMoistureRaw;
  final bool vibrationDigital;
  final int vibrationAnalog;
  final double tiltMagnitude;
  final DateTime updatedAt;

  double get rainfallEstimateMm {
    final wetness = (4095 - rainAnalog).clamp(0, 4095) / 4095;
    return (wetness * 250).clamp(0, 250).toDouble();
  }

  double get waterLevelMeters {
    return (waterLevelRaw.clamp(0, 4095) / 4095 * 6).toDouble();
  }

  double get drainagePercent {
    final waterPressure = waterLevelRaw.clamp(0, 4095) / 4095;
    return ((1 - waterPressure) * 100).clamp(0, 100).toDouble();
  }

  double get soilMoisturePercent {
    final moisture = (4095 - soilMoistureRaw).clamp(0, 4095) / 4095;
    return (moisture * 100).clamp(0, 100).toDouble();
  }

  double get slopeDegrees {
    return (tiltMagnitude * 70).clamp(0, 70).toDouble();
  }
}

class IotSensorService {
  const IotSensorService();

  static const _elephantCollection = 'alpha_iot_elephant';
  static const _environmentCollection = 'alpha_iot_environment';

  Future<ElephantBeamReading?> latestElephantBeam() async {
    if (!FirebaseBootstrap.isInitialized) return null;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_elephantCollection)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      return ElephantBeamReading(
        deviceId: _asString(data['deviceId']) ?? doc.id,
        beamBroken: _asBool(data['beamBroken']),
        risk: _asString(data['risk']) ?? 'low',
        updatedAt: _asDateTime(data['updatedAt']) ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<EnvironmentSensorReading?> latestEnvironment() async {
    if (!FirebaseBootstrap.isInitialized) return null;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_environmentCollection)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      return EnvironmentSensorReading(
        deviceId: _asString(data['deviceId']) ?? doc.id,
        rainAnalog: _asInt(data['rainAnalog']),
        rainDigital: _asBool(data['rainDigital']),
        waterLevelRaw: _asInt(data['waterLevelRaw']),
        soilMoistureRaw: _asInt(data['soilMoistureRaw']),
        vibrationDigital: _asBool(data['vibrationDigital']),
        vibrationAnalog: _asInt(data['vibrationAnalog']),
        tiltMagnitude: _asDouble(data['tiltMagnitude']),
        updatedAt: _asDateTime(data['updatedAt']) ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _asDouble(Object? value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String? _asString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
