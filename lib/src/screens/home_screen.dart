import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/app_user.dart';
import '../models/location_profile.dart';
import '../models/safety_module.dart';
import '../plugins/flood/flood_screen.dart';
import '../plugins/garbage/garbage_screen.dart';
import '../plugins/landslide/landslide_screen.dart';
import '../services/garbage_bin_sensor_service.dart';
import '../services/iot_sensor_service.dart';
import '../services/location_name_service.dart';
import '../services/location_service.dart';
import '../services/module_registry.dart';
import '../services/risk_engine.dart';
import 'admin_control_screen.dart';
import 'assistant_screen.dart';
import 'citizen_work_screen.dart';
import 'detection_screen.dart';
import 'emergency_contacts_screen.dart';
import 'officer_work_screen.dart';
import 'safety_map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _measuring = true;
  String? _locationError;
  StreamSubscription<Position>? _positionSubscription;
  LocationProfile _profile = const LocationProfile(
    label: 'Measuring current location',
    latitude: null,
    longitude: null,
    isLive: false,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_startAutomaticLocationMeasure());
  }

  LocationProfile _profileFromPosition(Position position) => LocationProfile(
        label: 'Live GPS location',
        latitude: position.latitude,
        longitude: position.longitude,
        isLive: true,
      );

  Future<void> _startAutomaticLocationMeasure() async {
    setState(() {
      _measuring = true;
      _locationError = null;
    });

    final stream =
        await LocationService().positionStream(distanceFilterMeters: 250);
    final firstPosition = await LocationService().currentPosition();
    if (!mounted) return;

    if (stream == null || firstPosition == null) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      setState(() {
        _measuring = false;
        _profile = const LocationProfile(
          label: 'GPS unavailable',
          latitude: null,
          longitude: null,
          isLive: false,
        );
        _locationError =
            'Enable GPS and location permission to measure modules.';
      });
      return;
    }

    await _positionSubscription?.cancel();
    _positionSubscription = stream.listen((position) {
      if (!mounted) return;
      setState(() {
        _measuring = false;
        _locationError = null;
        _profile = _profileFromPosition(position);
      });
    });

    setState(() {
      _measuring = false;
      _locationError = null;
      _profile = _profileFromPosition(firstPosition);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final privilegedRole = widget.user.canSeeEveryCard;
    final modules =
        const ModuleRegistry().modulesFor(_profile, demoAll: privilegedRole);
    final visibleModules = privilegedRole
        ? modules
        : modules.where((module) => module.enabled).toList();
    final pages = [
      _Dashboard(
        modules: visibleModules,
        profile: _profile,
        measuring: _measuring,
        user: widget.user,
        locationError: _locationError,
        onRefreshLocation: _startAutomaticLocationMeasure,
        onSignOut: widget.onSignOut,
      ),
      SafetyMapScreen(profile: _profile),
      _workScreen(),
      EmergencyContactsScreen(profile: _profile),
      const AssistantScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(_workIcon()),
            label: _workLabel(),
          ),
          const NavigationDestination(
            icon: Icon(Icons.call_rounded),
            label: 'Contacts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome_rounded),
            label: 'Assistant',
          ),
        ],
      ),
    );
  }

  Widget _workScreen() => switch (widget.user.role) {
        UserRole.admin => AdminControlScreen(user: widget.user),
        UserRole.officer => OfficerWorkScreen(user: widget.user),
        UserRole.citizen => CitizenWorkScreen(
            user: widget.user,
            profile: _profile,
          ),
      };

  String _workLabel() => switch (widget.user.role) {
        UserRole.admin => 'Control',
        UserRole.officer => 'Officer',
        UserRole.citizen => 'Report',
      };

  IconData _workIcon() => switch (widget.user.role) {
        UserRole.admin => Icons.admin_panel_settings_rounded,
        UserRole.officer => Icons.assignment_turned_in_rounded,
        UserRole.citizen => Icons.report_problem_rounded,
      };
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.modules,
    required this.profile,
    required this.measuring,
    required this.user,
    required this.locationError,
    required this.onRefreshLocation,
    required this.onSignOut,
  });

  final List<SafetyModule> modules;
  final LocationProfile profile;
  final bool measuring;
  final AppUser user;
  final String? locationError;
  final VoidCallback onRefreshLocation;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8F3E9), Color(0xFFEAF3EA), Color(0xFFF8F3E9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(
            children: [
              _RoundActionButton(
                icon: Icons.menu_rounded,
                onPressed: () {},
              ),
              const Expanded(
                child: Text(
                  'Alpha Community',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101D18),
                  ),
                ),
              ),
              _RoundActionButton(
                icon: Icons.logout_rounded,
                onPressed: onSignOut,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HeroStatusPanel(
            user: user,
            profile: profile,
            measuring: measuring,
            locationError: locationError,
            onRefreshLocation: onRefreshLocation,
          ),
          const SizedBox(height: 22),
          const Text(
            'Monitoring Services',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101D18),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Live village safety modules for field response.',
            style: TextStyle(color: Color(0xFF6D756F)),
          ),
          const SizedBox(height: 14),
          if (modules.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Waiting for GPS measurement. Cards will appear automatically.',
                ),
              ),
            )
          else
            for (final module in modules)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ModuleCard(module: module),
              ),
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _HeroStatusPanel extends StatelessWidget {
  const _HeroStatusPanel({
    required this.user,
    required this.profile,
    required this.measuring,
    required this.locationError,
    required this.onRefreshLocation,
  });

  final AppUser user;
  final LocationProfile profile;
  final bool measuring;
  final String? locationError;
  final VoidCallback onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    final healthy = locationError == null;
    final locationName = const LocationNameService().nameForProfile(profile);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF123C2B), Color(0xFF1D6B49), Color(0xFF8AAA5B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33123C2B),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -18,
            top: -24,
            child: _GlowCircle(size: 110, opacity: 0.12),
          ),
          const Positioned(
            right: 34,
            bottom: -36,
            child: _GlowCircle(size: 80, opacity: 0.1),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.holiday_village_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${user.role.label} access',
                          style: const TextStyle(color: Color(0xFFDDEFE4)),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: measuring ? null : onRefreshLocation,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                measuring ? 'Measuring live location' : locationName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                locationError ??
                    (profile.isLive
                        ? 'Live GPS active for this area'
                        : profile.displayLabel),
                style: const TextStyle(color: Color(0xFFE7F2DA)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusPill(
                    icon: healthy
                        ? Icons.sensors_rounded
                        : Icons.location_off_rounded,
                    label: healthy ? 'Live sensing' : 'Location needed',
                  ),
                  const _StatusPill(
                    icon: Icons.cloud_sync_rounded,
                    label: 'Cloud ready',
                  ),
                  const _StatusPill(
                    icon: Icons.security_rounded,
                    label: 'Protected access',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  const _ModuleCard({required this.module});

  final SafetyModule module;

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  late Future<_ModuleInsight> _insightFuture;

  @override
  void initState() {
    super.initState();
    _insightFuture = _loadInsight();
  }

  Widget _screen() => switch (widget.module.id) {
        ModuleId.elephant => const DetectionScreen(),
        ModuleId.flood => const FloodScreen(),
        ModuleId.landslide => const LandslideScreen(),
        ModuleId.garbage => const GarbageScreen(),
      };

  Future<_ModuleInsight> _loadInsight() async {
    switch (widget.module.id) {
      case ModuleId.elephant:
        final reading = await const IotSensorService().latestElephantBeam();
        if (reading == null) {
          return const _ModuleInsight(
            level: 0.18,
            value: 'Standby',
            label: 'Beam sensor',
            source: 'Perimeter network waiting',
            status: 'IoT sensor not synced',
            riskColor: Color(0xFFE7F2DA),
          );
        }
        return _ModuleInsight(
          level: reading.isHighRisk ? 1 : 0.16,
          value: reading.isHighRisk ? 'High' : 'Safe',
          label: reading.beamBroken ? 'Beam broken' : 'Beam normal',
          source: reading.deviceId,
          status: reading.isHighRisk
              ? 'Siren and alert level active'
              : 'Perimeter beam clear',
          riskColor: reading.isHighRisk
              ? const Color(0xFFFFD2C7)
              : const Color(0xFFCFF7DE),
        );
      case ModuleId.flood:
        final reading = await const IotSensorService().latestEnvironment();
        if (reading == null) {
          return const _ModuleInsight(
            level: 0.25,
            value: '--',
            label: 'Water level',
            source: 'Live network waiting',
            status: 'Open module for latest field assessment',
            riskColor: Color(0xFFE7F2DA),
          );
        }
        final assessment = const RiskEngine().flood(
          rainfall24h: reading.rainfallEstimateMm,
          waterLevel: reading.waterLevelMeters,
          drainage: reading.drainagePercent,
        );
        return _ModuleInsight(
          level: assessment.score,
          value: '${reading.waterLevelMeters.toStringAsFixed(1)} m',
          label: '${_riskLevelLabel(assessment.level)} flood level',
          source: reading.deviceId,
          status:
              'Rain ${reading.rainfallEstimateMm.toStringAsFixed(0)} mm | Drainage ${reading.drainagePercent.toStringAsFixed(0)}%',
          riskColor: _riskColor(assessment.level),
        );
      case ModuleId.landslide:
        final reading = await const IotSensorService().latestEnvironment();
        if (reading == null) {
          return const _ModuleInsight(
            level: 0.25,
            value: '--',
            label: 'Slope watch',
            source: 'Live network waiting',
            status: 'Open module for latest field assessment',
            riskColor: Color(0xFFE7F2DA),
          );
        }
        final assessment = const RiskEngine().landslide(
          rainfall72h: (reading.rainfallEstimateMm * 1.8).clamp(0, 500),
          slope: reading.slopeDegrees,
          soilMoisture: reading.soilMoisturePercent,
        );
        return _ModuleInsight(
          level: assessment.score,
          value: '${reading.soilMoisturePercent.toStringAsFixed(0)}%',
          label: '${_riskLevelLabel(assessment.level)} landslide level',
          source: reading.deviceId,
          status:
              'Tilt ${reading.slopeDegrees.toStringAsFixed(0)}° | Vibration ${reading.vibrationDigital ? 'active' : 'normal'}',
          riskColor: _riskColor(assessment.level),
        );
      case ModuleId.garbage:
        final reading = await const GarbageBinSensorService().nearestBin(
          null,
          simulateFallbackDelay: false,
        );
        return _ModuleInsight(
          level: reading.fillPercent / 100,
          value: '${reading.fillPercent}%',
          label: reading.isAlmostFull
              ? 'Bin full level'
              : reading.hasGoodSpace
                  ? 'Good free space'
                  : 'Medium fill level',
          source: reading.binId,
          status:
              '${reading.currentWeightKg.toStringAsFixed(1)} kg used | ${reading.freePercent}% free',
          riskColor: reading.isAlmostFull
              ? const Color(0xFFFFD2C7)
              : reading.hasGoodSpace
                  ? const Color(0xFFCFF7DE)
                  : const Color(0xFFFFE7B8),
        );
    }
  }

  void _refreshInsight() {
    setState(() => _insightFuture = _loadInsight());
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _foregroundColor(widget.module.id);
    final gradient = _cardGradient(widget.module.id);
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => _screen())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.32),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -20,
              top: -28,
              child: _GlowCircle(size: 96, opacity: 0.13),
            ),
            Positioned(
              right: 34,
              bottom: -28,
              child: _GlowCircle(size: 62, opacity: 0.08),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.17),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(
                        child: _CardIncidentIcon(
                          moduleId: widget.module.id,
                          color: foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _monitoringTitle(widget.module.id),
                            style: TextStyle(
                              color: foreground,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _monitoringSubtitle(widget.module.id),
                            style: TextStyle(
                              color: foreground.withValues(alpha: 0.88),
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _refreshInsight,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh IoT level',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<_ModuleInsight>(
                  future: _insightFuture,
                  builder: (context, snapshot) {
                    final insight = snapshot.data ??
                        _ModuleInsight.loading(widget.module.id);
                    final loading =
                        snapshot.connectionState == ConnectionState.waiting;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _MiniStatus(label: insight.source),
                            const SizedBox(width: 8),
                            if (loading)
                              const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              _MiniStatus(label: insight.label),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _LevelMeter(
                          value: insight.level,
                          color: insight.riskColor,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              insight.value,
                              style: TextStyle(
                                color: foreground,
                                fontSize: 31,
                                height: 0.95,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                insight.status,
                                style: TextStyle(
                                  color: foreground.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: foreground,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _cardGradient(ModuleId id) => switch (id) {
        ModuleId.elephant => const [Color(0xFF004D2B), Color(0xFF008956)],
        ModuleId.garbage => const [Color(0xFFE78A00), Color(0xFFFFBD2E)],
        ModuleId.flood => const [Color(0xFF006EBC), Color(0xFF00A7D8)],
        ModuleId.landslide => const [Color(0xFF6F421F), Color(0xFFB47A42)],
      };

  Color _foregroundColor(ModuleId id) {
    return Colors.white;
  }

  String _monitoringTitle(ModuleId id) => switch (id) {
        ModuleId.elephant => 'Elephant Monitoring',
        ModuleId.garbage => 'Garbage Monitoring',
        ModuleId.flood => 'Flood Monitoring',
        ModuleId.landslide => 'Landslide Monitoring',
      };

  String _monitoringSubtitle(ModuleId id) => switch (id) {
        ModuleId.elephant => 'Detects elephants and sends real-time alerts',
        ModuleId.garbage => 'Check dustbin status and availability',
        ModuleId.flood => 'Monitor water levels and rainfall',
        ModuleId.landslide => 'Track slope, rain, and ground risk',
      };

  String _riskLevelLabel(RiskLevel level) => switch (level) {
        RiskLevel.low => 'Low',
        RiskLevel.medium => 'Medium',
        RiskLevel.high => 'High',
      };

  Color _riskColor(RiskLevel level) => switch (level) {
        RiskLevel.low => const Color(0xFFCFF7DE),
        RiskLevel.medium => const Color(0xFFFFE7B8),
        RiskLevel.high => const Color(0xFFFFD2C7),
      };
}

class _ModuleInsight {
  const _ModuleInsight({
    required this.level,
    required this.value,
    required this.label,
    required this.source,
    required this.status,
    required this.riskColor,
  });

  final double level;
  final String value;
  final String label;
  final String source;
  final String status;
  final Color riskColor;

  factory _ModuleInsight.loading(ModuleId id) => _ModuleInsight(
        level: 0.08,
        value: '--',
        label: 'Loading',
        source: switch (id) {
          ModuleId.elephant => 'Perimeter beam',
          ModuleId.flood => 'Flood network',
          ModuleId.landslide => 'Slope network',
          ModuleId.garbage => 'Bin sensor',
        },
        status: 'Reading IoT sensor level...',
        riskColor: const Color(0xFFE7F2DA),
      );
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 16,
            value: clamped,
            color: color,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _MeterDot(active: clamped >= 0.15, color: color),
            const SizedBox(width: 6),
            _MeterDot(active: clamped >= 0.4, color: color),
            const SizedBox(width: 6),
            _MeterDot(active: clamped >= 0.7, color: color),
            const SizedBox(width: 8),
            Text(
              '${(clamped * 100).round()}% level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MeterDot extends StatelessWidget {
  const _MeterDot({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: active ? color : Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CardIncidentIcon extends StatelessWidget {
  const _CardIncidentIcon({required this.moduleId, required this.color});

  final ModuleId moduleId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (moduleId == ModuleId.elephant) {
      return Image.asset(
        'assets/icons/safari.png',
        width: 52,
        height: 52,
        color: color,
        colorBlendMode: BlendMode.srcIn,
      );
    }
    return Icon(_largeIcon(moduleId), color: color, size: 48);
  }

  IconData _largeIcon(ModuleId id) => switch (id) {
        ModuleId.elephant => Icons.forest_rounded,
        ModuleId.garbage => Icons.delete_rounded,
        ModuleId.flood => Icons.waves_rounded,
        ModuleId.landslide => Icons.terrain_rounded,
      };
}
