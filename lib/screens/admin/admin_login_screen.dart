import 'package:flutter/material.dart';

import '../../api.dart';
import '../../glass.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'admin_panel_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _url = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _url.text = await Api.baseUrl();
    // Already logged in earlier? Go straight to the panel.
    if (await Api.hasAdminSession() && mounted) _openPanel();
  }

  void _openPanel() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
      );

  Future<void> _login() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter the admin password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.setBaseUrl(_url.text);
      await Api.adminLogin(_password.text);
      if (mounted) _openPanel();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _decoration(AppPalette p, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: p.glassFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.glassBorder),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: GlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(caption: 'Itachi Universe', title: 'Admin'),
              const SizedBox(height: 28),
              const Text('Admin login',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Only for the owner. Generate and manage student keys here.',
                  style: TextStyle(fontSize: 14, height: 1.5, color: p.textDim)),
              const SizedBox(height: 24),
              GlassCard(
                radius: 28,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Server address',
                        style: TextStyle(fontSize: 13, color: p.textDim)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: _decoration(p, 'https://your-app.onrender.com'),
                    ),
                    const SizedBox(height: 18),
                    Text('Password', style: TextStyle(fontSize: 13, color: p.textDim)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      obscureText: _hide,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _login(),
                      decoration: _decoration(p, 'Admin password').copyWith(
                        suffixIcon: IconButton(
                          tooltip: _hide ? 'Show password' : 'Hide password',
                          icon: Icon(_hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!,
                          style: const TextStyle(color: Color(0xFFFF6A6A), fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Log in',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The first login can take up to a minute if the server was asleep.',
                style: TextStyle(fontSize: 12, color: p.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
