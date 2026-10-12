import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/saved_filter.dart';
import '../domain/saved_filter_repository.dart';

class LocalSavedFilterRepository implements SavedFilterRepository {
  static const _key = 'filters_v1';

  @override
  Future<List<SavedFilter>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => SavedFilter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> save(List<SavedFilter> filters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(filters.map((f) => f.toJson()).toList()));
  }
}
