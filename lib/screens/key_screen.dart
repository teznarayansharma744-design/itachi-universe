import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../device_id.dart';
import '../glass.dart';
import '../theme.dart';
import 'home_screen.dart';

class KeyScreen extends StatefulWidget {
  const KeyScreen({super.key});

  @override
  State<KeyScreen> createState() => _KeyScreenState();
}

class _KeyScreenState extends State<KeyScreen> {
  final _keyController = TextEditingController();
  late final Future<String> _deviceId = DeviceId.get();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _activate() {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      _toast('Please enter your premium key.');
      return;
    }
    // DEV ONLY: any non-empty key opens Home so you can test the screens.
    // TODO(next step): send key + device ID to the server and unlock only on success.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
              Row(
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(10),
                    radius: 14,
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 12),
                  const Text('Premium Key',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Enter your key',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Your key is generated for this device only. Copy the Device ID below and send it to our Telegram bot.',
                style: TextStyle(fontSize: 15, height: 1.5, color: p.textDim),
              ),
              const SizedBox(height: 24),
              GlassCard(
                padding: const EdgeInsets.all(20),
                radius: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premium Key',
                        style: TextStyle(fontSize: 13, color: p.textDim)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _keyController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 16, letterSpacing: 1),
                      decoration: InputDecoration(
                        hintText: 'XXXX-XXXX-XXXX-XXXX',
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
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Your Device ID',
                        style: TextStyle(fontSize: 13, color: p.textDim)),
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: _deviceId,
                      builder: (context, snap) {
                        final id = snap.data ?? '...';
                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: p.glassFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.glassBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(id,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w500)),
                              ),
                              TextButton.icon(
                                onPressed: snap.hasData
                                    ? () async {
                                        await Clipboard.setData(ClipboardData(text: id));
                                        if (mounted) _toast('Device ID copied.');
                                      }
                                    : null,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Copy'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF5B5BFF), Color(0xFF19C3B1)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextButton(
                    onPressed: _activate,
                    child: const Text('Activate Premium',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.all(16),
                radius: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 20, color: p.textDim),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'One key works on one device only. If you switch phones, you will need a new key for the new Device ID.',
                        style: TextStyle(fontSize: 13, height: 1.5, color: p.textDim),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
