import 'trashed_task.dart';

abstract class TrashRepository {
  Future<List<TrashedTask>> load();
  Future<void> save(List<TrashedTask> items);
}
