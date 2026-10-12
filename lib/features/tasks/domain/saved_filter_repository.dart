import 'saved_filter.dart';

abstract class SavedFilterRepository {
  Future<List<SavedFilter>> load();
  Future<void> save(List<SavedFilter> filters);
}
