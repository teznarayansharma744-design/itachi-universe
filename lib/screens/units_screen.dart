import 'package:flutter/material.dart';

import '../data.dart';
import '../glass.dart';
import '../theme.dart';
import '../widgets.dart';
import 'player_screen.dart';

class UnitsScreen extends StatelessWidget {
  final Batch batch;
  final Subject subject;
  const UnitsScreen({super.key, required this.batch, required this.subject});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: GlassBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            BackHeader(caption: batch.name, title: subject.name),
            const SizedBox(height: 20),
            for (var i = 0; i < subject.units.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _UnitCard(
                  number: i + 1,
                  unit: subject.units[i],
                  subjectName: subject.name,
                  palette: p,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final int number;
  final UnitItem unit;
  final String subjectName;
  final AppPalette palette;
  const _UnitCard({
    required this.number,
    required this.unit,
    required this.subjectName,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final inProgress = unit.status == UnitStatus.inProgress;
    final statusText = switch (unit.status) {
      UnitStatus.done => 'DONE',
      UnitStatus.inProgress => 'IN PROGRESS',
      UnitStatus.todo => '',
    };

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      gradient: inProgress
          ? const LinearGradient(
              colors: [Color(0x595B5BFF), Color(0x2E19C3B1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.text.withAlpha(36),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$number',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(unit.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (statusText.isNotEmpty)
                Text(statusText,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: unit.status == UnitStatus.done
                            ? const Color(0xFF19C3B1)
                            : palette.text)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Chip(
                  icon: Icons.play_circle_outline_rounded,
                  label: '${unit.videos} Videos',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(
                        title: unit.title,
                        subtitle: '$subjectName / Unit $number',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Chip(
                  icon: Icons.picture_as_pdf_outlined,
                  iconColor: const Color(0xFFFF9CC3),
                  label: '${unit.pdfs} PDFs',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF viewer is coming in the next step.')),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.label, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.text.withAlpha(24),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
