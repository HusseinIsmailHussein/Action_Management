import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_search_history_repository.dart';
import '../domain/recent_searches.dart';
import '../domain/search_history_repository.dart';

final searchHistoryRepositoryProvider =
    Provider<SearchHistoryRepository>((ref) => LocalSearchHistoryRepository());

/// The last few searches, newest first (saved on the device).
class RecentSearchesController extends AsyncNotifier<List<String>> {
  SearchHistoryRepository get _repo => ref.read(searchHistoryRepositoryProvider);

  @override
  Future<List<String>> build() => _repo.load();

  Future<void> _set(List<String> next) async {
    state = AsyncData(next);
    await _repo.save(next);
  }

  Future<void> add(String query) async {
    final current = await future; // wait for the stored list to load first
    final next = withRecent(current, query);
    if (next.length == current.length && next.isNotEmpty && next.first == current.first) {
      return; // already the most recent one
    }
    await _set(next);
  }

  Future<void> remove(String query) async {
    final current = await future;
    await _set(current.where((q) => q != query).toList());
  }

  Future<void> clear() => _set(<String>[]);
}

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesController, List<String>>(
        RecentSearchesController.new);
