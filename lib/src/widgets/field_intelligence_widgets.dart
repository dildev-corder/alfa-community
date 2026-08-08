import 'package:flutter/material.dart';

import '../services/risk_engine.dart';

class FieldIntelligenceShell extends StatelessWidget {
  const FieldIntelligenceShell({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF7EF), Color(0xFFF8FBF7)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: children,
        ),
      ),
    );
  }
}

class FieldRiskHero extends StatelessWidget {
  const FieldRiskHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.assessment,
    required this.modelReady,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final RiskAssessment? assessment;
  final bool modelReady;

  @override
  Widget build(BuildContext context) {
    final level = assessment?.level;
    final color = switch (level) {
      RiskLevel.high => const Color(0xFFFFD6D0),
      RiskLevel.medium => const Color(0xFFFFE4B8),
      RiskLevel.low => const Color(0xFFD9F6E7),
      null => const Color(0xFFE4F3EA),
    };
    final label = switch (level) {
      RiskLevel.high => 'High risk',
      RiskLevel.medium => 'Watch zone',
      RiskLevel.low => 'Stable',
      null => 'Measuring',
    };
    final score =
        assessment == null ? 'Live' : '${(assessment!.score * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073B2D), Color(0xFF0A7A4F)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const Spacer(),
              _HeroPill(text: modelReady ? 'AI ready' : 'AI standby'),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF123B2D),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  score,
                  style: const TextStyle(
                    color: Color(0xFF123B2D),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FieldMetricTile extends StatelessWidget {
  const FieldMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.progress,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF66736D),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE7EFEA),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class FieldGuidanceCard extends StatelessWidget {
  const FieldGuidanceCard({super.key, required this.assessment});

  final RiskAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final color = switch (assessment.level) {
      RiskLevel.low => const Color(0xFF1F8A5B),
      RiskLevel.medium => const Color(0xFFE09F3E),
      RiskLevel.high => const Color(0xFFC84630),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Field guidance',
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(assessment.guidance, style: const TextStyle(height: 1.4)),
                const SizedBox(height: 8),
                Text(
                  assessment.isModelResult
                      ? 'Generated by the installed on-device AI model.'
                      : 'Generated by the built-in safety engine.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FieldStatusCard extends StatelessWidget {
  const FieldStatusCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE5F3EC),
            child: Icon(icon, color: const Color(0xFF0A6B49)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
