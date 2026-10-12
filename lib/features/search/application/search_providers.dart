import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../habits/application/habit_controller.dart';
import '../../habits/application/habit_trash_controller.dart';
import '../../tasks/application/list_controller.dart';
import '../../tasks/application/saved_filter_controller.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/application/trash_controller.dart';
import '../domain/search.dart';

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String query) => state = query;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

/// Everything that matches the current query, grouped by kind.
final searchResultsProvider = Provider<SearchResults>((ref) {
  final words = queryWords(ref.watch(searchQueryProvider));
  if (words.isEmpty) return const SearchResults();

  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final habits = ref.watch(habitControllerProvider).value ?? [];
  final lists = ref.watch(listControllerProvider).value ?? [];
  final filters = ref.watch(savedFilterControllerProvider).value ?? [];
  final trashedTasks = ref.watch(trashProvider).value ?? [];
  final trashedHabits = ref.watch(habitTrashProvider).value ?? [];

  return SearchResults(
    tasks: searchTasks(tasks, words),
    habits: habits.where((h) => matchesAll(h.name, words)).toList(),
    lists: lists.where((l) => matchesAll(l.name, words)).toList(),
    tags: ref.watch(allTagsProvider).where((t) => matchesAll(t.$1, words)).toList(),
    filters: filters.where((f) => matchesAll(f.name, words)).toList(),
    trashedTasks: trashedTasks.where((t) => matchesAll(t.task.title, words)).toList(),
    trashedHabits: trashedHabits.where((t) => matchesAll(t.habit.name, words)).toList(),
  );
});
