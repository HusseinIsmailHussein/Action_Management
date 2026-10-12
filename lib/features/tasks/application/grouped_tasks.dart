import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/task_grouping.dart';
import '../domain/task_list.dart';
import '../domain/view_options.dart';
import 'list_controller.dart';
import 'task_controller.dart';
import 'view_options_controller.dart';

/// The visible tasks (already sorted) split into sections per the group option.
final groupedTasksProvider = Provider<List<TaskGroup>>((ref) {
  final tasks = ref.watch(visibleTasksProvider);
  final options = ref.watch(viewOptionsProvider).value ?? const ViewOptions();
  final lists = ref.watch(listControllerProvider).value ?? [TaskList.inbox()];
  return groupTasks(
    tasks,
    options.group,
    DateTime.now(),
    lists: [for (final l in lists) (id: l.id, name: l.name, color: l.color)],
  );
});
