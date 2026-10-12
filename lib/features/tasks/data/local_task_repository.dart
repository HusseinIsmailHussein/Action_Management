import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/task.dart';
import '../domain/task_repository.dart';

class LocalTaskRepository implements TaskRepository {
  static const _key = 'tasks_v1';

  @override
  Future<List<TaskItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> save(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }
}
