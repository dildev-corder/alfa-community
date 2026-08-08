class LocationProfile {
  const LocationProfile({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.isLive,
  });

  final String label;
  final double? latitude;
  final double? longitude;
  final bool isLive;

  String get coordinates {
    if (latitude == null || longitude == null) return 'Location unavailable';
    return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
  }

  String get displayLabel {
    if (label.trim().isEmpty || label == 'Live GPS location') {
      return 'Nearby community area';
    }
    return label;
  }
}
