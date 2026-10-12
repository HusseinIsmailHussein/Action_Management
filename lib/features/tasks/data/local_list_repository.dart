import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/list_repository.dart';
import '../domain/task_list.dart';

class LocalListRepository implements ListRepository {
  static const _key = 'lists_v1';

  @override
  Future<List<TaskList>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [TaskList.inbox()];
    return (jsonDecode(raw) as List)
        .map((e) => TaskList.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> save(List<TaskList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(lists.map((l) => l.toJson()).toList()));
  }
}
