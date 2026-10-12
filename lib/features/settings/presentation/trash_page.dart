import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/trash.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../habits/application/habit_controller.dart';
import '../../habits/application/habit_trash_controller.dart';
import '../../habits/presentation/habit_icons.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/application/trash_controller.dart';

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return d.inDays == 1 ? 'yesterday' : '${d.inDays} days ago';
}

/// Deleted tasks and habits, kept for 30 days.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  Future<bool> _confirm(
      BuildContext context, String title, String text, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(trashProvider).value ?? [];
    final habits = ref.watch(habitTrashProvider).value ?? [];
    final total = tasks.length + habits.length;
    final taskTrash = ref.read(trashProvider.notifier);
    final habitTrash = ref.read(habitTrashProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final now = DateTime.now();

    void snack(String text) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (total > 0)
            PopupMenuButton<String>(
              onSelected: (_) async {
                if (await _confirm(
                    context,
                    'Empty trash?',
                    'This permanently deletes $total ${total == 1 ? 'item' : 'items'}.',
                    'Empty trash')) {
                  await taskTrash.empty();
                  await habitTrash.empty();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'empty', child: Text('Empty trash')),
              ],
            ),
        ],
      ),
      body: total == 0
          ? const EmptyState(
              icon: Icons.delete_outline_rounded,
              title: 'Trash is empty',
              subtitle: 'Deleted tasks and habits are kept here for 30 days.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Text(
                    'Items are removed for good after $kTrashRetentionDays days.',
                    style: TextStyle(color: muted),
                  ),
                ),
                if (tasks.isNotEmpty) _label(context, 'TASKS'),
                for (final item in tasks)
                  _TrashRow(
                    icon: Icons.task_alt_rounded,
                    color: Colors.grey,
                    title: item.task.title,
                    detail: 'Deleted ${_ago(item.deletedAt)} · ${item.daysLeft(now)} days left',
                    onRestore: () {
                      ref.read(taskControllerProvider.notifier).restore(item.task);
                      snack('Task restored');
                    },
                    onDelete: () async {
                      if (await _confirm(context, 'Delete forever?',
                          '"${item.task.title}" will be permanently deleted.', 'Delete')) {
                        await taskTrash.discard(item.task.id);
                      }
                    },
                  ),
                if (habits.isNotEmpty) _label(context, 'HABITS'),
                for (final item in habits)
                  _TrashRow(
                    icon: habitIcon(item.habit.iconIndex),
                    color: Color(item.habit.color),
                    title: item.habit.name,
                    detail: 'Deleted ${_ago(item.deletedAt)} · ${item.daysLeft(now)} days left',
                    onRestore: () {
                      ref.read(habitControllerProvider.notifier).restore(item.habit);
                      snack('Habit restored');
                    },
                    onDelete: () async {
                      if (await _confirm(context, 'Delete forever?',
                          '"${item.habit.name}" and its history will be permanently deleted.',
                          'Delete')) {
                        await habitTrash.discard(item.habit.id);
                      }
                    },
                  ),
              ],
            ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  const _TrashRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(children: [
          IconBadge(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(detail,
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          IconButton(
            tooltip: 'Restore',
            icon: const Icon(Icons.restore_from_trash_rounded, color: AppColors.green),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: 'Delete forever',
            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.red),
            onPressed: onDelete,
          ),
        ]),
      );
}
