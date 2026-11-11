import 'package:flutter/material.dart';

import 'theme.dart';

/// Soft colored glow behind everything. Drawn with plain gradients (no blur filters),
/// so it costs almost nothing to paint, and it is painted only once.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  Widget _glow(Color color, double size, double opacity) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: p.bg)),
                Positioned(left: -140, top: -120, child: _glow(p.blob1, 460, 0.5)),
                Positioned(right: -180, top: 220, child: _glow(p.blob2, 440, 0.38)),
                Positioned(left: -120, bottom: -150, child: _glow(p.blob3, 440, 0.34)),
              ],
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}

/// Glass-style card: translucent fill and a thin light border. No blur, so scrolling
/// and screen changes stay smooth even on low-end phones.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? p.glassFill : null,
        gradient: gradient,
        borderRadius: shape,
        border: Border.all(color: p.glassBorder),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
