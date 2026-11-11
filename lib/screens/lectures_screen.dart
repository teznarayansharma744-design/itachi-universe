import 'package:flutter/material.dart';

import '../access.dart';
import '../data.dart';
import '../glass.dart';
import '../theme.dart';
import '../widgets.dart';
import '../api.dart';
import 'pdf_screen.dart';
import 'player_screen.dart';

enum _Filter { all, video, pdf }

/// Every lecture of one unit as a separate card.
/// Under each lecture name: "Play video" and "View PDF" (when they exist).
/// The top tabs All / Video / PDF also show PDF-only items.
class LecturesScreen extends StatefulWidget {
  final Subject subject;
  final UnitItem unit;
  final int unitNumber;
  const LecturesScreen({
    super.key,
    required this.subject,
    required this.unit,
    required this.unitNumber,
  });

  @override
  State<LecturesScreen> createState() => _LecturesScreenState();
}

class _LecturesScreenState extends State<LecturesScreen> {
  _Filter _filter = _Filter.all;

  List<Lecture> get _visible => widget.unit.lectures.where((l) {
        switch (_filter) {
          case _Filter.all:
            return true;
          case _Filter.video:
            return l.hasVideo;
          case _Filter.pdf:
            return l.hasPdf;
        }
      }).toList();

  void _play(Lecture l) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            lectureId: l.id,
            title: l.title,
            subtitle: '${widget.subject.name} / ${widget.unit.title}',
          ),
        ),
      );

  void _openPdf(Lecture l) {
    if (!Api.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample mode: connect the app to your server to open PDFs.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfScreen(
          lectureId: l.id,
          title: l.title,
          subtitle: '${widget.subject.name} / ${widget.unit.title}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final unit = widget.unit;
    final items = _visible;

    return Scaffold(
      body: GlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackHeader(
                caption: '${widget.subject.name} / Unit ${widget.unitNumber}',
                title: unit.title,
              ),
              const SizedBox(height: 20),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    _Tab('All', unit.lectures.length, _filter == _Filter.all,
                        () => setState(() => _filter = _Filter.all)),
                    _Tab('Video', unit.videos, _filter == _Filter.video,
                        () => setState(() => _filter = _Filter.video)),
                    _Tab('PDF', unit.pdfs, _filter == _Filter.pdf,
                        () => setState(() => _filter = _Filter.pdf)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text('Nothing here yet.',
                            style: TextStyle(color: p.textDim)),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: ListView.separated(
                          key: ValueKey(_filter),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _LectureCard(
                            lecture: items[i],
                            onPlay: () => _play(items[i]),
                            onPdf: () => _openPdf(items[i]),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(this.label, this.count, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.text.withAlpha(40) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$label ($count)',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? p.text : p.textDim)),
        ),
      ),
    );
  }
}

class _LectureCard extends StatelessWidget {
  final Lecture lecture;
  final VoidCallback onPlay;
  final VoidCallback onPdf;
  const _LectureCard({
    required this.lecture,
    required this.onPlay,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final locked = isDemo && !lecture.free;
    final pdfOnly = !lecture.hasVideo;

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: pdfOnly
                    ? Icons.picture_as_pdf_outlined
                    : Icons.play_circle_outline_rounded,
                tint: pdfOnly ? const Color(0xFFFF6AA2) : const Color(0xFF5B5BFF),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(lecture.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (isDemo && lecture.free)
                const Text('FREE',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF19C3B1)))
              else if (locked)
                Icon(Icons.lock_rounded, size: 18, color: p.textDim),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (lecture.hasVideo)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Play video',
                    locked: locked,
                    onTap: onPlay,
                  ),
                ),
              if (lecture.hasVideo && lecture.hasPdf) const SizedBox(width: 10),
              if (lecture.hasPdf)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.picture_as_pdf_outlined,
                    iconColor: const Color(0xFFFF9CC3),
                    label: 'View PDF',
                    locked: locked,
                    onTap: onPdf,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final bool locked;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.locked,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: locked ? () => showPremiumRequired(context) : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: p.text.withAlpha(24),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(locked ? Icons.lock_rounded : icon,
                size: 18, color: locked ? null : iconColor),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
