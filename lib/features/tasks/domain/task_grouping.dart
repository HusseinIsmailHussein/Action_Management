import 'task.dart';
import 'view_options.dart';

/// A titled section of tasks. An empty [title] means "no header".
class TaskGroup {
  final String key; // stable id, e.g. 'overdue', 'p3', a list id
  final String title;
  final int? color; // ARGB when the group has its own (lists)
  final List<TaskItem> tasks;
  const TaskGroup({required this.key, required this.title, this.color, required this.tasks});
}

typedef ListInfo = ({String id, String name, int color});

const _dateBuckets = [
  ('overdue', 'Overdue'),
  ('today', 'Today'),
  ('tomorrow', 'Tomorrow'),
  ('week', 'Next 7 days'),
  ('later', 'Later'),
  ('none', 'No date'),
];

String _dateBucket(TaskItem t, DateTime now) {
  final due = t.due;
  if (due == null) return 'none';
  final diff = DateTime.utc(due.year, due.month, due.day)
      .difference(DateTime.utc(now.year, now.month, now.day))
      .inDays;
  if (diff < 0) return 'overdue';
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  if (diff <= 7) return 'week';
  return 'later';
}

const _priorityTitles = {
  Priority.high: 'High priority',
  Priority.medium: 'Medium priority',
  Priority.low: 'Low priority',
  Priority.none: 'No priority',
};

/// Splits already-sorted [tasks] into sections. Order inside a section is kept.
/// Finished tasks always collect in a final "Completed" section.
List<TaskGroup> groupTasks(
  List<TaskItem> tasks,
  GroupBy by,
  DateTime now, {
  required List<ListInfo> lists,
}) {
  if (by == GroupBy.none) return [TaskGroup(key: 'all', title: '', tasks: tasks)];

  final open = tasks.where((t) => !t.done).toList();
  final done = tasks.where((t) => t.done).toList();
  final groups = <TaskGroup>[];

  void add(String key, String title, List<TaskItem> items, {int? color}) {
    if (items.isNotEmpty) {
      groups.add(TaskGroup(key: key, title: title, color: color, tasks: items));
    }
  }

  switch (by) {
    case GroupBy.none:
      break;
    case GroupBy.date:
      for (final (key, title) in _dateBuckets) {
        add(key, title, open.where((t) => _dateBucket(t, now) == key).toList());
      }
    case GroupBy.priority:
      for (final p in [Priority.high, Priority.medium, Priority.low, Priority.none]) {
        add('p${p.index}', _priorityTitles[p]!, open.where((t) => t.priority == p).toList());
      }
    case GroupBy.list:
      final known = lists.map((l) => l.id).toSet();
      for (final l in lists) {
        add(l.id, l.name, open.where((t) => t.listId == l.id).toList(), color: l.color);
      }
      add('other', 'Other', open.where((t) => !known.contains(t.listId)).toList());
  }

  add('done', 'Completed', done);
  return groups;
}
