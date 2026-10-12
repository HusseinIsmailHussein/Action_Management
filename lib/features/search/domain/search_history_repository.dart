abstract class SearchHistoryRepository {
  Future<List<String>> load();
  Future<void> save(List<String> queries);
}
