import 'dart:convert';

enum AlertRisk { low, medium, high }

class SafetyAlert {
  const SafetyAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.confidence,
    required this.createdAt,
    required this.risk,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String type;
  final String message;
  final double confidence;
  final DateTime createdAt;
  final AlertRisk risk;
  final double? latitude;
  final double? longitude;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'message': message,
        'confidence': confidence,
        'createdAt': createdAt.toIso8601String(),
        'risk': risk.name,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory SafetyAlert.fromJson(Map<String, Object?> json) => SafetyAlert(
        id: json['id']! as String,
        type: json['type']! as String,
        message: json['message']! as String,
        confidence: (json['confidence']! as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt']! as String),
        risk: AlertRisk.values.byName(json['risk']! as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  static String encodeList(List<SafetyAlert> alerts) =>
      jsonEncode(alerts.map((alert) => alert.toJson()).toList());

  static List<SafetyAlert> decodeList(String source) =>
      (jsonDecode(source) as List<dynamic>)
          .map((item) => SafetyAlert.fromJson(item as Map<String, Object?>))
          .toList();
}
