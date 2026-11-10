import 'package:flutter/material.dart';

/// Wraps a widget; tapping it [taps] times quickly calls [onUnlocked].
/// Used to open the admin login without a visible button.
class SecretTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onUnlocked;
  final int taps;
  const SecretTap({
    super.key,
    required this.child,
    required this.onUnlocked,
    this.taps = 7,
  });

  @override
  State<SecretTap> createState() => _SecretTapState();
}

class _SecretTapState extends State<SecretTap> {
  int _count = 0;
  DateTime? _last;

  void _tap() {
    final now = DateTime.now();
    if (_last == null || now.difference(_last!) > const Duration(seconds: 2)) {
      _count = 0;
    }
    _last = now;
    _count++;
    if (_count >= widget.taps) {
      _count = 0;
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _tap,
      child: widget.child,
    );
  }
}
