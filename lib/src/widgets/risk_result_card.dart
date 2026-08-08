import 'package:flutter/material.dart';

import '../services/risk_engine.dart';

class RiskResultCard extends StatelessWidget {
  const RiskResultCard({super.key, required this.assessment});

  final RiskAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (assessment.level) {
      RiskLevel.low => (
          'LOW',
          const Color(0xFF2E7D52),
          Icons.check_circle_outline
        ),
      RiskLevel.medium => (
          'MEDIUM',
          const Color(0xFFC77800),
          Icons.warning_amber_rounded
        ),
      RiskLevel.high => (
          'HIGH',
          const Color(0xFFB3261E),
          Icons.dangerous_outlined
        ),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 9),
              Text(
                '$label RISK | ${(assessment.score * 100).round()}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(assessment.guidance, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 8),
          Text(
            assessment.isModelResult
                ? 'Calculated by the installed on-device model.'
                : 'Prototype rule score, not an official warning.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
