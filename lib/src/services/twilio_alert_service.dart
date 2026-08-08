import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/community_report.dart';

class TwilioAlertService {
  const TwilioAlertService();

  static const _endpoint = String.fromEnvironment('TWILIO_ALERT_ENDPOINT');

  bool get isConfigured => _endpoint.trim().isNotEmpty;

  Future<void> sendReportAlert(CommunityReport report) async {
    if (!isConfigured) return;
    try {
      await http
          .post(
            Uri.parse(_endpoint),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'reportId': report.id,
              'type': report.type.label,
              'typeName': report.type.name,
              'area': report.district,
              'message': report.message,
              'contactNumber': report.contactNumber,
              'latitude': report.latitude,
              'longitude': report.longitude,
              'createdAt': report.createdAt.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Reporting must not fail only because SMS delivery is unavailable.
    }
  }
}
