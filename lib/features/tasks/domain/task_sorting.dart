import 'task.dart';
import 'view_options.dart';

/// Position in the user's manual order. Tasks never dragged yet fall back to
/// "newest first" (new tasks appear at the top).
double effectiveOrder(TaskItem t) =>
    t.order ?? -t.createdAt.millisecondsSinceEpoch.toDouble();

int _byDue(TaskItem a, TaskItem b) {
  final x = a.due, y = b.due;
  if (x == null && y == null) return 0;
  if (x == null) return 1; // undated last
  if (y == null) return -1;
  return x.compareTo(y);
}

int _byKey(SortBy sort, TaskItem a, TaskItem b) => switch (sort) {
      SortBy.smart => () {
          final p = b.priority.index.compareTo(a.priority.index);
          return p != 0 ? p : _byDue(a, b);
        }(),
      SortBy.dueDate => _byDue(a, b),
      SortBy.priority => b.priority.index.compareTo(a.priority.index),
      SortBy.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      SortBy.created => b.createdAt.compareTo(a.createdAt),
      SortBy.manual => effectiveOrder(a).compareTo(effectiveOrder(b)),
    };

/// Sorts [tasks] in place. Whatever the chosen order: finished tasks sink
/// (most recently finished first). Pinned tasks float up among open ones,
/// except in Manual order where the user's arrangement wins.
void sortTasks(List<TaskItem> tasks, ViewOptions options) {
  final fixedDirection = options.sort == SortBy.smart || options.sort == SortBy.manual;
  tasks.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.done && a.completedAt != null && b.completedAt != null) {
      return b.completedAt!.compareTo(a.completedAt!);
    }
    if (options.sort != SortBy.manual && a.pinned != b.pinned) {
      return a.pinned ? -1 : 1;
    }
    final c = _byKey(options.sort, a, b);
    return options.reversed && !fixedDirection ? -c : c;
  });
}
