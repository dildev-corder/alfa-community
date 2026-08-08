import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/safety_alert.dart';
import '../../services/alert_store.dart';
import '../../services/garbage_bin_sensor_service.dart';
import '../../services/garbage_classifier.dart';
import '../../services/location_service.dart';

class GarbageScreen extends StatefulWidget {
  const GarbageScreen({super.key});

  @override
  State<GarbageScreen> createState() => _GarbageScreenState();
}

class _GarbageScreenState extends State<GarbageScreen> {
  final _classifier = GarbageClassifier();
  final _binSensor = const GarbageBinSensorService();
  final _location = LocationService();
  File? _image;
  bool _busy = false;
  bool _loadingBin = true;
  bool _modelLoaded = false;
  GarbageClassification? _classification;
  GarbageBinReading? _binReading;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadBinReading();
  }

  Future<void> _loadModel() async {
    final loaded = await _classifier.load();
    if (mounted) setState(() => _modelLoaded = loaded);
  }

  Future<void> _loadBinReading() async {
    setState(() => _loadingBin = true);
    final position = await _location.currentPosition();
    final reading = await _binSensor.nearestBin(position);
    if (!mounted) return;
    setState(() {
      _binReading = reading;
      _loadingBin = false;
    });
  }

  Future<void> _pick(ImageSource source) async {
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 82);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _busy = true;
      _image = file;
      _classification = null;
    });
    final classification = await _classifier.classify(file);
    if (!mounted) return;
    setState(() {
      _classification = classification;
      _busy = false;
    });
  }

  Future<void> _submit() async {
    if (_image == null || _classification == null) return;
    setState(() => _busy = true);
    final position = await _location.currentPosition();
    await AlertStore().add(
      SafetyAlert(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: 'Waste report',
        message: _classification!.label,
        confidence: _classification!.confidence,
        createdAt: DateTime.now(),
        risk: AlertRisk.medium,
        latitude: position?.latitude,
        longitude: position?.longitude,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Waste report saved with available location.'),
      ),
    );
  }

  Future<void> _openDirections() async {
    final reading = _binReading;
    if (reading == null) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${reading.latitude},${reading.longitude}',
      'travelmode': 'walking',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps for directions.')),
      );
    }
  }

  @override
  void dispose() {
    _classifier.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classification = _classification;
    return Scaffold(
      appBar: AppBar(title: const Text('Clean Community')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _modelLoaded
                  ? Theme.of(context).colorScheme.primaryContainer
                  : const Color(0xFFFFE9C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _modelLoaded
                  ? 'Smart waste classification is active for citizen reports.'
                  : 'Waste classification is preparing. Bin capacity and directions are still available.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          _BinCapacityCard(
            reading: _binReading,
            loading: _loadingBin,
            onRefresh: _loadBinReading,
            onDirections: _openDirections,
          ),
          const SizedBox(height: 16),
          Text(
            'Waste intelligence',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: ColoredBox(
                color: const Color(0xFFDFE8E4),
                child: _image == null
                    ? const Center(
                        child: Icon(Icons.add_a_photo_outlined, size: 52),
                      )
                    : Image.file(_image!, fit: BoxFit.cover),
              ),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          if (classification != null) ...[
            const SizedBox(height: 14),
            Text(
              classification.isModelResult
                  ? 'Category: ${classification.label} | ${(classification.confidence * 100).toStringAsFixed(1)}%'
                  : classification.label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : () => _pick(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Take report photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _image == null || _busy ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Save community report'),
          ),
        ],
      ),
    );
  }
}

class _BinCapacityCard extends StatelessWidget {
  const _BinCapacityCard({
    required this.reading,
    required this.loading,
    required this.onRefresh,
    required this.onDirections,
  });

  final GarbageBinReading? reading;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final reading = this.reading;
    final fill = reading == null ? 0.0 : reading.fillPercent / 100;
    final color = reading == null
        ? Theme.of(context).colorScheme.primary
        : reading.isAlmostFull
            ? const Color(0xFFC84630)
            : reading.hasGoodSpace
                ? const Color(0xFF1F8A5B)
                : const Color(0xFFE09F3E);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(Icons.delete_outline_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reading?.areaLabel ?? 'Measuring smart bin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        reading == null
                            ? 'Reading weight sensor data...'
                            : '${reading.binId} | updated ${_timeText(reading.updatedAt)}',
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh sensor reading',
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 18,
                value: loading ? null : fill,
                color: color,
                backgroundColor: const Color(0xFFE8EFEA),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              reading == null
                  ? 'Waiting for weight sensor.'
                  : 'Bin is ${reading.fillPercent}% full. You can use ${reading.freePercent}% free space.',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            if (reading != null) ...[
              const SizedBox(height: 6),
              Text(
                '${reading.currentWeightKg.toStringAsFixed(1)} kg used / ${reading.capacityKg.toStringAsFixed(0)} kg capacity. Free capacity: ${reading.freeCapacityKg.toStringAsFixed(1)} kg.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onDirections,
                icon: const Icon(Icons.directions_walk_rounded),
                label: Text(
                  reading.isAlmostFull
                      ? 'Find direction to nearest bin'
                      : 'Get direction to this free bin',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _timeText(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
