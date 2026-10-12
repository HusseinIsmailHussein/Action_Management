import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../habits/application/habit_controller.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/domain/task.dart';

/// Open tasks due today or overdue, soonest first, then by priority.
final todayTasksProvider = Provider<List<TaskItem>>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final now = DateTime.now();
  return tasks.where((t) => matchesSmart(t, SmartView.today, now)).toList()
    ..sort((a, b) {
      final byDue = a.due!.compareTo(b.due!);
      return byDue != 0 ? byDue : b.priority.index.compareTo(a.priority.index);
    });
});

final overdueCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return tasks.where((t) => !t.done && t.due != null && t.due!.isBefore(today)).length;
});

/// Tasks + habits finished today, out of everything planned for today.
final dayProgressProvider = Provider<(int, int)>((ref) {
  final tasks = ref.watch(todayProgressProvider);
  final habits = ref.watch(habitProgressProvider);
  return (tasks.$1 + habits.$1, tasks.$2 + habits.$2);
});
