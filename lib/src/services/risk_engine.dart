enum RiskLevel { low, medium, high }

class RiskAssessment {
  const RiskAssessment({
    required this.level,
    required this.score,
    required this.guidance,
    required this.isModelResult,
  });

  final RiskLevel level;
  final double score;
  final String guidance;
  final bool isModelResult;
}

class RiskEngine {
  const RiskEngine();

  RiskAssessment flood({
    required double rainfall24h,
    required double waterLevel,
    required double drainage,
  }) {
    final score = ((rainfall24h / 200) * 0.45 +
            (waterLevel / 5) * 0.4 +
            (1 - drainage / 100) * 0.15)
        .clamp(0.0, 1.0);
    return _assessment(
      score,
      high: 'Move away from waterways and follow official evacuation advice.',
      medium: 'Monitor water levels and prepare essential items.',
      low: 'Conditions appear lower risk. Continue monitoring official alerts.',
    );
  }

  RiskAssessment landslide({
    required double rainfall72h,
    required double slope,
    required double soilMoisture,
  }) {
    final score = ((rainfall72h / 400) * 0.4 +
            (slope / 60) * 0.3 +
            (soilMoisture / 100) * 0.3)
        .clamp(0.0, 1.0);
    return _assessment(
      score,
      high: 'Leave steep or unstable ground and contact local authorities.',
      medium: 'Watch for cracks, leaning trees, and unusual water flow.',
      low: 'No strong risk signal from these inputs. Stay weather-aware.',
    );
  }

  RiskAssessment _assessment(
    double score, {
    required String high,
    required String medium,
    required String low,
  }) {
    if (score >= 0.7) {
      return RiskAssessment(
        level: RiskLevel.high,
        score: score,
        guidance: high,
        isModelResult: false,
      );
    }
    if (score >= 0.4) {
      return RiskAssessment(
        level: RiskLevel.medium,
        score: score,
        guidance: medium,
        isModelResult: false,
      );
    }
    return RiskAssessment(
      level: RiskLevel.low,
      score: score,
      guidance: low,
      isModelResult: false,
    );
  }
}
