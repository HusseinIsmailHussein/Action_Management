import 'package:flutter/material.dart';
import '../../../core/widgets/app_card.dart';

/// One tappable row: colored icon badge, label, and a clear button or chevron.
class DetailRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool muted;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const DetailRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.muted = false,
    this.enabled = true,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconBadge(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                  color: muted ? scheme.onSurfaceVariant : null,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 20, color: scheme.onSurfaceVariant),
              )
            else
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
