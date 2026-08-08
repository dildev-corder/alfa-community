import 'package:flutter/material.dart';

import '../../models/risk_prediction.dart';
import '../../services/iot_sensor_service.dart';
import '../../services/risk_engine.dart';
import '../../services/risk_prediction_store.dart';
import '../../services/tabular_risk_model.dart';
import '../../widgets/field_intelligence_widgets.dart';
import '../../widgets/prediction_history_card.dart';

class FloodScreen extends StatefulWidget {
  const FloodScreen({super.key});

  @override
  State<FloodScreen> createState() => _FloodScreenState();
}

class _FloodScreenState extends State<FloodScreen> {
  final _model = TabularRiskModel(
    assetPath: 'assets/models/flood_model.tflite',
    highGuidance:
        'Move away from waterways and follow official evacuation advice.',
    mediumGuidance: 'Monitor water levels and prepare essential items.',
    lowGuidance:
        'Conditions appear lower risk. Continue monitoring official alerts.',
  );

  double _rainfall = 80;
  double _waterLevel = 1.5;
  double _drainage = 55;
  bool _modelLoaded = false;
  bool _assessing = true;
  RiskAssessment? _assessment;
  List<RiskPrediction> _history = const [];
  String _sourceMessage = 'Reading live flood network...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _model.load();
    final history = await const RiskPredictionStore().load(module: 'flood');
    if (!mounted) return;
    setState(() {
      _modelLoaded = loaded;
      _history = history;
    });
    await _refreshLiveAssessment(save: false);
  }

  Future<void> _loadHistory() async {
    final history = await const RiskPredictionStore().load(module: 'flood');
    if (mounted) setState(() => _history = history);
  }

  Future<void> _refreshLiveAssessment({bool save = true}) async {
    setState(() {
      _assessing = true;
      _sourceMessage = 'Syncing rainfall, water level, and drainage data...';
    });

    final reading = await const IotSensorService().latestEnvironment();
    if (reading != null) {
      _rainfall = reading.rainfallEstimateMm;
      _waterLevel = reading.waterLevelMeters;
      _drainage = reading.drainagePercent;
      _sourceMessage =
          'Live station ${reading.deviceId} updated at ${_timeText(reading.updatedAt)}.';
    } else {
      _sourceMessage =
          'Live network pending. Showing last calibrated field values.';
    }

    await _runAssessment(save: save);
  }

  Future<void> _runAssessment({required bool save}) async {
    final modelResult =
        await _model.predict([_rainfall, _waterLevel, _drainage]);
    final assessment = modelResult ??
        const RiskEngine().flood(
          rainfall24h: _rainfall,
          waterLevel: _waterLevel,
          drainage: _drainage,
        );

    if (save) {
      await const RiskPredictionStore().save(
        RiskPrediction(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          module: 'flood',
          createdAt: DateTime.now(),
          inputs: {
            'rainfall mm': _rainfall,
            'water m': _waterLevel,
            'drainage %': _drainage,
          },
          level: assessment.level,
          confidence: assessment.score,
          isModelResult: assessment.isModelResult,
        ),
      );
      await _loadHistory();
    }

    if (!mounted) return;
    setState(() {
      _assessment = assessment;
      _assessing = false;
    });
  }

  @override
  void dispose() {
    _model.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    return FieldIntelligenceShell(
      title: 'Flood Intelligence',
      children: [
        FieldRiskHero(
          eyebrow: 'Automatic flood measurement',
          title: 'Water risk command view',
          subtitle:
              'Location aware rainfall, river level, and drainage signals are converted into a clear public safety decision.',
          icon: Icons.water_drop_rounded,
          assessment: assessment,
          modelReady: _modelLoaded,
        ),
        const SizedBox(height: 16),
        FieldStatusCard(
          title: 'Live data source',
          message: _sourceMessage,
          icon: Icons.sensors_rounded,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FieldMetricTile(
                label: 'Rainfall 24h',
                value: _rainfall.toStringAsFixed(1),
                unit: 'mm',
                icon: Icons.cloudy_snowing,
                progress: _rainfall / 250,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FieldMetricTile(
                label: 'Water level',
                value: _waterLevel.toStringAsFixed(1),
                unit: 'm',
                icon: Icons.waves_rounded,
                progress: _waterLevel / 6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FieldMetricTile(
          label: 'Drainage capacity',
          value: _drainage.toStringAsFixed(0),
          unit: '%',
          icon: Icons.route_rounded,
          progress: _drainage / 100,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed:
              _assessing ? null : () => _refreshLiveAssessment(save: true),
          icon: _assessing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.autorenew_rounded),
          label: const Text('Refresh live assessment'),
        ),
        if (assessment != null) ...[
          const SizedBox(height: 16),
          FieldGuidanceCard(assessment: assessment),
        ],
        const SizedBox(height: 16),
        _CalibrationPanel(
          rainfall: _rainfall,
          waterLevel: _waterLevel,
          drainage: _drainage,
          onRainfall: (value) => setState(() => _rainfall = value),
          onWaterLevel: (value) => setState(() => _waterLevel = value),
          onDrainage: (value) => setState(() => _drainage = value),
          onApply: () => _runAssessment(save: true),
        ),
        const SizedBox(height: 16),
        PredictionHistoryCard(
          predictions: _history,
          onClear: () async {
            await const RiskPredictionStore().clear(module: 'flood');
            await _loadHistory();
          },
        ),
      ],
    );
  }

  static String _timeText(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _CalibrationPanel extends StatelessWidget {
  const _CalibrationPanel({
    required this.rainfall,
    required this.waterLevel,
    required this.drainage,
    required this.onRainfall,
    required this.onWaterLevel,
    required this.onDrainage,
    required this.onApply,
  });

  final double rainfall;
  final double waterLevel;
  final double drainage;
  final ValueChanged<double> onRainfall;
  final ValueChanged<double> onWaterLevel;
  final ValueChanged<double> onDrainage;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.tune_rounded),
        title: const Text('Advanced field calibration'),
        subtitle: const Text('For officer testing when live data is limited.'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _CalibrationSlider(
            label: 'Rainfall in 24 hours',
            value: rainfall,
            max: 250,
            unit: 'mm',
            onChanged: onRainfall,
          ),
          _CalibrationSlider(
            label: 'River or drain water level',
            value: waterLevel,
            max: 6,
            unit: 'm',
            onChanged: onWaterLevel,
          ),
          _CalibrationSlider(
            label: 'Drainage capacity',
            value: drainage,
            max: 100,
            unit: '%',
            onChanged: onDrainage,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: onApply,
              child: const Text('Apply calibration'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrationSlider extends StatelessWidget {
  const _CalibrationSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text('${value.toStringAsFixed(1)} $unit'),
            ],
          ),
          Slider(value: value, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}
