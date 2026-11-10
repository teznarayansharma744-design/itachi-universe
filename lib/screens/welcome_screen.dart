import 'package:flutter/material.dart';

import '../access.dart';
import '../glass.dart';
import '../theme.dart';
import 'key_screen.dart';
import '../secret_tap.dart';
import 'admin/admin_login_screen.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _soon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what is coming in the next step.')));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: GlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Switch theme',
                  onPressed: () => themeMode.value =
                      isDark ? ThemeMode.light : ThemeMode.dark,
                  icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                ),
              ),
              const SizedBox(height: 28),
              // Tap the logo 7 times quickly to open the hidden admin login.
              Align(
                alignment: Alignment.centerLeft,
                child: SecretTap(
                  onUnlocked: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                  ),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    radius: 20,
                    child: const Icon(Icons.play_arrow_rounded, size: 28),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Itachi Universe',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Learn at your own pace. Subject-wise videos and PDFs, all in one place.',
                style: TextStyle(fontSize: 16, height: 1.5, color: p.textDim),
              ),
              const SizedBox(height: 36),
              _OptionCard(
                icon: Icons.ondemand_video_rounded,
                title: 'Demo Mode',
                subtitle: 'Browse everything. Only free lectures play.',
                badge: 'DEMO',
                onTap: () {
                  accessMode.value = AccessMode.demo;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _OptionCard(
                icon: Icons.vpn_key_rounded,
                title: 'Enter Premium Key',
                subtitle: 'Enter your key to unlock the full course',
                highlight: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KeyScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _OptionCard(
                icon: Icons.workspace_premium_rounded,
                title: 'Get Premium',
                subtitle: 'Contact us on Telegram to get a key',
                onTap: () => _soon(context, 'The Telegram link'),
              ),
              const Spacer(),
              Center(
                child: Text(
                  'One key, one device. Your key works only on your phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? badge;
  final bool highlight;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final onGradient = highlight;
    final fg = onGradient ? Colors.white : p.text;
    final fgDim = onGradient ? const Color(0xE6FFFFFF) : p.textDim;

    return GlassCard(
      onTap: onTap,
      gradient: highlight
          ? const LinearGradient(
              colors: [Color(0xFF4B4BF0), Color(0xFF2E9BE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: fg.withAlpha(36),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: fg),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600, color: fg)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: fgDim)),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x3819C3B1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0B9E8F))),
            )
          else
            Icon(Icons.chevron_right_rounded, color: fgDim),
        ],
      ),
    );
  }
}
