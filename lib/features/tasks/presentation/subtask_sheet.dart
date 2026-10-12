import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/date_utils.dart';
import '../../../core/theme.dart';
import '../application/task_controller.dart';
import '../domain/reminder.dart';
import '../domain/task.dart';
import 'date_pickers.dart';
import 'detail_row.dart';
import 'reminders_editor.dart';

/// Edit a subtask: title, date, time and reminders.
Future<void> showSubtaskSheet(
  BuildContext context, {
  required String taskId,
  required String subtaskId,
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubtaskSheet(taskId: taskId, subtaskId: subtaskId),
    );

class _SubtaskSheet extends ConsumerStatefulWidget {
  final String taskId;
  final String subtaskId;
  const _SubtaskSheet({required this.taskId, required this.subtaskId});
  @override
  ConsumerState<_SubtaskSheet> createState() => _SubtaskSheetState();
}

class _SubtaskSheetState extends ConsumerState<_SubtaskSheet> {
  late final TextEditingController _title;

  Subtask? _find() {
    final task = ref.read(taskByIdProvider(widget.taskId));
    if (task == null) return null;
    for (final s in task.subtasks) {
      if (s.id == widget.subtaskId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _find()?.title ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _edit(Subtask Function(Subtask) change) => ref
      .read(taskControllerProvider.notifier)
      .editSubtask(widget.taskId, widget.subtaskId, change);

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(taskByIdProvider(widget.taskId));
    Subtask? sub;
    for (final s in task?.subtasks ?? const <Subtask>[]) {
      if (s.id == widget.subtaskId) sub = s;
    }
    if (sub == null) return const SizedBox.shrink();
    final s = sub;
    final hasDue = s.due != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 20, 4),
            child: Row(children: [
              Checkbox(
                value: s.done,
                shape: const CircleBorder(),
                activeColor: AppColors.teal,
                onChanged: (_) => _edit((x) => x.copyWith(done: !x.done)),
              ),
              Expanded(
                child: TextField(
                  controller: _title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                      border: InputBorder.none, hintText: 'Subtask'),
                  onChanged: (v) => _edit((x) => x.copyWith(title: v)),
                ),
              ),
            ]),
          ),
          const Divider(),
          DetailRow(
            icon: Icons.event_rounded,
            color: AppColors.blue,
            label: hasDue ? DateFormat.yMMMEd().format(s.due!) : 'Add date',
            muted: !hasDue,
            onTap: () async {
              final d = await pickDate(context, initial: s.due);
              if (d != null) {
                _edit((x) => x.copyWith(due: withDay(x.due, d, keepTime: x.hasTime)));
              }
            },
            onClear: hasDue ? () => _edit((x) => x.copyWith(clearDue: true)) : null,
          ),
          DetailRow(
            icon: Icons.schedule_rounded,
            color: AppColors.violet,
            label: s.hasTime ? DateFormat.jm().format(s.due!) : 'Add time',
            muted: !s.hasTime,
            onTap: () async {
              final tm = await pickTimeOfDay(context, initial: s.due, hasTime: s.hasTime);
              if (tm != null) {
                _edit((x) =>
                    x.copyWith(due: withTime(x.due, tm.hour, tm.minute), hasTime: true));
              }
            },
            onClear: s.hasTime
                ? () => _edit((x) => x.copyWith(
                      due: dateOnly(x.due!),
                      hasTime: false,
                      reminders: x.reminders
                          .where(reminderPresetsFor(false).contains)
                          .toList(),
                    ))
                : null,
          ),
          RemindersEditor(
            reminders: s.reminders,
            hasTime: s.hasTime,
            enabled: hasDue,
            onChanged: (r) => _edit((x) => x.copyWith(reminders: r)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                label: const Text('Delete subtask',
                    style: TextStyle(color: AppColors.red)),
                onPressed: () {
                  ref
                      .read(taskControllerProvider.notifier)
                      .removeSubtask(widget.taskId, widget.subtaskId);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
