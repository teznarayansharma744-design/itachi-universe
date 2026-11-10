import 'package:flutter/material.dart';

import 'glass.dart';
import 'screens/key_screen.dart';
import 'theme.dart';

/// Demo: everything is visible but locked, except items marked free.
/// Premium: everything is unlocked.
enum AccessMode { demo, premium }

final ValueNotifier<AccessMode> accessMode = ValueNotifier(AccessMode.demo);

bool get isDemo => accessMode.value == AccessMode.demo;

/// Popup shown when a locked item is tapped in Demo Mode.
Future<void> showPremiumRequired(BuildContext context) {
  final p = AppPalette.of(context);
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
            const Icon(Icons.lock_rounded, size: 36),
            const SizedBox(height: 12),
            const Text('Locked in Demo Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'This lecture is for premium users. Enter your key to unlock everything.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: p.textDim),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KeyScreen()),
                  );
                },
                child: const Text('Enter Premium Key'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    ),
  );
}
