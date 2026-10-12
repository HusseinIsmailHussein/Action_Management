import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_view_options_repository.dart';
import '../domain/view_options.dart';
import '../domain/view_options_repository.dart';

final viewOptionsRepositoryProvider =
    Provider<ViewOptionsRepository>((ref) => LocalViewOptionsRepository());

class ViewOptionsController extends AsyncNotifier<ViewOptions> {
  ViewOptionsRepository get _repo => ref.read(viewOptionsRepositoryProvider);
  ViewOptions get _current => state.value ?? const ViewOptions();

  @override
  Future<ViewOptions> build() => _repo.load();

  Future<void> _set(ViewOptions o) async {
    state = AsyncData(o);
    await _repo.save(o);
  }

  Future<void> setSort(SortBy s) => _set(_current.copyWith(sort: s));
  Future<void> setReversed(bool v) => _set(_current.copyWith(reversed: v));
  Future<void> setGroup(GroupBy g) => _set(_current.copyWith(group: g));
  Future<void> reset() => _set(const ViewOptions());
}

final viewOptionsProvider =
    AsyncNotifierProvider<ViewOptionsController, ViewOptions>(ViewOptionsController.new);
