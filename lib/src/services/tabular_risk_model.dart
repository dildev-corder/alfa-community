import 'package:tflite_flutter/tflite_flutter.dart';

import 'risk_engine.dart';

class TabularRiskModel {
  TabularRiskModel({
    required this.assetPath,
    required this.highGuidance,
    required this.mediumGuidance,
    required this.lowGuidance,
  });

  final String assetPath;
  final String highGuidance;
  final String mediumGuidance;
  final String lowGuidance;
  Interpreter? _interpreter;
  String? lastError;

  Future<bool> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(assetPath);
      lastError = null;
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  Future<RiskAssessment?> predict(List<double> features) async {
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    if (features.any((value) => !value.isFinite)) {
      throw ArgumentError('All model inputs must be finite numbers.');
    }
    final inputShape = interpreter.getInputTensor(0).shape;
    if (inputShape.last != features.length) {
      throw StateError(
        'Model expects ${inputShape.last} features, received ${features.length}.',
      );
    }
    final outputShape = interpreter.getOutputTensor(0).shape;
    if (outputShape.last != 3) {
      throw StateError('Risk model must output three class probabilities.');
    }
    final output = [List<double>.filled(3, 0)];
    interpreter.run([features], output);

    var bestIndex = 0;
    for (var index = 1; index < output.first.length; index++) {
      if (output.first[index] > output.first[bestIndex]) bestIndex = index;
    }
    final confidence = output.first[bestIndex].clamp(0.0, 1.0);
    return RiskAssessment(
      level: RiskLevel.values[bestIndex],
      score: confidence,
      guidance: switch (RiskLevel.values[bestIndex]) {
        RiskLevel.low => lowGuidance,
        RiskLevel.medium => mediumGuidance,
        RiskLevel.high => highGuidance,
      },
      isModelResult: true,
    );
  }

  void close() => _interpreter?.close();
}
