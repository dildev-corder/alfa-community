import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionResult {
  const DetectionResult({
    required this.detected,
    required this.confidence,
    required this.isDemo,
  });

  final bool detected;
  final double confidence;
  final bool isDemo;
}

class ElephantDetector {
  Interpreter? _interpreter;

  Future<bool> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/elephant_model.tflite',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DetectionResult> analyze(File image) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      final seed = await image.length();
      final confidence = 0.72 + Random(seed).nextDouble() * 0.22;
      return DetectionResult(
        detected: true,
        confidence: confidence,
        isDemo: true,
      );
    }

    final input = await _preprocess(image);
    final outputShape = interpreter.getOutputTensor(0).shape;
    final output = _zeros(outputShape);
    interpreter.run(input, output);
    final confidence = _decodeConfidence(output);

    return DetectionResult(
      detected: confidence >= 0.45,
      confidence: confidence,
      isDemo: false,
    );
  }

  Future<List<List<List<List<double>>>>> _preprocess(File imageFile) async {
    final decoded = img.decodeImage(await imageFile.readAsBytes());
    if (decoded == null) {
      throw const FormatException('Could not decode image.');
    }

    final resized = img.copyResize(decoded, width: 640, height: 640);
    return [
      List.generate(
        640,
        (y) => List.generate(640, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    ];
  }

  Object _zeros(List<int> shape) {
    if (shape.length == 1) {
      return List<double>.filled(shape.first, 0);
    }
    return List.generate(shape.first, (_) => _zeros(shape.sublist(1)));
  }

  double _decodeConfidence(Object output) {
    final tensor = output as List<dynamic>;
    if (tensor.isEmpty) return 0;
    final first = tensor.first;

    if (first is List && first.isNotEmpty && first.first is List) {
      final matrix = first.cast<List<dynamic>>();
      final rows = matrix.length;
      final cols = matrix.first.length;

      // NMS exports are commonly [1, N, 6]: x1, y1, x2, y2, score, class.
      if (cols >= 6) {
        return matrix
            .map((row) => (row[4] as num).toDouble())
            .fold<double>(0, max)
            .clamp(0.0, 1.0);
      }

      // Raw single-class YOLO exports are often [1, 5, N].
      if (rows >= 5) {
        return matrix[4]
            .map((value) => (value as num).toDouble())
            .fold<double>(0, max)
            .clamp(0.0, 1.0);
      }

      // Raw transposed exports can be [1, N, 5].
      if (cols >= 5) {
        return matrix
            .map((row) => (row[4] as num).toDouble())
            .fold<double>(0, max)
            .clamp(0.0, 1.0);
      }
    }

    return 0;
  }

  void close() => _interpreter?.close();
}
