import 'task.dart';

enum DueRange { overdue, today, next7Days, noDate }

extension DueRangeX on DueRange {
  String get label => switch (this) {
        DueRange.overdue => 'Overdue',
        DueRange.today => 'Today',
        DueRange.next7Days => 'Next 7 days',
        DueRange.noDate => 'No date',
      };
}

/// Criteria for picking tasks. Empty set / null = "don't filter on this".
/// Dimensions are ANDed; within priorities, lists, tags a task matches ANY chosen value.
/// To add a dimension: field here + check in matches() + JSON + a chip group in filter_sheet.dart.
class TaskFilter {
  final Set<Priority> priorities;
  final Set<String> tags;
  final Set<String> listIds;
  final DueRange? due;

  const TaskFilter({
    this.priorities = const {},
    this.tags = const {},
    this.listIds = const {},
    this.due,
  });

  bool get isActive =>
      priorities.isNotEmpty || tags.isNotEmpty || listIds.isNotEmpty || due != null;

  bool matches(TaskItem t, [DateTime? now]) =>
      (priorities.isEmpty || priorities.contains(t.priority)) &&
      (tags.isEmpty || t.tags.any(tags.contains)) &&
      (listIds.isEmpty || listIds.contains(t.listId)) &&
      _matchesDue(t, now ?? DateTime.now());

  bool _matchesDue(TaskItem t, DateTime now) {
    final range = due;
    if (range == null) return true;
    final d = t.due;
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case DueRange.noDate:
        return d == null;
      case DueRange.overdue:
        return d != null && d.isBefore(today);
      case DueRange.today:
        return d != null &&
            !d.isBefore(today) &&
            d.isBefore(DateTime(today.year, today.month, today.day + 1));
      case DueRange.next7Days:
        return d != null &&
            !d.isBefore(today) &&
            d.isBefore(DateTime(today.year, today.month, today.day + 8));
    }
  }

  TaskFilter togglePriority(Priority p) =>
      TaskFilter(priorities: _toggle(priorities, p), tags: tags, listIds: listIds, due: due);

  TaskFilter toggleTag(String tag) =>
      TaskFilter(priorities: priorities, tags: _toggle(tags, tag), listIds: listIds, due: due);

  TaskFilter toggleList(String id) =>
      TaskFilter(priorities: priorities, tags: tags, listIds: _toggle(listIds, id), due: due);

  TaskFilter withDue(DueRange? range) =>
      TaskFilter(priorities: priorities, tags: tags, listIds: listIds, due: range);

  static Set<T> _toggle<T>(Set<T> s, T v) =>
      s.contains(v) ? (Set<T>.of(s)..remove(v)) : {...s, v};

  Map<String, dynamic> toJson() => {
        'priorities': [for (final p in priorities) p.index],
        'tags': tags.toList(),
        'listIds': listIds.toList(),
        'due': due?.index,
      };

  factory TaskFilter.fromJson(Map<String, dynamic> j) => TaskFilter(
        priorities: {
          for (final i in (j['priorities'] ?? const []) as List)
            Priority.values[i as int]
        },
        tags: {...List<String>.from((j['tags'] ?? const []) as List)},
        listIds: {...List<String>.from((j['listIds'] ?? const []) as List)},
        due: j['due'] == null ? null : DueRange.values[j['due'] as int],
      );
}
