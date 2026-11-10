import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api.dart';
import '../../glass.dart';
import '../../theme.dart';
import 'admin_login_screen.dart';

const _teal = Color(0xFF19C3B1);
const _amber = Color(0xFFFFB84D);
const _pink = Color(0xFFFF6AA2);

Color _statusColor(String s) =>
    s == 'active' ? _teal : (s == 'expired' ? _amber : _pink);

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<AdminKey> _keys = [];
  AdminStats? _stats;
  bool _loading = true;
  String? _error;
  String _query = '';
  String _filter = 'all'; // all | active | expired | revoked
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Runs a server call. On an expired session, goes back to the login screen.
  Future<T?> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (e) {
      if (!mounted) return null;
      if (e.unauthorized) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        );
      } else {
        _toast(e.message);
      }
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await Api.adminStats();
      final keys = await Api.adminKeys(q: _query);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _keys = keys;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.unauthorized) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        );
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminKey> get _shown =>
      _filter == 'all' ? _keys : _keys.where((k) => k.status == _filter).toList();

  Future<void> _logout() async {
    await Api.adminLogout();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<AdminKey>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateKeySheet(),
    );
    if (created != null && mounted) {
      await _load();
      if (mounted) await _showCreated(created);
    }
  }

  Future<void> _showCreated(AdminKey k) {
    final p = AppPalette.of(context);
    final message = 'Your Itachi Universe premium key:\n${k.key}\n\n'
        'Valid until ${_date(k.expiresAt)}.\n'
        'Open the app, tap "Enter Premium Key" and paste it. '
        'It works only on your device.';
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: GlassCard(
          radius: 28,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 36, color: _teal),
              const SizedBox(height: 12),
              const Text('Key created',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              SelectableText(k.key,
                  style: const TextStyle(
                      fontSize: 20, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Valid until ${_date(k.expiresAt)}',
                  style: TextStyle(fontSize: 13, color: p.textDim)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: k.key));
                        _toast('Key copied.');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy key'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message));
                        _toast('Message copied. Paste it in Telegram or WhatsApp.');
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Copy message'),
                    ),
                  ),
                ],
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _action(AdminKey k, String what) async {
    switch (what) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: k.key));
        _toast('Key copied.');
        return;
      case 'extend':
        await _guard(() => Api.extendKey(k.key, 30));
        _toast('Extended by 30 days.');
      case 'revoke':
        if (!await _confirm('Revoke key?',
            'The student loses premium right away. You can restore it later.', 'Revoke')) {
          return;
        }
        await _guard(() => Api.revokeKey(k.key));
        _toast('Key revoked.');
      case 'restore':
        await _guard(() => Api.restoreKey(k.key));
        _toast('Key restored.');
      case 'delete':
        if (!await _confirm('Delete key?', 'This removes the key for good.', 'Delete')) {
          return;
        }
        await _guard(() => Api.deleteKey(k.key));
        _toast('Key deleted.');
    }
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = _stats;
    return Scaffold(
      body: GlassBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(10),
                    radius: 14,
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Admin panel',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Log out',
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  _Stat('Active', s?.active, _teal),
                  const SizedBox(width: 10),
                  _Stat('Expired', s?.expired, _amber),
                  const SizedBox(width: 10),
                  _Stat('Revoked', s?.revoked, _pink),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: TextField(
                  onChanged: (v) {
                    _query = v;
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), _load);
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(Icons.search_rounded, color: p.textDim),
                    hintText: 'Search key, device ID or student',
                    hintStyle: TextStyle(color: p.textDim),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                children: [
                  for (final f in const ['all', 'active', 'expired', 'revoked'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f[0].toUpperCase() + f.substring(1)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _body(p)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New key'),
      ),
    );
  }

  Widget _body(AppPalette p) {
    if (_loading && _keys.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _keys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.textDim)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    final shown = _shown;
    return RefreshIndicator(
      onRefresh: _load,
      child: shown.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text('No keys here yet.', style: TextStyle(color: p.textDim)),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 110),
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _KeyCard(key: ValueKey(shown[i].key), k: shown[i], onAction: _action),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int? value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value?.toString() ?? '-',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: p.textDim)),
          ],
        ),
      ),
    );
  }
}

class _KeyCard extends StatelessWidget {
  final AdminKey k;
  final Future<void> Function(AdminKey, String) onAction;
  const _KeyCard({super.key, required this.k, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = _statusColor(k.status);
    final expiry = k.status == 'active'
        ? 'Expires ${_date(k.expiresAt)} (${k.daysLeft} days left)'
        : (k.status == 'expired' ? 'Expired ${_date(k.expiresAt)}' : 'Revoked');

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withAlpha(50),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(k.status.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ),
                    if (k.note.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(k.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(k.key,
                    style: const TextStyle(
                        fontSize: 16, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Device ${k.deviceId}',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: p.textDim)),
                const SizedBox(height: 2),
                Text(expiry, style: TextStyle(fontSize: 12, color: p.textDim)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (v) => onAction(k, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'copy', child: Text('Copy key')),
              const PopupMenuItem(value: 'extend', child: Text('Extend 30 days')),
              if (k.status == 'revoked')
                const PopupMenuItem(value: 'restore', child: Text('Restore'))
              else
                const PopupMenuItem(value: 'revoke', child: Text('Revoke')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: device ID + days + student name -> generates a key.
class _CreateKeySheet extends StatefulWidget {
  const _CreateKeySheet();

  @override
  State<_CreateKeySheet> createState() => _CreateKeySheetState();
}

class _CreateKeySheetState extends State<_CreateKeySheet> {
  final _device = TextEditingController();
  final _note = TextEditingController();
  final _days = TextEditingController(text: '30');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _device.dispose();
    _note.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() => _device.text = data!.text!.trim().toUpperCase());
    }
  }

  Future<void> _create() async {
    final days = int.tryParse(_days.text.trim());
    if (_device.text.trim().length < 4) {
      setState(() => _error = 'Paste the student\'s Device ID.');
      return;
    }
    if (days == null || days < 1 || days > 3650) {
      setState(() => _error = 'Days must be between 1 and 3650.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final k = await Api.createKey(_device.text.trim(), days, _note.text.trim());
      if (mounted) Navigator.pop(context, k);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(AppPalette p, String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New key',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text('Device ID (from the student)',
                    style: TextStyle(fontSize: 13, color: p.textDim)),
                const SizedBox(height: 8),
                TextField(
                  controller: _device,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: _decoration(
                    p,
                    'A7F3-92KD-41QX',
                    suffix: TextButton(onPressed: _paste, child: const Text('Paste')),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Valid for (days)', style: TextStyle(fontSize: 13, color: p.textDim)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in const [7, 30, 90, 365])
                      ChoiceChip(
                        label: Text('$d'),
                        selected: _days.text == '$d',
                        onSelected: (_) => setState(() => _days.text = '$d'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: _decoration(p, 'Custom number of days'),
                ),
                const SizedBox(height: 16),
                Text('Student name or note (optional)',
                    style: TextStyle(fontSize: 13, color: p.textDim)),
                const SizedBox(height: 8),
                TextField(controller: _note, decoration: _decoration(p, 'Rahul, batch 1')),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Color(0xFFFF6A6A), fontSize: 13)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : _create,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Generate key',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
