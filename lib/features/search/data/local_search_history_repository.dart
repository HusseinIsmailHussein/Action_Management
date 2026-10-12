import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/search_history_repository.dart';

class LocalSearchHistoryRepository implements SearchHistoryRepository {
  static const _key = 'recent_searches_v1';

  @override
  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw) as List);
  }

  @override
  Future<void> save(List<String> queries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(queries));
  }
}
