import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder.dart';
import 'reminder_sheet.dart';

/// A row of reminder chips with an "add" chip. Used for tasks and subtasks.
class RemindersEditor extends ConsumerWidget {
  final List<int> reminders;
  final bool hasTime;
  final bool enabled;
  final String disabledLabel;
  final ValueChanged<List<int>> onChanged;
  const RemindersEditor({
    super.key,
    required this.reminders,
    required this.hasTime,
    required this.enabled,
    required this.onChanged,
    this.disabledLabel = 'Set a date to add reminders',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(icon: Icons.notifications_rounded, color: AppColors.orange),
          const SizedBox(width: 14),
          Expanded(
            child: !enabled
                ? Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(disabledLabel,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                : Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final m in reminders)
                      InputChip(
                        label: Text(reminderLabel(m, hasTime: hasTime)),
                        onDeleted: () =>
                            onChanged([for (final x in reminders) if (x != m) x]),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: Text(reminders.isEmpty ? 'Add reminder' : 'Add'),
                      onPressed: () => showReminderSheet(
                        context,
                        hasTime: hasTime,
                        taken: reminders.toSet(),
                        onSelected: (m) {
                          ref.read(reminderSchedulerProvider).requestPermission();
                          onChanged(withReminder(reminders, m));
                        },
                      ),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
