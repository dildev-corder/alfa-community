import 'package:flutter/material.dart';

import '../../models/risk_prediction.dart';
import '../../services/iot_sensor_service.dart';
import '../../services/risk_engine.dart';
import '../../services/risk_prediction_store.dart';
import '../../services/tabular_risk_model.dart';
import '../../widgets/field_intelligence_widgets.dart';
import '../../widgets/prediction_history_card.dart';

class LandslideScreen extends StatefulWidget {
  const LandslideScreen({super.key});

  @override
  State<LandslideScreen> createState() => _LandslideScreenState();
}

class _LandslideScreenState extends State<LandslideScreen> {
  final _model = TabularRiskModel(
    assetPath: 'assets/models/landslide_model.tflite',
    highGuidance:
        'Leave steep or unstable ground and contact local authorities.',
    mediumGuidance: 'Watch for cracks, leaning trees, and unusual water flow.',
    lowGuidance: 'No strong risk signal from these inputs. Stay weather-aware.',
  );

  double _rainfall = 120;
  double _slope = 25;
  double _soilMoisture = 60;
  bool _modelLoaded = false;
  bool _assessing = true;
  RiskAssessment? _assessment;
  List<RiskPrediction> _history = const [];
  String _sourceMessage = 'Reading hillside stability network...';
  String _movementSignal = 'No movement signal';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _model.load();
    final history = await const RiskPredictionStore().load(module: 'landslide');
    if (!mounted) return;
    setState(() {
      _modelLoaded = loaded;
      _history = history;
    });
    await _refreshLiveAssessment(save: false);
  }

  Future<void> _loadHistory() async {
    final history = await const RiskPredictionStore().load(module: 'landslide');
    if (mounted) setState(() => _history = history);
  }

  Future<void> _refreshLiveAssessment({bool save = true}) async {
    setState(() {
      _assessing = true;
      _sourceMessage = 'Syncing rainfall, slope, and soil readings...';
    });

    final reading = await const IotSensorService().latestEnvironment();
    if (reading != null) {
      _rainfall = (reading.rainfallEstimateMm * 1.8).clamp(0, 500).toDouble();
      _slope = reading.slopeDegrees;
      _soilMoisture = reading.soilMoisturePercent;
      _movementSignal = reading.vibrationDigital
          ? 'Movement detected'
          : reading.tiltMagnitude > 0.45
              ? 'Tilt change detected'
              : 'No movement signal';
      _sourceMessage =
          'Live station ${reading.deviceId} updated at ${_timeText(reading.updatedAt)}.';
    } else {
      _movementSignal = 'Live sensor pending';
      _sourceMessage =
          'Live network pending. Showing last calibrated field values.';
    }

    await _runAssessment(save: save);
  }

  Future<void> _runAssessment({required bool save}) async {
    final modelResult =
        await _model.predict([_rainfall, _slope, _soilMoisture]);
    final assessment = modelResult ??
        const RiskEngine().landslide(
          rainfall72h: _rainfall,
          slope: _slope,
          soilMoisture: _soilMoisture,
        );

    if (save) {
      await const RiskPredictionStore().save(
        RiskPrediction(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          module: 'landslide',
          createdAt: DateTime.now(),
          inputs: {
            'rainfall mm': _rainfall,
            'slope deg': _slope,
            'moisture %': _soilMoisture,
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
      title: 'Landslide Intelligence',
      children: [
        FieldRiskHero(
          eyebrow: 'Automatic hillside measurement',
          title: 'Slope stability command view',
          subtitle:
              'Rainfall, terrain angle, soil saturation, and movement signals are converted into a simple risk decision.',
          icon: Icons.terrain_rounded,
          assessment: assessment,
          modelReady: _modelLoaded,
        ),
        const SizedBox(height: 16),
        FieldStatusCard(
          title: 'Live data source',
          message: _sourceMessage,
          icon: Icons.cell_tower_rounded,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FieldMetricTile(
                label: 'Rainfall 72h',
                value: _rainfall.toStringAsFixed(1),
                unit: 'mm',
                icon: Icons.water_drop_rounded,
                progress: _rainfall / 500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FieldMetricTile(
                label: 'Terrain slope',
                value: _slope.toStringAsFixed(1),
                unit: 'deg',
                icon: Icons.landscape_rounded,
                progress: _slope / 70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FieldMetricTile(
                label: 'Soil moisture',
                value: _soilMoisture.toStringAsFixed(0),
                unit: '%',
                icon: Icons.grass_rounded,
                progress: _soilMoisture / 100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FieldMetricTile(
                label: 'Movement',
                value: _movementSignal.startsWith('No') ? 'Clear' : 'Alert',
                unit: '',
                icon: Icons.vibration_rounded,
                progress: _movementSignal.startsWith('No') ? 0.12 : 0.9,
              ),
            ),
          ],
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
          slope: _slope,
          soilMoisture: _soilMoisture,
          onRainfall: (value) => setState(() => _rainfall = value),
          onSlope: (value) => setState(() => _slope = value),
          onSoilMoisture: (value) => setState(() => _soilMoisture = value),
          onApply: () => _runAssessment(save: true),
        ),
        const SizedBox(height: 16),
        PredictionHistoryCard(
          predictions: _history,
          onClear: () async {
            await const RiskPredictionStore().clear(module: 'landslide');
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
    required this.slope,
    required this.soilMoisture,
    required this.onRainfall,
    required this.onSlope,
    required this.onSoilMoisture,
    required this.onApply,
  });

  final double rainfall;
  final double slope;
  final double soilMoisture;
  final ValueChanged<double> onRainfall;
  final ValueChanged<double> onSlope;
  final ValueChanged<double> onSoilMoisture;
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
            label: 'Rainfall in 72 hours',
            value: rainfall,
            max: 500,
            unit: 'mm',
            onChanged: onRainfall,
          ),
          _CalibrationSlider(
            label: 'Terrain slope',
            value: slope,
            max: 70,
            unit: 'degrees',
            onChanged: onSlope,
          ),
          _CalibrationSlider(
            label: 'Soil moisture',
            value: soilMoisture,
            max: 100,
            unit: '%',
            onChanged: onSoilMoisture,
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
