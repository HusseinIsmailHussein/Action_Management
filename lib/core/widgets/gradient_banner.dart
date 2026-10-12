import 'package:flutter/material.dart';
import '../theme.dart';

/// Big gradient banner used at the top of main screens.
/// [progress] = (done, total) shows a progress bar when total > 0.
class GradientBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final (int done, int total)? progress;
  const GradientBanner({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.progress,
  });

  Widget _bubble(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity), shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        gradient: color.gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(children: [
          Positioned(right: -30, top: -30, child: _bubble(130, 0.12)),
          Positioned(right: 50, bottom: -45, child: _bubble(100, 0.10)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
              if (p != null && p.$2 > 0) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: p.$1 / p.$2,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                const SizedBox(height: 6),
                Text('${p.$1} of ${p.$2} done',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
