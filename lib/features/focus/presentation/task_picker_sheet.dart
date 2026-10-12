import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/presentation/task_tile.dart';

/// Pick an open task to focus on. [onSelected] gets null for "no task".
Future<void> showTaskPicker(
  BuildContext context, {
  required String? current,
  required ValueChanged<String?> onSelected,
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TaskPicker(
        current: current,
        onSelected: (id) {
          Navigator.pop(ctx);
          onSelected(id);
        },
      ),
    );

class _TaskPicker extends ConsumerWidget {
  final String? current;
  final ValueChanged<String?> onSelected;
  const _TaskPicker({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks =
        (ref.watch(taskControllerProvider).value ?? []).where((t) => !t.done).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('No task (free focus)'),
            selected: current == null,
            onTap: () => onSelected(null),
          ),
          for (final t in tasks)
            ListTile(
              leading: Icon(Icons.circle, size: 12, color: priorityColor(t.priority)),
              title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              selected: t.id == current,
              onTap: () => onSelected(t.id),
            ),
        ]),
      ),
    );
  }
}
