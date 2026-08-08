import 'package:flutter/material.dart';

enum ModuleId { elephant, flood, landslide, garbage }

class SafetyModule {
  const SafetyModule({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.reason,
  });

  final ModuleId id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool enabled;
  final String reason;
}
