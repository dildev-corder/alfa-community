import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key, required this.onEnter});

  final VoidCallback onEnter;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/alfa_landing.mp4')
      ..setLooping(true)
      ..setVolume(0);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
    }).catchError((_) {
      if (mounted) setState(() => _ready = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10291F),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10291F), Color(0xFF315C38), Color(0xFF10291F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.public_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'ALPHA COMMUNITY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _VideoHeroPanel(
                  ready: _ready,
                  controller: _controller,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEECF6D),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'WORLD CITIZEN APP',
                    style: TextStyle(
                      color: Color(0xFF10291F),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Smart intelligence for every community.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Safety map, public issue reporting, emergency contacts, location alerts, smart-bin information, and AI guidance in one community app.',
                  style: TextStyle(
                    color: Color(0xFFE6F0E8),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _CapabilityChip(label: 'AI safety assistant'),
                    _CapabilityChip(label: 'Safety map'),
                    _CapabilityChip(label: 'Public reporting'),
                    _CapabilityChip(label: 'Emergency contacts'),
                    _CapabilityChip(label: 'Community alerts'),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEECF6D),
                      foregroundColor: const Color(0xFF10291F),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: widget.onEnter,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Enter Alpha Community',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoHeroPanel extends StatelessWidget {
  const _VideoHeroPanel({required this.ready, required this.controller});

  final bool ready;
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ready
            ? VideoPlayer(controller)
            : const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6D7C75), Color(0xFF202C28)],
                  ),
                ),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
