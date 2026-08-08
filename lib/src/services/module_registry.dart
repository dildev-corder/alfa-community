import 'package:flutter/material.dart';

import '../models/location_profile.dart';
import '../models/safety_module.dart';

class ModuleRegistry {
  const ModuleRegistry();

  List<SafetyModule> modulesFor(
    LocationProfile profile, {
    required bool demoAll,
  }) {
    final latitude = profile.latitude;
    final longitude = profile.longitude;
    final hasLocation = latitude != null && longitude != null;

    // Broad relevance zones for the MVP, not official hazard boundaries.
    final centralHighlands = hasLocation &&
        latitude >= 6.6 &&
        latitude <= 7.8 &&
        longitude >= 80.3 &&
        longitude <= 81.1;
    final floodLowlands = hasLocation &&
        latitude >= 5.8 &&
        latitude <= 9.9 &&
        longitude >= 79.5 &&
        longitude <= 81.9 &&
        !centralHighlands;
    final dryZone = hasLocation &&
        latitude >= 7.0 &&
        latitude <= 9.8 &&
        longitude >= 80.0 &&
        longitude <= 81.9 &&
        !centralHighlands;

    bool active(bool regionalMatch) => demoAll || regionalMatch;
    String reason(bool regionalMatch, String matchReason) {
      if (demoAll) return 'Enabled for demonstration';
      if (!hasLocation) return 'Waiting for GPS or manual coordinates';
      return regionalMatch ? matchReason : 'Not prioritized for this location';
    }

    return [
      SafetyModule(
        id: ModuleId.elephant,
        name: 'Elephant watch',
        description: 'Camera detection and GPS alerts',
        icon: Icons.visibility_rounded,
        color: const Color(0xFFEA8C36),
        enabled: active(dryZone),
        reason: reason(dryZone, 'Dry-zone wildlife relevance profile'),
      ),
      SafetyModule(
        id: ModuleId.flood,
        name: 'Flood alerts',
        description: 'Estimate risk from rainfall and water level',
        icon: Icons.water_rounded,
        color: const Color(0xFF3278B7),
        enabled: active(floodLowlands),
        reason: reason(floodLowlands, 'Lowland flood relevance profile'),
      ),
      SafetyModule(
        id: ModuleId.landslide,
        name: 'Landslide risk',
        description: 'Assess rain, slope, and soil conditions',
        icon: Icons.landscape_rounded,
        color: const Color(0xFF8B6B4B),
        enabled: active(centralHighlands),
        reason: reason(centralHighlands, 'Central highlands relevance profile'),
      ),
      SafetyModule(
        id: ModuleId.garbage,
        name: 'Clean community',
        description: 'Classify and report waste issues',
        icon: Icons.recycling_rounded,
        color: const Color(0xFF4A8D63),
        enabled: true,
        reason: 'Available in every community',
      ),
    ];
  }
}
