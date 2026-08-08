import 'package:shared_preferences/shared_preferences.dart';

class EzvizCameraService {
  const EzvizCameraService();

  static const _streamUrlKey = 'ezviz.camera.streamUrl';
  static const _buildStreamUrl = String.fromEnvironment('EZVIZ_STREAM_URL');
  static const _buildCameraIp = String.fromEnvironment('EZVIZ_CAMERA_IP');
  static const _buildVerificationCode =
      String.fromEnvironment('EZVIZ_VERIFICATION_CODE');

  String? get buildDefaultStreamUrl {
    final value = _buildStreamUrl.trim();
    return value.isEmpty ? null : value;
  }

  Future<String?> loadStreamUrl() async {
    final buildUrl = buildDefaultStreamUrl ?? _buildUrlFromParts();
    if (buildUrl != null) return buildUrl;

    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_streamUrlKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> saveStreamUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streamUrlKey, url.trim());
  }

  Future<void> clearStreamUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_streamUrlKey);
  }

  Future<List<Uri>> candidateStreamUris([String? preferredUrl]) async {
    final preferred = (preferredUrl ?? await loadStreamUrl())?.trim();
    if (preferred == null || preferred.isEmpty) return const [];

    final uri = Uri.tryParse(preferred);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return const [];

    final base = uri.replace(path: '', query: null, fragment: null);
    final paths = <String>[
      '/Streaming/Channels/101',
      '/h264/ch1/main/av_stream',
      '/Streaming/channels/1',
      '/Streaming/Channels/102',
      '/ch1/main',
      '/ch1/sub',
      uri.path,
    ];

    final unique = <String>{};
    return [
      for (final path in paths)
        if (path.trim().isNotEmpty &&
            unique.add(base.replace(path: path).toString()))
          base.replace(path: path),
    ];
  }

  String? _buildUrlFromParts() {
    final cameraAddress = _CameraAddress.parse(_buildCameraIp);
    final code = _buildVerificationCode.trim();
    if (cameraAddress == null || code.isEmpty) return null;
    return Uri(
      scheme: 'rtsp',
      userInfo: 'admin:$code',
      host: cameraAddress.host,
      port: cameraAddress.port,
      path: '/Streaming/Channels/101',
    ).toString();
  }
}

class _CameraAddress {
  const _CameraAddress({required this.host, required this.port});

  final String host;
  final int port;

  static _CameraAddress? parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = trimmed.contains('://') ? trimmed : 'rtsp://$trimmed';
    final uri = Uri.tryParse(withScheme);
    final host = uri?.host.trim();
    if (uri == null || host == null || host.isEmpty) return null;

    return _CameraAddress(
      host: host,
      port: uri.hasPort ? uri.port : 554,
    );
  }
}
