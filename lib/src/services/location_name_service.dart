import '../models/location_profile.dart';

class LocationNameService {
  const LocationNameService();

  String nameForProfile(LocationProfile profile) {
    final lat = profile.latitude;
    final lng = profile.longitude;
    if (lat == null || lng == null) return profile.label;
    return nameForCoordinates(lat, lng, fallback: profile.label);
  }

  String nameForCoordinates(
    double latitude,
    double longitude, {
    String fallback = 'Unknown area',
  }) {
    for (final area in _areas) {
      if (area.contains(latitude, longitude)) return area.name;
    }
    return fallback.trim().isEmpty ? 'Nearby community area' : fallback;
  }

  String districtForCoordinates(
    double latitude,
    double longitude, {
    String fallback = 'Unknown area',
  }) {
    for (final area in _areas) {
      if (area.contains(latitude, longitude)) return area.district;
    }
    return fallback.trim().isEmpty ? 'Nearby community area' : fallback;
  }
}

class _KnownArea {
  const _KnownArea({
    required this.name,
    required this.district,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final String name;
  final String district;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  bool contains(double latitude, double longitude) {
    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLng &&
        longitude <= maxLng;
  }
}

const _areas = [
  _KnownArea(
    name: 'Colombo',
    district: 'Colombo',
    minLat: 6.78,
    maxLat: 7.12,
    minLng: 79.78,
    maxLng: 80.10,
  ),
  _KnownArea(
    name: 'Kandy',
    district: 'Kandy',
    minLat: 7.18,
    maxLat: 7.42,
    minLng: 80.52,
    maxLng: 80.78,
  ),
  _KnownArea(
    name: 'Mahiyanganaya',
    district: 'Badulla',
    minLat: 7.20,
    maxLat: 7.55,
    minLng: 80.85,
    maxLng: 81.22,
  ),
  _KnownArea(
    name: 'Ampara',
    district: 'Ampara',
    minLat: 7.08,
    maxLat: 7.40,
    minLng: 81.45,
    maxLng: 81.90,
  ),
  _KnownArea(
    name: 'Badulla',
    district: 'Badulla',
    minLat: 6.85,
    maxLat: 7.12,
    minLng: 80.82,
    maxLng: 81.12,
  ),
  _KnownArea(
    name: 'Nuwara Eliya',
    district: 'Nuwara Eliya',
    minLat: 6.86,
    maxLat: 7.08,
    minLng: 80.62,
    maxLng: 80.90,
  ),
  _KnownArea(
    name: 'Rathnapura',
    district: 'Rathnapura',
    minLat: 6.48,
    maxLat: 6.82,
    minLng: 80.25,
    maxLng: 80.55,
  ),
];
