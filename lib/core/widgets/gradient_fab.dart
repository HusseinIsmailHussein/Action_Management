import 'package:flutter/material.dart';
import '../theme.dart';

/// Round gradient action button. Defaults to the user's accent color.
class GradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color? color;
  const GradientFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppAccent.of(context);
    final radius = BorderRadius.circular(20);
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: c.gradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
              color: c.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
