import 'package:flutter/material.dart';

import '../access.dart';
import '../data.dart';
import '../glass.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lectures_screen.dart';

/// Lists the units (chapters) of a subject. Tapping one opens its lectures.
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
                  palette: p,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LecturesScreen(
                        subject: subject,
                        unit: subject.units[i],
                        unitNumber: i + 1,
                      ),
                    ),
                  ),
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
  final AppPalette palette;
  final VoidCallback onTap;
  const _UnitCard({
    required this.number,
    required this.unit,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inProgress = unit.status == UnitStatus.inProgress;
    final statusText = switch (unit.status) {
      UnitStatus.done => 'DONE',
      UnitStatus.inProgress => 'IN PROGRESS',
      UnitStatus.todo => '',
    };
    final allLocked = isDemo && unit.freeCount == 0;

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      gradient: inProgress
          ? const LinearGradient(
              colors: [Color(0x595B5BFF), Color(0x2E19C3B1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.text.withAlpha(36),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$number',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unit.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${unit.videos} videos / ${unit.pdfs} PDFs',
                    style: TextStyle(fontSize: 12, color: palette.textDim)),
              ],
            ),
          ),
          if (isDemo && unit.freeCount > 0)
            Text('${unit.freeCount} FREE',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF19C3B1)))
          else if (allLocked)
            const Icon(Icons.lock_rounded, size: 18)
          else if (statusText.isNotEmpty)
            Text(statusText,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: unit.status == UnitStatus.done
                        ? const Color(0xFF19C3B1)
                        : palette.text)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: palette.textDim),
        ],
      ),
    );
  }
}
