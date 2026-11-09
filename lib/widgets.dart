import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme.dart';

/// Back button + small caption + title, used at the top of inner screens.
class BackHeader extends StatelessWidget {
  final String caption;
  final String title;
  const BackHeader({super.key, required this.caption, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(10),
          radius: 14,
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption, style: TextStyle(fontSize: 12, color: p.textDim)),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rounded square icon tile with a tinted background.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final double size;
  const IconTile({super.key, required this.icon, required this.tint, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withAlpha(80),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(icon, size: size * 0.5),
    );
  }
}
