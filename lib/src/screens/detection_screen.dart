import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:image_picker/image_picker.dart';

import '../models/safety_alert.dart';
import '../services/alert_store.dart';
import '../services/elephant_detector.dart';
import '../services/ezviz_camera_service.dart';
import '../services/iot_sensor_service.dart';
import '../services/location_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  final _detector = ElephantDetector();
  final _location = LocationService();
  final _store = AlertStore();
  bool _busy = false;
  bool _realModelLoaded = false;
  File? _image;
  DetectionResult? _result;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final loaded = await _detector.initialize();
    if (mounted) setState(() => _realModelLoaded = loaded);
  }

  Future<void> _capture(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1280,
    );
    if (photo == null) return;

    setState(() {
      _busy = true;
      _image = File(photo.path);
      _result = null;
    });

    try {
      final result = await _detector.analyze(_image!);
      if (result.detected && result.confidence >= 0.7) {
        final position = await _location.currentPosition();
        await _store.add(
          SafetyAlert(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: 'Elephant',
            message:
                'Elephant detected near your location. Keep a safe distance.',
            confidence: result.confidence,
            createdAt: DateTime.now(),
            risk: AlertRisk.high,
            latitude: position?.latitude,
            longitude: position?.longitude,
          ),
        );
      }
      if (mounted) setState(() => _result = result);
    } on UnsupportedError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elephant Safety')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_realModelLoaded)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9C7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Elephant AI safety is preparing. Live camera and perimeter alerts remain available.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 16),
          _EzvizCameraPanel(detector: _detector),
          const SizedBox(height: 16),
          const _BeamSensorPanel(),
          const SizedBox(height: 18),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ColoredBox(
                color: const Color(0xFFDFE8E4),
                child: _image == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 54),
                          SizedBox(height: 12),
                          Text('Capture or choose an image'),
                        ],
                      )
                    : Image.file(_image!, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_busy) const LinearProgressIndicator(),
          if (_result != null) _ResultCard(result: _result!),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : () => _capture(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Open camera'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _capture(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose test image'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Safety note: AI results can be wrong. Never approach wildlife and always follow local authority guidance.',
            style: TextStyle(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _EzvizCameraPanel extends StatefulWidget {
  const _EzvizCameraPanel({required this.detector});

  final ElephantDetector detector;

  @override
  State<_EzvizCameraPanel> createState() => _EzvizCameraPanelState();
}

class _EzvizCameraPanelState extends State<_EzvizCameraPanel> {
  final _service = const EzvizCameraService();
  final _location = LocationService();
  final _store = AlertStore();
  VlcPlayerController? _controller;
  Timer? _watchTimer;
  bool _loading = true;
  bool _connecting = false;
  bool _hasDefaultCamera = false;
  bool _analyzing = false;
  bool _watching = false;
  DetectionResult? _liveResult;
  AlertRisk? _liveRisk;
  DateTime? _lastAlertAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCamera();
  }

  Future<void> _loadSavedCamera() async {
    final savedUrl = await _service.loadStreamUrl();
    if (!mounted) return;
    setState(() {
      _hasDefaultCamera = savedUrl != null;
      _loading = false;
    });
    if (savedUrl != null) {
      await _connect(savedUrl, false);
    }
  }

  void _onVlcChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _connect([String? value, bool save = true]) async {
    final candidates = await _service.candidateStreamUris(value);
    if (candidates.isEmpty) {
      setState(
        () => _error =
            'Default EZVIZ camera is not configured for this APK build.',
      );
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    await _disposeController();
    final uri = candidates.first;
    final controller = VlcPlayerController.network(
      uri.toString(),
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(1800),
        ]),
        http: VlcHttpOptions([
          VlcHttpOptions.httpReconnect(true),
        ]),
        rtp: VlcRtpOptions([
          VlcRtpOptions.rtpOverRtsp(true),
        ]),
      ),
    );
    controller.addListener(_onVlcChanged);

    if (save) await _service.saveStreamUrl(uri.toString());
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _connecting = false;
      _error = null;
    });
  }

  Future<void> _analyzeLiveFrame({bool silent = false}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      if (!silent) {
        setState(() => _error = 'Connect the live camera before AI detection.');
      }
      return;
    }
    if (_analyzing) return;

    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      final bytes = await controller.takeSnapshot();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Live camera snapshot failed.');
      }
      final file = File(
        '${Directory.systemTemp.path}/alpha_live_elephant_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);

      final result = await widget.detector.analyze(file);
      final risk = _riskFor(result);
      if (result.detected && risk != AlertRisk.low) {
        await _sendLiveAlert(result, risk);
      }

      if (!mounted) return;
      setState(() {
        _liveResult = result;
        _liveRisk = risk;
        _analyzing = false;
      });

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Live stream risk: ${_riskLabel(risk)}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = 'Could not analyze live frame: $error';
      });
    }
  }

  Future<void> _sendLiveAlert(DetectionResult result, AlertRisk risk) async {
    final now = DateTime.now();
    final lastAlert = _lastAlertAt;
    if (lastAlert != null && now.difference(lastAlert).inSeconds < 60) {
      return;
    }

    final position = await _location.currentPosition();
    await _store.add(
      SafetyAlert(
        id: now.microsecondsSinceEpoch.toString(),
        type: 'Elephant',
        message:
            'Live field camera detected elephant risk: ${_riskLabel(risk)}. Keep distance and alert nearby citizens.',
        confidence: result.confidence,
        createdAt: now,
        risk: risk,
        latitude: position?.latitude,
        longitude: position?.longitude,
      ),
    );
    _lastAlertAt = now;
  }

  void _toggleWatch() {
    if (_watching) {
      _watchTimer?.cancel();
      setState(() => _watching = false);
      return;
    }
    setState(() => _watching = true);
    unawaited(_analyzeLiveFrame(silent: true));
    _watchTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_analyzeLiveFrame(silent: true)),
    );
  }

  AlertRisk _riskFor(DetectionResult result) {
    if (!result.detected || result.confidence < 0.55) return AlertRisk.low;
    if (result.confidence >= 0.8) return AlertRisk.high;
    return AlertRisk.medium;
  }

  String _riskLabel(AlertRisk risk) => switch (risk) {
        AlertRisk.low => 'Low',
        AlertRisk.medium => 'Medium',
        AlertRisk.high => 'High',
      };

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onVlcChanged);
    await controller?.dispose();
  }

  Future<void> _disconnect() async {
    _watchTimer?.cancel();
    setState(() {
      _watching = false;
      _error = null;
    });
    await _disposeController();
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final connected = controller != null && controller.value.isInitialized;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFEAF3EA),
                child: Icon(Icons.videocam_rounded, color: Color(0xFF194D36)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live field camera',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('Live stream, risk detection, and alert automation.'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ColoredBox(
                color: const Color(0xFF101D18),
                child: _loading || _connecting
                    ? const Center(child: CircularProgressIndicator())
                    : controller != null
                        ? VlcPlayer(
                            controller: controller,
                            aspectRatio: 16 / 9,
                            placeholder: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.videocam_off_rounded,
                                  color: Colors.white,
                                  size: 44,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'No camera connected',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _CameraStatusPill(
            configured: _hasDefaultCamera,
            connected: connected,
          ),
          if (_liveResult != null && _liveRisk != null) ...[
            const SizedBox(height: 10),
            _LiveRiskCard(result: _liveResult!, risk: _liveRisk!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _connecting ? null : () => _connect(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Connect default camera'),
              ),
              OutlinedButton.icon(
                onPressed: controller == null ? null : _disconnect,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Disconnect'),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    connected && !_analyzing ? () => _analyzeLiveFrame() : null,
                icon: _analyzing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.center_focus_strong_rounded),
                label: const Text('Analyze live frame'),
              ),
              OutlinedButton.icon(
                onPressed: connected ? _toggleWatch : null,
                icon: Icon(
                  _watching ? Icons.pause_circle_rounded : Icons.radar_rounded,
                ),
                label: Text(_watching ? 'Stop AI watch' : 'Start AI watch'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CameraStatusPill extends StatelessWidget {
  const _CameraStatusPill({
    required this.configured,
    required this.connected,
  });

  final bool configured;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? const Color(0xFF1D6B49)
        : configured
            ? const Color(0xFFE78A00)
            : const Color(0xFFB00020);
    final text = connected
        ? 'Default camera connected'
        : configured
            ? 'Default camera ready'
            : 'Default camera not configured';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected
                ? Icons.videocam_rounded
                : configured
                    ? Icons.settings_input_antenna_rounded
                    : Icons.error_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeamSensorPanel extends StatefulWidget {
  const _BeamSensorPanel();

  @override
  State<_BeamSensorPanel> createState() => _BeamSensorPanelState();
}

class _BeamSensorPanelState extends State<_BeamSensorPanel> {
  final _iot = const IotSensorService();
  final _store = AlertStore();
  final _location = LocationService();
  Timer? _timer;
  bool _loading = false;
  bool _watching = false;
  ElephantBeamReading? _reading;
  DateTime? _lastAlertAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh(silent: true));
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final reading = await _iot.latestElephantBeam();
    if (!mounted) return;
    if (reading == null) {
      setState(() {
        _loading = false;
        _error = 'No perimeter beam reading found in Firebase.';
      });
      return;
    }
    if (reading.isHighRisk) await _sendAlert(reading);
    if (!mounted) return;
    setState(() {
      _reading = reading;
      _loading = false;
    });
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reading.beamBroken
                ? 'Beam broken: elephant risk alert saved.'
                : 'Beam normal.',
          ),
        ),
      );
    }
  }

  Future<void> _sendAlert(ElephantBeamReading reading) async {
    final now = DateTime.now();
    final last = _lastAlertAt;
    if (last != null && now.difference(last).inSeconds < 60) return;
    final position = await _location.currentPosition();
    await _store.add(
      SafetyAlert(
        id: now.microsecondsSinceEpoch.toString(),
        type: 'Elephant beam',
        message:
            'Single beam sensor broken on ${reading.deviceId}. Possible elephant crossing risk.',
        confidence: 0.9,
        createdAt: now,
        risk: AlertRisk.high,
        latitude: position?.latitude,
        longitude: position?.longitude,
      ),
    );
    _lastAlertAt = now;
  }

  void _toggleWatch() {
    if (_watching) {
      _timer?.cancel();
      setState(() => _watching = false);
      return;
    }
    setState(() => _watching = true);
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refresh(silent: true)),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    final highRisk = reading?.isHighRisk ?? false;
    final color = highRisk ? const Color(0xFFB00020) : const Color(0xFF1D6B49);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.sensors_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Perimeter beam sensor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        reading == null
                            ? 'Waiting for perimeter crossing status.'
                            : '${reading.deviceId} | ${reading.beamBroken ? 'Beam broken' : 'Beam normal'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _loading ? null : () => _refresh(),
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh beam'),
                ),
                OutlinedButton.icon(
                  onPressed: _toggleWatch,
                  icon: Icon(
                    _watching
                        ? Icons.pause_circle_rounded
                        : Icons.radar_rounded,
                  ),
                  label:
                      Text(_watching ? 'Stop beam watch' : 'Start beam watch'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRiskCard extends StatelessWidget {
  const _LiveRiskCard({required this.result, required this.risk});

  final DetectionResult result;
  final AlertRisk risk;

  @override
  Widget build(BuildContext context) {
    final color = switch (risk) {
      AlertRisk.low => const Color(0xFF1D6B49),
      AlertRisk.medium => const Color(0xFFE78A00),
      AlertRisk.high => const Color(0xFFB00020),
    };
    final percent = (result.confidence * 100).toStringAsFixed(1);
    final label = switch (risk) {
      AlertRisk.low => 'Low live risk',
      AlertRisk.medium => 'Medium live risk - alert saved',
      AlertRisk.high => 'High live risk - alert saved',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label\nConfidence: $percent%',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final DetectionResult result;

  @override
  Widget build(BuildContext context) {
    final percent = (result.confidence * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD9D4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Elephant detected\nConfidence: $percent%',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
