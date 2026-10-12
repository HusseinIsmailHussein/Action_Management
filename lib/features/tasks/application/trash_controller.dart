import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_trash_repository.dart';
import '../domain/task.dart';
import '../domain/trash_repository.dart';
import '../domain/trashed_task.dart';

final trashRepositoryProvider =
    Provider<TrashRepository>((ref) => LocalTrashRepository());

/// Deleted tasks, newest first. Entries older than 30 days are dropped on load.
/// Restoring goes through TaskController.restore, which also leaves the trash.
class TrashController extends AsyncNotifier<List<TrashedTask>> {
  TrashRepository get _repo => ref.read(trashRepositoryProvider);

  @override
  Future<List<TrashedTask>> build() async {
    final all = await _repo.load();
    final kept = withoutExpired(all, DateTime.now());
    if (kept.length != all.length) await _repo.save(kept);
    return kept;
  }

  Future<void> _set(List<TrashedTask> next) async {
    state = AsyncData(next);
    await _repo.save(next);
  }

  Future<void> add(TaskItem task) async {
    final current = await future; // wait for the stored list to load first
    await _set([
      TrashedTask(task: task, deletedAt: DateTime.now()),
      ...current.where((t) => t.task.id != task.id),
    ]);
  }

  /// Removes one entry (after a restore, or "delete forever").
  Future<void> discard(String taskId) async {
    final current = await future;
    await _set(current.where((t) => t.task.id != taskId).toList());
  }

  Future<void> empty() => _set(<TrashedTask>[]);
}

final trashProvider =
    AsyncNotifierProvider<TrashController, List<TrashedTask>>(TrashController.new);
