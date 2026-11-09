import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Soft colored blobs behind everything, so the glass cards have something to blur.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  Widget _blob(Color color, double size, double opacity) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha((opacity * 255).round()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: p.bg)),
        Positioned(left: -90, top: -70, child: _blob(p.blob1, 320, 0.55)),
        Positioned(right: -110, top: 260, child: _blob(p.blob2, 300, 0.4)),
        Positioned(left: -60, bottom: -80, child: _blob(p.blob3, 300, 0.35)),
        SafeArea(child: child),
      ],
    );
  }
}

/// Frosted glass card: blur + translucent fill + thin light border.
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
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: gradient == null ? p.glassFill : null,
                gradient: gradient,
                borderRadius: shape,
                border: Border.all(color: p.glassBorder),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
