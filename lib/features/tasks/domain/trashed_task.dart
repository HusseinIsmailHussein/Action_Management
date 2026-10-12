import '../../../core/trash.dart';
import 'task.dart';

/// A deleted task waiting in the trash.
class TrashedTask {
  final TaskItem task;
  final DateTime deletedAt;
  const TrashedTask({required this.task, required this.deletedAt});

  /// Days before this task is permanently removed (never negative).
  int daysLeft(DateTime now) {
    final left = kTrashRetentionDays - now.difference(deletedAt).inDays;
    return left < 0 ? 0 : left;
  }

  Map<String, dynamic> toJson() =>
      {'task': task.toJson(), 'deletedAt': deletedAt.toIso8601String()};

  factory TrashedTask.fromJson(Map<String, dynamic> j) => TrashedTask(
        task: TaskItem.fromJson(j['task'] as Map<String, dynamic>),
        deletedAt: DateTime.parse(j['deletedAt'] as String),
      );
}

/// [items] without the ones older than the retention period.
List<TrashedTask> withoutExpired(List<TrashedTask> items, DateTime now) =>
    items.where((i) => now.difference(i.deletedAt).inDays < kTrashRetentionDays).toList();
