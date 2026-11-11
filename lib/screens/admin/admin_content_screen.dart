import 'package:flutter/material.dart';

import '../../api.dart';
import '../../glass.dart';
import '../../theme.dart';
import 'admin_login_screen.dart';

const _teal = Color(0xFF19C3B1);
const _amber = Color(0xFFFFB84D);
const _pink = Color(0xFFFF6AA2);

/// Admin: see every batch, subject, unit and lecture, and add / edit / delete them.
/// Tap an item to go inside. The top bar shows where you are.
class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  static const _kinds = ['batches', 'subjects', 'units', 'lectures'];
  static const _words = ['batch', 'subject', 'unit', 'lecture'];

  List<dynamic> _data = [];
  final List<int> _path = []; // ids: batch, subject, unit
  bool _loading = true;
  String? _error;

  int get _level => _path.length; // 0 batches, 1 subjects, 2 units, 3 lectures

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _toLogin() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await Api.adminContent();
      if (!mounted) return;
      setState(() => _data = d);
      // If the item we are inside was deleted elsewhere, go back to the top.
      if (_level >= 1 && _find(_data, _path[0]) == null) _path.clear();
      if (_level >= 2 && _find(_current(1)['subjects'], _path[1]) == null) _path.length = 1;
      if (_level >= 3 && _find(_current(2)['units'], _path[2]) == null) _path.length = 2;
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.unauthorized) return _toLogin();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs a change, then reloads. Returns true when it worked.
  Future<bool> _run(Future<void> Function() change, String done) async {
    try {
      await change();
      if (!mounted) return true;
      _toast(done);
      await _load();
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      if (e.unauthorized) {
        _toLogin();
      } else {
        _toast(e.message);
      }
      return false;
    }
  }

  Map? _find(List<dynamic> list, int id) {
    for (final e in list) {
      if (e['id'] == id) return e as Map;
    }
    return null;
  }

  /// The batch (level 1), subject (2) or unit (3) we are inside.
  Map _current(int level) {
    var m = _find(_data, _path[0])!;
    if (level >= 2) m = _find(m['subjects'], _path[1])!;
    if (level >= 3) m = _find(m['units'], _path[2])!;
    return m;
  }

  List<dynamic> get _items {
    switch (_level) {
      case 0:
        return _data;
      case 1:
        return _current(1)['subjects'] as List;
      case 2:
        return _current(2)['units'] as List;
      default:
        return _current(3)['lectures'] as List;
    }
  }

  String get _title {
    if (_level == 0) return 'Lectures';
    final m = _current(_level);
    return (m['name'] ?? m['title']) as String;
  }

  // ---- counts shown on the cards ----
  int _lecturesIn(Map m, int level) {
    // level: 0 batch, 1 subject, 2 unit
    if (level == 2) return (m['lectures'] as List).length;
    final children = (level == 0 ? m['subjects'] : m['units']) as List;
    return children.fold<int>(0, (n, c) => n + _lecturesIn(c as Map, level + 1));
  }

  String _subtitle(Map m) {
    switch (_level) {
      case 0:
        final subjects = (m['subjects'] as List).length;
        return '$subjects subjects, ${_lecturesIn(m, 0)} lectures';
      case 1:
        final units = (m['units'] as List).length;
        return '$units units, ${_lecturesIn(m, 1)} lectures';
      default:
        return '${_lecturesIn(m, 2)} lectures';
    }
  }

  // ---- actions ----
  Future<String?> _askName(String title, String initial) async {
    final c = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> _add() async {
    if (_level == 3) return _editLecture(null);
    final name = await _askName('New ${_words[_level]}', '');
    if (name == null) return;
    await _run(
      () => Api.addItem(_kinds[_level], name, parentId: _level == 0 ? null : _path[_level - 1]),
      'Added.',
    );
  }

  Future<void> _editLecture(Map? lecture) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LectureSheet(lecture: lecture, unitId: _level == 3 ? _path[2] : null),
    );
    if (saved == true && mounted) {
      _toast(lecture == null ? 'Lecture added.' : 'Lecture saved.');
      _load();
    }
  }

  Future<void> _rename(Map m) async {
    final name = await _askName('Rename ${_words[_level]}', (m['name'] ?? '') as String);
    if (name == null) return;
    await _run(() => Api.renameItem(_kinds[_level], m['id'] as int, name), 'Renamed.');
  }

  Future<void> _delete(Map m) async {
    final name = (m['name'] ?? m['title']) as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_words[_level]}?'),
        content: Text(_level == 3
            ? '"$name" will be removed.'
            : '"$name" and everything inside it will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => Api.deleteItem(_kinds[_level], m['id'] as int), 'Deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final items = _loading && _data.isEmpty ? <dynamic>[] : _items;
    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _path.removeLast());
      },
      child: Scaffold(
        body: GlassBackground(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(10),
                      radius: 14,
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(Icons.chevron_left_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _error != null && _data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: TextStyle(color: p.textDim)),
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: _load, child: const Text('Try again')),
                          ],
                        ),
                      )
                    : _loading && _data.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: items.isEmpty
                                ? ListView(children: [
                                    const SizedBox(height: 80),
                                    Center(
                                      child: Text('No ${_words[_level]}s yet. Tap Add.',
                                          style: TextStyle(color: p.textDim)),
                                    ),
                                  ])
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 110),
                                    itemCount: items.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (_, i) => _row(p, items[i] as Map),
                                  ),
                          ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: Text('Add ${_words[_level]}'),
        ),
      ),
    );
  }

  Widget _chip(String text, bool on, Color color) {
    final c = on ? color : Colors.grey;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(on ? 50 : 25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
    );
  }

  Widget _row(AppPalette p, Map m) {
    final isLecture = _level == 3;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      onTap: isLecture ? () => _editLecture(m) : () => setState(() => _path.add(m['id'] as int)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((m['name'] ?? m['title']) as String,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (isLecture)
                  Row(children: [
                    _chip(m['has_video'] == true ? 'VIDEO' : 'NO VIDEO', m['has_video'] == true, _teal),
                    _chip(m['has_pdf'] == true ? 'PDF' : 'NO PDF', m['has_pdf'] == true, _amber),
                    if (m['free'] == true) _chip('FREE', true, _pink),
                  ])
                else
                  Text(_subtitle(m), style: TextStyle(fontSize: 12, color: p.textDim)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') isLecture ? _editLecture(m) : _rename(m);
              if (v == 'delete') _delete(m);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(isLecture ? 'Edit' : 'Rename')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add or edit one lecture: title, video link, PDF link, free switch.
class _LectureSheet extends StatefulWidget {
  final Map? lecture;
  final int? unitId;
  const _LectureSheet({required this.lecture, required this.unitId});

  @override
  State<_LectureSheet> createState() => _LectureSheetState();
}

class _LectureSheetState extends State<_LectureSheet> {
  late final _title = TextEditingController(text: (widget.lecture?['title'] ?? '') as String);
  late final _video = TextEditingController(text: (widget.lecture?['video_url'] ?? '') as String);
  late final _pdf = TextEditingController(text: (widget.lecture?['pdf_url'] ?? '') as String);
  late bool _free = widget.lecture?['free'] == true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _video.dispose();
    _pdf.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.saveLecture(
        id: widget.lecture?['id'] as int?,
        unitId: widget.unitId,
        title: _title.text.trim(),
        video: _video.text.trim(),
        pdf: _pdf.text.trim(),
        free: _free,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(AppPalette p, String hint) => InputDecoration(
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
                Text(widget.lecture == null ? 'Add lecture' : 'Edit lecture',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec(p, 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _video,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: _dec(p, 'Video link (mp4, m3u8 or YouTube)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pdf,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: _dec(p, 'PDF link (direct or Google Drive)'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Free in Demo Mode'),
                  value: _free,
                  onChanged: (v) => setState(() => _free = v),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Color(0xFFFF6A6A), fontSize: 13)),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Save',
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
