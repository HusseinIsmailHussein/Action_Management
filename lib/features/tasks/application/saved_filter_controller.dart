import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/local_saved_filter_repository.dart';
import '../domain/saved_filter.dart';
import '../domain/saved_filter_repository.dart';
import '../domain/task_filter.dart';

final savedFilterRepositoryProvider =
    Provider<SavedFilterRepository>((ref) => LocalSavedFilterRepository());

class SavedFilterController extends AsyncNotifier<List<SavedFilter>> {
  SavedFilterRepository get _repo => ref.read(savedFilterRepositoryProvider);
  List<SavedFilter> get _current => state.value ?? [];

  @override
  Future<List<SavedFilter>> build() => _repo.load();

  Future<void> _commit(List<SavedFilter> next) async {
    state = AsyncData(next);
    await _repo.save(next);
  }

  Future<SavedFilter> add(String name, TaskFilter filter) async {
    final f = SavedFilter(id: const Uuid().v4(), name: name.trim(), filter: filter);
    await _commit([..._current, f]);
    return f;
  }

  Future<void> rename(String id, String name) => _commit([
        for (final f in _current) f.id == id ? f.copyWith(name: name.trim()) : f
      ]);

  Future<void> updateFilter(String id, TaskFilter filter) => _commit([
        for (final f in _current) f.id == id ? f.copyWith(filter: filter) : f
      ]);

  Future<void> remove(String id) =>
      _commit(_current.where((f) => f.id != id).toList());

  /// Puts a deleted filter back (used by "Undo").
  Future<void> restore(SavedFilter filter) =>
      _commit([..._current.where((f) => f.id != filter.id), filter]);
}

final savedFilterControllerProvider =
    AsyncNotifierProvider<SavedFilterController, List<SavedFilter>>(
        SavedFilterController.new);

final savedFilterByIdProvider = Provider.family<SavedFilter?, String>((ref, id) {
  final all = ref.watch(savedFilterControllerProvider).value ?? [];
  for (final f in all) {
    if (f.id == id) return f;
  }
  return null;
});
