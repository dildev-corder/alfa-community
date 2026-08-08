import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'firebase_bootstrap.dart';

class GarbageBinReading {
  const GarbageBinReading({
    required this.binId,
    required this.areaLabel,
    required this.fillPercent,
    required this.capacityKg,
    required this.currentWeightKg,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  final String binId;
  final String areaLabel;
  final int fillPercent;
  final double capacityKg;
  final double currentWeightKg;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  int get freePercent => 100 - fillPercent;
  double get freeCapacityKg => capacityKg - currentWeightKg;
  bool get isAlmostFull => fillPercent >= 80;
  bool get hasGoodSpace => fillPercent <= 70;
}

class GarbageBinSensorService {
  const GarbageBinSensorService();

  static const _collection = 'garbage_bins';
  static const _legacyCollection = 'alpha_smart_bins';

  Future<GarbageBinReading> nearestBin(
    Position? position, {
    bool simulateFallbackDelay = true,
  }) async {
    final cloudReading = await _nearestCloudBin(position);
    if (cloudReading != null) return cloudReading;

    if (simulateFallbackDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    final latitude = position?.latitude ?? 7.2906;
    final longitude = position?.longitude ?? 80.6337;
    final seed =
        ((latitude * 1000).round().abs() + (longitude * 1000).round().abs()) %
            100;
    final fillPercent = 18 + seed % 73;
    const capacityKg = 120.0;

    return GarbageBinReading(
      binId:
          'BIN-${(latitude * 100).round().abs()}-${(longitude * 100).round().abs()}',
      areaLabel: _areaLabel(latitude, longitude),
      fillPercent: fillPercent,
      capacityKg: capacityKg,
      currentWeightKg: capacityKg * fillPercent / 100,
      latitude: latitude + 0.002 * sin(seed),
      longitude: longitude + 0.002 * cos(seed),
      updatedAt: DateTime.now(),
    );
  }

  Future<GarbageBinReading?> _nearestCloudBin(Position? position) async {
    if (!FirebaseBootstrap.isInitialized) return null;

    try {
      final readings = <GarbageBinReading>[];
      for (final collection in const [_collection, _legacyCollection]) {
        final snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .limit(30)
            .get()
            .timeout(const Duration(seconds: 6));
        readings.addAll(
          snapshot.docs
              .map((doc) => _readingFromFirestore(doc.id, doc.data()))
              .whereType<GarbageBinReading>(),
        );
      }
      if (readings.isEmpty) return null;
      if (position == null) return readings.first;

      readings.sort(
        (a, b) => _distanceSquared(
          position.latitude,
          position.longitude,
          a.latitude,
          a.longitude,
        ).compareTo(
          _distanceSquared(
            position.latitude,
            position.longitude,
            b.latitude,
            b.longitude,
          ),
        ),
      );
      return readings.first;
    } catch (_) {
      return null;
    }
  }

  static GarbageBinReading? _readingFromFirestore(
    String documentId,
    Map<String, dynamic> json,
  ) {
    final fillPercent = _asInt(json['fillPercent']);
    final capacityKg = _asDouble(json['capacityKg']) ?? 120.0;
    final currentWeightKg = _asDouble(json['currentWeightKg']) ??
        capacityKg * (fillPercent ?? 0) / 100;
    final latitude = _asDouble(json['latitude']);
    final longitude = _asDouble(json['longitude']);

    if (fillPercent == null || latitude == null || longitude == null) {
      return null;
    }

    return GarbageBinReading(
      binId: (json['binId'] as String?)?.trim().isNotEmpty == true
          ? (json['binId'] as String).trim()
          : documentId,
      areaLabel:
          (json['areaLabel'] as String?)?.trim() ?? 'IoT community smart bin',
      fillPercent: fillPercent.clamp(0, 100).toInt(),
      capacityKg: capacityKg,
      currentWeightKg: currentWeightKg.clamp(0, capacityKg).toDouble(),
      latitude: latitude,
      longitude: longitude,
      updatedAt: _asDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double _distanceSquared(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    final latitudeDifference = latitudeA - latitudeB;
    final longitudeDifference = longitudeA - longitudeB;
    return latitudeDifference * latitudeDifference +
        longitudeDifference * longitudeDifference;
  }

  static String _areaLabel(double latitude, double longitude) {
    if (latitude >= 6.8 &&
        latitude <= 7.5 &&
        longitude >= 79.8 &&
        longitude <= 80.2) {
      return 'Colombo community smart bin';
    }
    if (latitude >= 7.0 &&
        latitude <= 7.6 &&
        longitude >= 80.3 &&
        longitude <= 80.9) {
      return 'Kandy community smart bin';
    }
    if (latitude >= 5.9 &&
        latitude <= 6.3 &&
        longitude >= 80.0 &&
        longitude <= 80.4) {
      return 'Galle community smart bin';
    }
    return 'Nearest community smart bin';
  }
}
