import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/local_list_repository.dart';
import '../domain/list_repository.dart';
import '../domain/task_list.dart';
import 'task_controller.dart';

final listRepositoryProvider =
    Provider<ListRepository>((ref) => LocalListRepository());

class ListController extends AsyncNotifier<List<TaskList>> {
  ListRepository get _repo => ref.read(listRepositoryProvider);
  List<TaskList> get _current => state.value ?? [TaskList.inbox()];

  @override
  Future<List<TaskList>> build() async {
    final lists = await _repo.load();
    if (lists.every((l) => l.id != inboxId)) return [TaskList.inbox(), ...lists];
    return lists;
  }

  Future<void> _commit(List<TaskList> next) async {
    state = AsyncData(next);
    await _repo.save(next);
  }

  Future<void> add(String name, int color) => _commit([
        ..._current,
        TaskList(id: const Uuid().v4(), name: name.trim(), color: color),
      ]);

  Future<void> edit(String id, {String? name, int? color}) => _commit([
        for (final l in _current)
          l.id == id ? l.copyWith(name: name?.trim(), color: color) : l
      ]);

  /// Deleting a list moves its tasks to Inbox (nothing is lost).
  Future<void> remove(String id) async {
    if (id == inboxId) return;
    await ref.read(taskControllerProvider.notifier).reassignList(id, inboxId);
    if (ref.read(selectedViewProvider).listId == id) {
      ref.read(selectedViewProvider.notifier).select(const ViewSelection.list(inboxId));
    }
    await _commit(_current.where((l) => l.id != id).toList());
  }

  /// Brings a deleted list back and moves [taskIds] (the tasks it held) into it again.
  Future<void> restore(TaskList list, List<String> taskIds) async {
    await _commit([..._current.where((l) => l.id != list.id), list]);
    await ref.read(taskControllerProvider.notifier).assignList(taskIds, list.id);
  }
}

final listControllerProvider =
    AsyncNotifierProvider<ListController, List<TaskList>>(ListController.new);

final listByIdProvider = Provider.family<TaskList?, String>((ref, id) {
  final lists = ref.watch(listControllerProvider).value ?? [];
  for (final l in lists) {
    if (l.id == id) return l;
  }
  return null;
});
