import 'package:flutter/material.dart';

import '../models/safety_alert.dart';
import '../services/alert_store.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  late Future<List<SafetyAlert>> _alerts;

  @override
  void initState() {
    super.initState();
    _alerts = AlertStore().load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _alerts = AlertStore().load()),
      child: FutureBuilder<List<SafetyAlert>>(
        future: _alerts,
        builder: (context, snapshot) {
          final alerts = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            children: [
              const Text(
                'Alert history',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('Recent community safety activity'),
              const SizedBox(height: 22),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (alerts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child:
                        Text('No alerts yet. Run an elephant detection test.'),
                  ),
                )
              else
                ...alerts.map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFFFD9D4),
                              child: Icon(Icons.warning_amber_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${alert.type} alert',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(alert.message),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(alert.confidence * 100).toStringAsFixed(1)}% confidence'
                                    '${alert.latitude == null ? ' | Location unavailable' : ' | GPS saved'}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
