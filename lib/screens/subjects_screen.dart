import 'package:flutter/material.dart';

import '../data.dart';
import '../glass.dart';
import '../theme.dart';
import '../widgets.dart';
import 'units_screen.dart';

class SubjectsScreen extends StatelessWidget {
  final Batch batch;
  const SubjectsScreen({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: GlassBackground(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackHeader(caption: 'Batch', title: batch.name),
              const SizedBox(height: 20),
              GlassCard(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overall progress',
                              style: TextStyle(fontSize: 13, color: p.textDim)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: 0.28,
                              minHeight: 6,
                              backgroundColor: p.text.withAlpha(40),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF19C3B1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text('28%',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Subjects',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.95,
                  children: [
                    for (final s in batch.subjects)
                      GlassCard(
                        radius: 24,
                        padding: const EdgeInsets.all(16),
                        gradient: LinearGradient(
                          colors: [s.tint.withAlpha(100), p.glassFill],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UnitsScreen(batch: batch, subject: s),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconTile(icon: s.icon, tint: s.tint, size: 44),
                            const Spacer(),
                            Text(s.name,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${s.units.length} units / ${s.lectures} lectures',
                                style: TextStyle(fontSize: 12, color: p.textDim)),
                          ],
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
