import 'package:flutter/material.dart';

import '../access.dart';
import '../api.dart';
import '../catalog.dart';
import '../data.dart';
import '../device_id.dart';
import '../glass.dart';
import '../theme.dart';
import '../widgets.dart';
import 'key_screen.dart';
import 'player_screen.dart';
import 'subjects_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Catalog.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GlassBackground(
        child: IndexedStack(
          index: _tab,
          // Pull down on Home or Library to fetch new lectures from the server.
          children: const [
            _Refreshable(_HomeTab()),
            _Refreshable(_LibraryTab()),
            _SettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: GlassCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(Icons.home_rounded, 'Home', _tab == 0, () => setState(() => _tab = 0)),
                _NavItem(Icons.grid_view_rounded, 'Library', _tab == 1, () => setState(() => _tab = 1)),
                _NavItem(Icons.settings_rounded, 'Settings', _tab == 2, () => setState(() => _tab = 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem(this.icon, this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.text.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: selected ? p.text : p.textDim),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? p.text : p.textDim)),
          ],
        ),
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  final Batch batch;
  const _BatchTile(this.batch);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SubjectsScreen(batch: batch)),
        ),
        child: Row(
          children: [
            IconTile(icon: batch.icon, tint: batch.tint),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(batch.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${batch.subjects.length} subjects / ${batch.lectures} lectures',
                      style: TextStyle(fontSize: 12, color: p.textDim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textDim),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back', style: TextStyle(fontSize: 13, color: p.textDim)),
                const Text('Itachi Universe',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0x8C5B5BFF), Color(0x6619C3B1)]),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.glassBorder),
              ),
              child: Text(isDemo ? 'DEMO' : 'PREMIUM',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: TextField(
            decoration: InputDecoration(
              border: InputBorder.none,
              icon: Icon(Icons.search_rounded, color: p.textDim),
              hintText: 'Search subjects, units, PDFs',
              hintStyle: TextStyle(color: p.textDim),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!isDemo && Catalog.instance.usingSample) ...[
        const Text('Continue watching',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.all(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PlayerScreen(
                title: "Newton's Laws of Motion: Lecture 3",
                subtitle: 'Physics / Laws of Motion',
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B2350), Color(0xFF2A1740)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                    child: Icon(Icons.play_circle_fill_rounded, size: 52, color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text("Newton's Laws of Motion: Lecture 3",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Physics / Laws of Motion',
                    style: TextStyle(fontSize: 12, color: p.textDim)),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 0.34,
                    minHeight: 4,
                    backgroundColor: p.text.withAlpha(40),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF19C3B1)),
                  ),
                ),
              ),
            ],
          ),
        ),
        ],
        if (isDemo) ...[
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.all(16),
            gradient: const LinearGradient(
              colors: [Color(0x595B5BFF), Color(0x2E19C3B1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KeyScreen()),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_open_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You are in Demo Mode',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Only free lectures are unlocked. Tap to enter your premium key.',
                          style: TextStyle(fontSize: 12, height: 1.4, color: p.textDim)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text('Your batches',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const _BatchList(),
      ],
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        const Text('Library',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        const _BatchList(),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'This removes premium from this phone. Your key stays valid, so you can enter it again on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true) return;
    await Api.clearPremium();
    accessMode.value = AccessMode.demo;
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        const Text('Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        GlassCard(
          radius: 22,
          child: Row(
            children: [
              const Icon(Icons.dark_mode_outlined),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Dark mode',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Switch(
                value: isDark,
                onChanged: (v) => themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          radius: 22,
          child: Row(
            children: [
              const Icon(Icons.phone_android_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Device ID',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    FutureBuilder<String>(
                      future: DeviceId.get(),
                      builder: (_, snap) => Text(snap.data ?? '...',
                          style: TextStyle(
                              fontSize: 13, fontFamily: 'monospace', color: p.textDim)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<AccessMode>(
          valueListenable: accessMode,
          builder: (context, mode, _) => mode == AccessMode.demo
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    radius: 22,
                    onTap: () => _logout(context),
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text('Log out from this device',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        GlassCard(
          radius: 22,
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Your premium key is locked to this device.',
                    style: TextStyle(fontSize: 14, color: p.textDim)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Itachi Universe  v${const String.fromEnvironment('APP_VERSION', defaultValue: 'dev')}',
            style: TextStyle(fontSize: 12, color: p.textDim),
          ),
        ),
      ],
    );
  }
}

/// Pull-to-refresh wrapper for a tab that contains a ListView.
class _Refreshable extends StatelessWidget {
  final Widget child;
  const _Refreshable(this.child);

  @override
  Widget build(BuildContext context) =>
      RefreshIndicator(onRefresh: Catalog.instance.load, child: child);
}

/// The batch list: spinner while loading, a retry card on error, otherwise the tiles.
class _BatchList extends StatelessWidget {
  const _BatchList();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ListenableBuilder(
      listenable: Catalog.instance,
      builder: (context, _) {
        final c = Catalog.instance;
        if (c.loading && c.batches.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (c.error != null && c.batches.isEmpty) {
          return GlassCard(
            radius: 22,
            child: Column(
              children: [
                Text(c.error!,
                    textAlign: TextAlign.center, style: TextStyle(color: p.textDim)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: c.load, child: const Text('Try again')),
              ],
            ),
          );
        }
        if (c.batches.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('No batches yet. Pull down to refresh.',
                  style: TextStyle(color: p.textDim)),
            ),
          );
        }
        return Column(children: [for (final b in c.batches) _BatchTile(b)]);
      },
    );
  }
}
