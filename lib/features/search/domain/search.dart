import '../../habits/domain/habit.dart';
import '../../tasks/domain/saved_filter.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/domain/task_list.dart';
import '../../tasks/domain/trashed_task.dart';
import '../../habits/domain/trashed_habit.dart';

/// Lowercase words of a query; a leading '#' (tag search) is ignored.
List<String> queryWords(String query) => query
    .toLowerCase()
    .replaceAll('#', ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// True when every word appears in [text] (any order, any case).
bool matchesAll(String text, List<String> words) {
  final t = text.toLowerCase();
  return words.every(t.contains);
}

class TaskHit {
  final TaskItem task;
  final String? snippet; // where it matched when the title didn't (notes, subtask...)
  final int score;
  const TaskHit({required this.task, this.snippet, required this.score});
}

String _excerpt(String text, String word) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final i = flat.toLowerCase().indexOf(word);
  if (i < 0) return flat.length > 70 ? '${flat.substring(0, 70)}…' : flat;
  final start = (i - 20).clamp(0, flat.length).toInt();
  final end = (i + word.length + 40).clamp(0, flat.length).toInt();
  return '${start > 0 ? '…' : ''}${flat.substring(start, end)}${end < flat.length ? '…' : ''}';
}

String? _snippet(TaskItem t, String word) {
  bool has(String s) => s.toLowerCase().contains(word);
  if (has(t.notes)) return _excerpt(t.notes, word);
  for (final s in t.subtasks) {
    if (has(s.title)) return 'Subtask: ${s.title}';
  }
  for (final c in t.comments) {
    if (has(c.text)) return 'Comment: ${_excerpt(c.text, word)}';
  }
  for (final tag in t.tags) {
    if (has(tag)) return '#$tag';
  }
  return null;
}

/// Tasks whose title, notes, tags, subtasks or comments contain all [words].
/// Title matches rank first, then open before finished, then by due date.
List<TaskHit> searchTasks(List<TaskItem> tasks, List<String> words) {
  if (words.isEmpty) return const [];
  final hits = <TaskHit>[];
  for (final t in tasks) {
    final haystack = [
      t.title,
      t.notes,
      ...t.tags,
      for (final s in t.subtasks) s.title,
      for (final c in t.comments) c.text,
    ].join('\n');
    if (!matchesAll(haystack, words)) continue;

    final inTitle = matchesAll(t.title, words);
    final score = inTitle ? (t.title.toLowerCase().startsWith(words.first) ? 3 : 2) : 1;
    hits.add(TaskHit(
      task: t,
      snippet: inTitle ? null : _snippet(t, words.first),
      score: score,
    ));
  }
  hits.sort((a, b) {
    final s = b.score.compareTo(a.score);
    if (s != 0) return s;
    if (a.task.done != b.task.done) return a.task.done ? 1 : -1;
    final x = a.task.due, y = b.task.due;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  });
  return hits;
}

class SearchResults {
  final List<TaskHit> tasks;
  final List<Habit> habits;
  final List<TaskList> lists;
  final List<(String, int)> tags; // (name, open tasks)
  final List<SavedFilter> filters;
  final List<TrashedTask> trashedTasks;
  final List<TrashedHabit> trashedHabits;

  const SearchResults({
    this.tasks = const [],
    this.habits = const [],
    this.lists = const [],
    this.tags = const [],
    this.filters = const [],
    this.trashedTasks = const [],
    this.trashedHabits = const [],
  });

  bool get isEmpty =>
      tasks.isEmpty &&
      habits.isEmpty &&
      lists.isEmpty &&
      tags.isEmpty &&
      filters.isEmpty &&
      trashedTasks.isEmpty &&
      trashedHabits.isEmpty;
}
