import 'package:flutter/material.dart';

import '../models/risk_prediction.dart';

class PredictionHistoryCard extends StatelessWidget {
  const PredictionHistoryCard({
    super.key,
    required this.predictions,
    required this.onClear,
  });

  final List<RiskPrediction> predictions;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Prediction history',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                if (predictions.isNotEmpty)
                  TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            const Text(
              'Recent inputs and outputs are stored on this device for comparison.',
              style: TextStyle(color: Color(0xFF68736D)),
            ),
            const SizedBox(height: 12),
            if (predictions.isEmpty)
              const Text('No predictions yet. Run an assessment to create one.')
            else
              for (final prediction in predictions.take(5)) ...[
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prediction.level.name.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                        '${(prediction.confidence * 100).toStringAsFixed(1)}%'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  prediction.inputs.entries
                      .map((entry) =>
                          '${entry.key}: ${entry.value.toStringAsFixed(1)}')
                      .join('  •  '),
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${prediction.createdAt.toLocal()} • ${prediction.isModelResult ? 'TFLite model' : 'development rule'}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF68736D)),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
