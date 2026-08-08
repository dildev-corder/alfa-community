import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class GarbageClassification {
  const GarbageClassification({
    required this.label,
    required this.confidence,
    required this.isModelResult,
  });

  final String label;
  final double confidence;
  final bool isModelResult;
}

class GarbageClassifier {
  static const _modelAsset = 'assets/models/garbage_model.tflite';
  static const _labelsAsset = 'assets/models/garbage_model.labels.json';
  static const _defaultLabels = [
    'Overflowing waste',
    'Illegal dumping',
    'Mixed recyclable waste',
  ];

  Interpreter? _interpreter;
  List<String> _labels = _defaultLabels;

  bool get isLoaded => _interpreter != null;

  Future<bool> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      _labels = await _loadLabels();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<GarbageClassification> classify(File imageFile) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      return const GarbageClassification(
        label: 'Model missing: install garbage_model.tflite',
        confidence: 0,
        isModelResult: false,
      );
    }

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const GarbageClassification(
        label: 'Could not read image',
        confidence: 0,
        isModelResult: false,
      );
    }

    final resized = img.copyResize(decoded, width: 224, height: 224);
    final input = [
      List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 127.5 - 1.0,
            pixel.g / 127.5 - 1.0,
            pixel.b / 127.5 - 1.0,
          ];
        }),
      ),
    ];

    final outputSize = interpreter.getOutputTensor(0).shape.last;
    final output = [List<double>.filled(outputSize, 0)];
    interpreter.run(input, output);

    var bestIndex = 0;
    for (var index = 1; index < output.first.length; index++) {
      if (output.first[index] > output.first[bestIndex]) bestIndex = index;
    }
    return GarbageClassification(
      label:
          bestIndex < _labels.length ? _labels[bestIndex] : 'Class $bestIndex',
      confidence: output.first[bestIndex].clamp(0.0, 1.0),
      isModelResult: true,
    );
  }

  Future<List<String>> _loadLabels() async {
    try {
      final source = await rootBundle.loadString(_labelsAsset);
      return (jsonDecode(source) as List<dynamic>).cast<String>();
    } catch (_) {
      return _defaultLabels;
    }
  }

  void close() => _interpreter?.close();
}
