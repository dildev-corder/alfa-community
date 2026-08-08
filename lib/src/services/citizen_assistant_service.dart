import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AssistantReply {
  const AssistantReply({
    required this.text,
    required this.engineLabel,
    this.diagnostic,
  });

  final String text;
  final String engineLabel;
  final String? diagnostic;
}

class AssistantOnlineConfig {
  const AssistantOnlineConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
  });

  final String endpoint;
  final String apiKey;
  final String model;

  bool get isConfigured {
    final normalizedEndpoint = endpoint.trim().toLowerCase();
    if (normalizedEndpoint.isEmpty) return false;
    if (normalizedEndpoint.contains('api.openai.com')) {
      return apiKey.trim().isNotEmpty;
    }
    return true;
  }
}

enum _AssistantIntent {
  flood,
  landslide,
  elephant,
  garbage,
  emergency,
  general
}

class CitizenAssistantService {
  CitizenAssistantService({http.Client? client})
      : _client = client ?? http.Client();

  static const _buildEndpoint = String.fromEnvironment(
    'GEN_AI_ENDPOINT',
    defaultValue: 'https://api.openai.com/v1/responses',
  );
  static const _buildApiKey = String.fromEnvironment('GEN_AI_API_KEY');
  static const _buildModel = String.fromEnvironment(
    'GEN_AI_MODEL',
    defaultValue: 'gpt-4.1-mini',
  );
  static const _endpointKey = 'assistant.genai.endpoint';
  static const _apiKeyKey = 'assistant.genai.api_key';
  static const _modelKey = 'assistant.genai.model';

  static bool get buildOnlineConfigured => _buildEndpoint.isNotEmpty;

  final http.Client _client;

  Future<AssistantOnlineConfig> loadOnlineConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return AssistantOnlineConfig(
      endpoint: prefs.getString(_endpointKey) ?? _buildEndpoint,
      apiKey: prefs.getString(_apiKeyKey) ?? _buildApiKey,
      model: prefs.getString(_modelKey) ?? _buildModel,
    );
  }

  Future<void> saveOnlineConfig(AssistantOnlineConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_endpointKey, config.endpoint.trim());
    await prefs.setString(_apiKeyKey, config.apiKey.trim());
    await prefs.setString(_modelKey, config.model.trim());
  }

  Future<void> clearOnlineConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_endpointKey);
    await prefs.remove(_apiKeyKey);
    await prefs.remove(_modelKey);
  }

  Future<AssistantReply> ask(String question) async {
    final config = await loadOnlineConfig();
    if (config.isConfigured) {
      final onlineReply = await _askOnline(question, config);
      if (onlineReply != null) return onlineReply;
    }

    await Future<void>.delayed(const Duration(milliseconds: 220));
    return AssistantReply(
      text: _generateOfflineAnswer(question),
      engineLabel: config.isConfigured
          ? 'OFFLINE GEN AI - ONLINE FAILED'
          : 'OFFLINE GEN AI',
      diagnostic: config.isConfigured
          ? 'Online endpoint did not return a usable answer.'
          : null,
    );
  }

  Future<AssistantReply?> _askOnline(
    String question,
    AssistantOnlineConfig config,
  ) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (config.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${config.apiKey}',
      };
      final response = await _client
          .post(
            Uri.parse(config.endpoint),
            headers: headers,
            body: jsonEncode(_requestBody(question, config)),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      final answer = _extractAnswer(decoded);
      if (answer == null || answer.trim().isEmpty) return null;

      return AssistantReply(
        text: answer.trim(),
        engineLabel: 'ONLINE GEN AI',
      );
    } catch (_) {
      return null;
    }
  }

  String? extractAnswerForTest(Object? decoded) => _extractAnswer(decoded);

  Map<String, Object> _requestBody(
    String question,
    AssistantOnlineConfig config,
  ) {
    const systemPrompt =
        'You are Alpha Community safety assistant. Give concise, practical disaster and community guidance. Official emergency instructions always override app guidance.';
    final endpoint = config.endpoint.toLowerCase();

    if (endpoint.contains('/v1/chat/completions')) {
      return {
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': question},
        ],
        'temperature': 0.3,
      };
    }

    if (endpoint.contains('/v1/responses')) {
      return {
        'model': config.model,
        'input': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': question},
        ],
        'temperature': 0.3,
      };
    }

    return {
      'model': config.model,
      'message': question,
      'context': systemPrompt,
    };
  }

  String? _extractAnswer(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final direct = decoded['answer'] ?? decoded['text'] ?? decoded['reply'];
      if (direct is String) return direct;

      final outputText = decoded['output_text'];
      if (outputText is String) return outputText;

      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final message = first['message'];
          if (message is Map<String, dynamic> && message['content'] is String) {
            return message['content'] as String;
          }
          if (first['text'] is String) return first['text'] as String;
        }
      }

      final output = decoded['output'];
      if (output is List) {
        final parts = <String>[];
        for (final item in output) {
          if (item is Map<String, dynamic>) {
            final content = item['content'];
            if (content is List) {
              for (final contentItem in content) {
                if (contentItem is Map<String, dynamic> &&
                    contentItem['text'] is String) {
                  parts.add(contentItem['text'] as String);
                }
              }
            }
          }
        }
        if (parts.isNotEmpty) return parts.join('\n');
      }
    }
    return null;
  }

  String _generateOfflineAnswer(String question) {
    final normalized = question.toLowerCase();
    final intent = _detectIntent(normalized);
    final urgency = _detectUrgency(normalized);
    final place = _detectPlaceHint(normalized);

    final buffer = StringBuffer();
    buffer.writeln(_opening(intent, urgency, place));
    buffer.writeln();
    buffer.writeln('Do this now:');
    for (final step in _stepsFor(intent, urgent: urgency)) {
      buffer.writeln('- $step');
    }
    buffer.writeln();
    buffer.write(_closing(intent));
    return buffer.toString();
  }

  _AssistantIntent _detectIntent(String text) {
    if (_hasAny(text, const ['emergency', 'help', 'danger', 'accident'])) {
      return _AssistantIntent.emergency;
    }
    if (_hasAny(text, const ['elephant', 'aliya', 'wildlife'])) {
      return _AssistantIntent.elephant;
    }
    if (_hasAny(text, const ['landslide', 'slope', 'mud', 'crack', 'nbro'])) {
      return _AssistantIntent.landslide;
    }
    if (_hasAny(text, const ['flood', 'water', 'river', 'rain', 'drain'])) {
      return _AssistantIntent.flood;
    }
    if (_hasAny(text, const [
      'garbage',
      'waste',
      'bin',
      'plastic',
      'glass',
      'trash',
      'recycle',
    ])) {
      return _AssistantIntent.garbage;
    }
    return _AssistantIntent.general;
  }

  bool _detectUrgency(String text) {
    return _hasAny(text, const [
      'now',
      'near',
      'inside',
      'urgent',
      'high',
      'fast',
      'rising',
      'trapped',
      'full',
      'overflow',
    ]);
  }

  String? _detectPlaceHint(String text) {
    const places = {
      'kandy': 'Kandy',
      'colombo': 'Colombo',
      'galle': 'Galle',
      'matara': 'Matara',
      'badulla': 'Badulla',
      'ratnapura': 'Ratnapura',
      'anuradhapura': 'Anuradhapura',
      'kogalle': 'Kogalle',
      'kegalle': 'Kegalle',
    };
    for (final entry in places.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _opening(_AssistantIntent intent, bool urgent, String? place) {
    final placeText = place == null ? '' : ' near $place';
    final urgencyText = urgent ? ' Treat this as urgent.' : '';
    return switch (intent) {
      _AssistantIntent.flood => 'Flood safety guidance$placeText.$urgencyText',
      _AssistantIntent.landslide =>
        'Landslide safety guidance$placeText.$urgencyText',
      _AssistantIntent.elephant =>
        'Wild elephant safety guidance$placeText.$urgencyText',
      _AssistantIntent.garbage =>
        'Clean community guidance$placeText.$urgencyText',
      _AssistantIntent.emergency => 'Emergency guidance$placeText.$urgencyText',
      _AssistantIntent.general =>
        'I am running fully offline on this device. I can guide flood, landslide, elephant, and garbage safety.',
    };
  }

  List<String> _stepsFor(_AssistantIntent intent, {required bool urgent}) {
    return switch (intent) {
      _AssistantIntent.flood => [
          'Move people, documents, medicine, and chargers to higher ground.',
          'Do not walk or drive through moving floodwater.',
          'Switch off electricity only if the switchboard is dry and reachable.',
          'Use the Flood Alerts card to estimate rainfall and water-level risk.',
          if (urgent) 'Call local emergency services or your disaster officer.',
        ],
      _AssistantIntent.landslide => [
          'Leave steep ground if you see cracks, leaning trees, or muddy water.',
          'Avoid sleeping in rooms facing unstable slopes during heavy rain.',
          'Move uphill or sideways away from the slide path, not into valleys.',
          'Use the Landslide Risk card for rain, slope, and soil moisture checks.',
          if (urgent) 'Follow official NBRO or local evacuation instructions.',
        ],
      _AssistantIntent.elephant => [
          'Keep distance and move indoors or behind a strong barrier.',
          'Do not use flash, shout, chase, or feed the animal.',
          'Keep children and pets away from doors, roads, and open yards.',
          'Use the Elephant Watch camera module only from a safe place.',
          if (urgent) 'Contact local wildlife officers immediately.',
        ],
      _AssistantIntent.garbage => [
          'Check the smart-bin fill percentage before carrying waste.',
          'If the bin has free capacity, use the direction button to navigate.',
          'If the bin is almost full, avoid dumping beside it and report overflow.',
          'Use photo classification for plastic, glass, metal, paper, and mixed waste.',
          if (urgent) 'Keep away from chemical, sharp, or medical waste.',
        ],
      _AssistantIntent.emergency => [
          'Move away from immediate danger first.',
          'Call the appropriate local emergency number.',
          'Share your location, hazard type, number of people, and injuries.',
          'Use app modules only when you are already in a safe place.',
        ],
      _AssistantIntent.general => [
          'Tell me the hazard type: flood, landslide, elephant, or garbage.',
          'Mention your area if you want location-aware guidance.',
          'Use short facts such as "water rising fast" or "bin 90% full".',
        ],
    };
  }

  String _closing(_AssistantIntent intent) {
    return switch (intent) {
      _AssistantIntent.garbage =>
        'This answer is generated offline. For real sensor accuracy, connect the bin weight sensor feed to the app service.',
      _ =>
        'This answer is generated offline and is not a replacement for official emergency instructions.',
    };
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  void close() => _client.close();
}
