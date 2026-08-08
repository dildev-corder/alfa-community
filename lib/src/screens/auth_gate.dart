import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'landing_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = const AuthService();
  AppUser? _user;
  bool _loading = true;
  bool _showLanding = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final user = await _auth.currentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final user = _user;
    if (_showLanding) {
      return LandingScreen(
        onEnter: () => setState(() => _showLanding = false),
      );
    }
    if (user == null) {
      return LoginScreen(
        onSignedIn: (value) => setState(() => _user = value),
      );
    }
    return HomeScreen(user: user, onSignOut: _signOut);
  }
}
