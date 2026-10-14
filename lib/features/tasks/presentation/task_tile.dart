import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/date_utils.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../application/list_controller.dart';
import '../application/task_controller.dart';
import '../domain/task.dart';
import 'task_detail_page.dart';

Color priorityColor(Priority p) => switch (p) {
  Priority.high => AppColors.red,
  Priority.medium => AppColors.orange,
  Priority.low => AppColors.blue,
  Priority.none => Colors.grey,
};

class _Pill extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color color;
  const _Pill({this.label, this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 13, color: color),
        if (icon != null && label != null) const SizedBox(width: 4),
        if (label != null)
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
      ],
    ),
  );
}

/// "Today, 3:00 PM – 3:30 PM" style label for a task's date.
String _dueLabel(TaskItem t) {
  final base = friendlyDue(t.due!, hasTime: t.hasTime);
  final d = t.durationMinutes;
  if (!t.hasTime || d == null) return base;
  return '$base – ${DateFormat.jm().format(t.due!.add(Duration(minutes: d)))}';
}

/// A task as a card. Swipe right = complete, swipe left = delete.
/// [projected] = a future occurrence of a repeating task (calendar only):
/// dimmed, tap opens the real task, can't be completed or swiped away.
class TaskTile extends ConsumerWidget {
  final TaskItem task;
  final bool projected;
  const TaskTile({super.key, required this.task, this.projected = false});

  static const _margin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

  void _snack(
    ScaffoldMessengerState messenger,
    String text, {
    VoidCallback? undo,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 4),
          action: undo == null
              ? null
              : SnackBarAction(label: 'Undo', onPressed: undo),
        ),
      );
  }

  Widget _swipeBackground(Color color, IconData icon, Alignment align) =>
      Container(
        margin: _margin,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: align,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: Colors.white),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(taskControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final list = ref.watch(listByIdProvider(task.listId));
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    Color? dueColor;
    if (task.due != null) {
      if (task.done) {
        dueColor = Colors.grey;
      } else if (task.due!.isBefore(today)) {
        dueColor = AppColors.red;
      } else if (task.due!.isBefore(tomorrow)) {
        dueColor = AppColors.blue;
      } else {
        dueColor = scheme.onSurfaceVariant;
      }
    }
    final subDone = task.subtasks.where((s) => s.done).length;
    final muted = scheme.onSurfaceVariant;

    final pills = <Widget>[
      if (task.wontDo) const _Pill(label: "Won't do", color: Colors.grey),
      if (task.due != null)
        _Pill(
          label: _dueLabel(task),
          icon: Icons.event_rounded,
          color: dueColor!,
        ),
      if (task.recurrence != null)
        const _Pill(icon: Icons.repeat_rounded, color: AppColors.green),
      if (task.reminders.isNotEmpty && !task.done)
        const _Pill(
          icon: Icons.notifications_active_rounded,
          color: AppColors.orange,
        ),
      if (task.subtasks.isNotEmpty)
        _Pill(
          label: '$subDone/${task.subtasks.length}',
          icon: Icons.account_tree_rounded,
          color: AppColors.teal,
        ),
      for (final tag in task.tags) _Pill(label: '#$tag', color: AppColors.pink),
      if (task.notes.trim().isNotEmpty)
        _Pill(icon: Icons.notes_rounded, color: muted),
      if (task.comments.isNotEmpty)
        _Pill(
          label: '${task.comments.length}',
          icon: Icons.chat_bubble_outline_rounded,
          color: muted,
        ),
      if (list != null) _Pill(label: list.name, color: Color(list.color)),
    ];

    final card = AppCard(
      margin: _margin,
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: task.id)),
      ),
      child: Row(
        children: [
          if (task.wontDo)
            IconButton(
              icon: const Icon(
                Icons.do_not_disturb_on_rounded,
                color: Colors.grey,
              ),
              onPressed: projected ? null : () => ctrl.toggle(task.id),
            )
          else
            Transform.scale(
              scale: 1.15,
              child: Checkbox(
                value: task.done,
                shape: const CircleBorder(),
                side: BorderSide(color: priorityColor(task.priority), width: 2),
                activeColor: priorityColor(task.priority),
                onChanged: projected ? null : (_) => ctrl.toggle(task.id),
              ),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: task.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.done ? Colors.grey : null,
                        ),
                      ),
                    ),
                    if (task.pinned)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          color: AppColors.orange,
                        ),
                      ),
                  ],
                ),
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: pills),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (projected) return Opacity(opacity: 0.6, child: card);

    return Dismissible(
      key: ValueKey(task.id),
      background: _swipeBackground(
        AppColors.green,
        task.done ? Icons.undo_rounded : Icons.check_rounded,
        Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBackground(
        AppColors.red,
        Icons.delete_rounded,
        Alignment.centerRight,
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          final reopening = task.done;
          // Completing a repeating task rolls it forward, which a plain toggle can't undo.
          final canUndo = reopening || task.recurrence == null;
          ctrl.toggle(task.id);
          _snack(
            messenger,
            reopening ? 'Task reopened' : 'Task completed',
            undo: canUndo ? () => ctrl.toggle(task.id) : null,
          );
          return false; // stays in the list; the view re-sorts itself
        }
        return true;
      },
      onDismissed: (_) {
        ctrl.remove(task.id);
        _snack(messenger, 'Task deleted', undo: () => ctrl.restore(task));
      },
      child: card,
    );
  }
}
