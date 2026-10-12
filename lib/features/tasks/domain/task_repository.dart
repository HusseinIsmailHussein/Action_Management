import 'task.dart';

/// Swap the implementation (SQLite/Drift, Isar, Firebase, REST...)
/// without touching UI or state code.
abstract class TaskRepository {
  Future<List<TaskItem>> load();
  Future<void> save(List<TaskItem> tasks);
}
