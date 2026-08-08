import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

enum _AccessMode { citizen, staff }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final ValueChanged<AppUser> onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = const AuthService();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  _AccessMode _mode = _AccessMode.citizen;
  bool _registering = false;
  bool _busy = false;
  bool _obscurePassword = true;

  bool get _isCitizen => _mode == _AccessMode.citizen;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_registering &&
        _passwordController.text != _confirmPasswordController.text) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _busy = true);

    final result = _registering
        ? await _auth.register(
            role: UserRole.citizen,
            displayName: _nameController.text,
            identifier: _idController.text,
            password: _passwordController.text,
            phoneNumber: _phoneController.text,
          )
        : _isCitizen
            ? await _auth.login(
                role: UserRole.citizen,
                identifier: _idController.text,
                password: _passwordController.text,
              )
            : await _auth.staffLogin(
                identifier: _idController.text,
                password: _passwordController.text,
              );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.user != null) {
      widget.onSignedIn(result.user!);
      return;
    }

    _showMessage(result.error ?? 'Login failed.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setMode(_AccessMode mode) {
    setState(() {
      _mode = mode;
      _registering = false;
      _nameController.clear();
      _idController.clear();
      _phoneController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final idLabel = _isCitizen ? 'NIC number' : 'Staff ID';
    final title = _registering
        ? 'Create Citizen Account'
        : _isCitizen
            ? 'Citizen Login'
            : 'Staff Login';
    final subtitle = _registering
        ? 'Register once with your NIC and secure password.'
        : _isCitizen
            ? 'Enter with your NIC to access community services.'
            : 'Admin and officers use their authorized staff ID.';

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F3E9), Color(0xFFEAF3EA), Color(0xFFF8F3E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const _LoginHero(),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _AccessCard(
                      selected: _mode == _AccessMode.citizen,
                      icon: Icons.person_rounded,
                      title: 'Citizen',
                      subtitle: 'NIC access',
                      onTap: () => _setMode(_AccessMode.citizen),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AccessCard(
                      selected: _mode == _AccessMode.staff,
                      icon: Icons.verified_user_rounded,
                      title: 'Staff',
                      subtitle: 'Admin and officers',
                      onTap: () => _setMode(_AccessMode.staff),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 26,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF194D36), Color(0xFF8AAA5B)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            _registering
                                ? Icons.person_add_alt_1_rounded
                                : _isCitizen
                                    ? Icons.badge_rounded
                                    : Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF101D18),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style:
                                    const TextStyle(color: Color(0xFF667168)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_registering) ...[
                      TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          label: 'Full name',
                          icon: Icons.account_circle_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          label: 'Mobile number for alerts',
                          icon: Icons.sms_rounded,
                          helper: 'Use country code, example +94771234567.',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _idController,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration(
                        label: idLabel,
                        icon: _isCitizen
                            ? Icons.credit_card_rounded
                            : Icons.security_rounded,
                        helper: _isCitizen
                            ? 'Use your national identity card number.'
                            : 'Admin uses ADMIN. Officers use employee ID.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: _registering
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_registering) _submit();
                      },
                      decoration: _fieldDecoration(
                        label: 'Password',
                        icon: Icons.lock_rounded,
                        helper: _registering
                            ? 'Create a password with at least 6 characters.'
                            : 'Secure access only.',
                        suffix: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    if (_registering) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: _fieldDecoration(
                          label: 'Confirm password',
                          icon: Icons.lock_reset_rounded,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _registering
                                    ? Icons.how_to_reg_rounded
                                    : Icons.login_rounded,
                              ),
                        label: Text(
                          _registering
                              ? 'Create citizen account'
                              : 'Authenticate and enter',
                        ),
                      ),
                    ),
                    if (_isCitizen) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () => setState(
                            () => _registering = !_registering,
                          ),
                          child: Text(
                            _registering
                                ? 'Already registered? Login'
                                : 'New citizen? Register',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? helper,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7FAF4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE4EBDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF1D6B49), width: 1.4),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF123C2B), Color(0xFF1D6B49), Color(0xFF8AAA5B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33123C2B),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -28,
            child: _SoftCircle(size: 120, opacity: 0.12),
          ),
          Positioned(
            right: 36,
            bottom: -34,
            child: _SoftCircle(size: 72, opacity: 0.1),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.public_rounded,
                      color: Color(0xFF194D36),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'ALPHA COMMUNITY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 22),
              Text(
                'Secure access for every community.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Citizens register safely. Officers are created by admin and manage field response.',
                style: TextStyle(color: Color(0xFFE7F2DA), height: 1.35),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF123C2B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF123C2B) : const Color(0xFFE4EBDD),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  selected ? const Color(0x33123C2B) : const Color(0x10000000),
              blurRadius: selected ? 20 : 12,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF194D36),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF101D18),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFDDEFE4)
                    : const Color(0xFF667168),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.opacity});

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
