import '../services/risk_engine.dart';

class RiskPrediction {
  const RiskPrediction({
    required this.id,
    required this.module,
    required this.createdAt,
    required this.inputs,
    required this.level,
    required this.confidence,
    required this.isModelResult,
  });

  final String id;
  final String module;
  final DateTime createdAt;
  final Map<String, double> inputs;
  final RiskLevel level;
  final double confidence;
  final bool isModelResult;

  Map<String, dynamic> toJson() => {
        'id': id,
        'module': module,
        'createdAt': createdAt.toIso8601String(),
        'inputs': inputs,
        'level': level.name,
        'confidence': confidence,
        'isModelResult': isModelResult,
      };

  factory RiskPrediction.fromJson(Map<String, dynamic> json) => RiskPrediction(
        id: json['id'] as String,
        module: json['module'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        inputs: (json['inputs'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
        level: RiskLevel.values.byName(json['level'] as String),
        confidence: (json['confidence'] as num).toDouble(),
        isModelResult: json['isModelResult'] as bool,
      );
}
