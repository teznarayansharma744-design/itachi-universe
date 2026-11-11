import 'package:flutter/material.dart';

import '../access.dart';
import '../api.dart';
import '../glass.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

/// First screen. If this phone already has a premium key it goes straight to Home,
/// otherwise to the Welcome screen.
class Launcher extends StatefulWidget {
  const Launcher({super.key});

  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    Widget next = const WelcomeScreen();
    if (Api.isConfigured && Api.hasPremiumToken) {
      // false = the server says the key is revoked or expired.
      // null = could not tell (slow server or no internet): trust the saved key.
      final ok = await Api.checkPremium()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (ok != false) {
        accessMode.value = AccessMode.premium;
        next = const HomeScreen();
      }
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GlassBackground(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
