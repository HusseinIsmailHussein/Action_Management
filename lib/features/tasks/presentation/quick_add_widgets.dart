import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/date_utils.dart';
import '../domain/duration_options.dart';
import '../domain/quick_add.dart';
import '../domain/reminder.dart';

({IconData icon, String label}) _describe(QuickKind kind, QuickAddResult r) {
  final due = r.due;
  switch (kind) {
    case QuickKind.date:
      return (
        icon: Icons.event_rounded,
        // Show the time here too when it came from "in 30 minutes" (no separate time chip).
        label: due == null
            ? 'Date'
            : (r.kinds.contains(QuickKind.time)
                ? friendlyDue(DateTime(due.year, due.month, due.day), hasTime: false)
                : friendlyDue(due, hasTime: r.hasTime)),
      );
    case QuickKind.time:
      return (
        icon: Icons.schedule_rounded,
        label: due == null ? 'Time' : DateFormat.jm().format(due),
      );
    case QuickKind.repeat:
      return (icon: Icons.repeat_rounded, label: r.recurrence?.ruleLabel ?? 'Repeat');
    case QuickKind.priority:
      return (
        icon: Icons.flag_rounded,
        label: '${r.priority?.name ?? 'none'} priority',
      );
    case QuickKind.tags:
      return (icon: Icons.tag_rounded, label: r.tags.map((t) => '#$t').join(' '));
    case QuickKind.list:
      return (icon: Icons.folder_rounded, label: r.listName ?? 'List');
    case QuickKind.reminder:
      return (
        icon: Icons.notifications_active_rounded,
        label: r.reminders.map((m) => reminderLabel(m, hasTime: r.hasTime)).join(', '),
      );
    case QuickKind.duration:
      return (
        icon: Icons.hourglass_bottom_rounded,
        label: r.durationMinutes == null ? 'Duration' : durationLabel(r.durationMinutes!),
      );
  }
}

/// "Detected from your text" chips. Tap one to ignore it (the words then
/// stay in the title); tap again to use it.
class QuickAddChips extends StatelessWidget {
  final QuickAddResult detected; // everything recognisable in the text
  final Set<QuickKind> ignored;
  final ValueChanged<QuickKind> onToggle;
  const QuickAddChips({
    super.key,
    required this.detected,
    required this.ignored,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final kinds = [for (final k in QuickKind.values) if (detected.kinds.contains(k)) k];
    if (kinds.isEmpty) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Detected from your text (tap to ignore)',
            style: TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final k in kinds)
            FilterChip(
              avatar: Icon(_describe(k, detected).icon, size: 18),
              label: Text(_describe(k, detected).label),
              selected: !ignored.contains(k),
              onSelected: (_) => onToggle(k),
            ),
        ]),
      ]),
    );
  }
}

/// Examples of what quick add understands.
Future<void> showQuickAddHelp(BuildContext context) {
  Widget row(String title, String examples) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(examples,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Quick add'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Type naturally. Details are picked out of your text:'),
          const SizedBox(height: 12),
          row('Dates', 'tomorrow, friday, next monday, in 3 days, oct 15, 10/15, on the 1st, next week, end of month'),
          row('Times', '5pm, 17:30, at 9, noon, tomorrow morning'),
          row('Repeat', 'every day, every 2 weeks, every mon and thu, weekdays, monthly'),
          row('Priority', '!high, !medium, !low, !1 !2 !3, !!!'),
          row('Tags & list', '#work   ~Work   ~"My list"'),
          row('Reminder', 'remind me, remind 30 min before'),
          row('Duration', 'for 45 min (with a time)'),
          const Text('Example: Dentist friday 3pm for 1h #health !high every 6 months'),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))],
    ),
  );
}
