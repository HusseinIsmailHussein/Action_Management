import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/task.dart';
import '../domain/task_filter.dart';

/// The temporary filter layered over the current view (not persisted).
class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => const TaskFilter();

  void set(TaskFilter f) => state = f;
  void togglePriority(Priority p) => state = state.togglePriority(p);
  void toggleTag(String tag) => state = state.toggleTag(tag);
  void toggleList(String id) => state = state.toggleList(id);
  void setDue(DueRange? r) => state = state.withDue(r);
  void clear() => state = const TaskFilter();
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);
