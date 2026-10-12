import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/habit_trash_repository.dart';
import '../domain/trashed_habit.dart';

class LocalHabitTrashRepository implements HabitTrashRepository {
  static const _key = 'habit_trash_v1';

  @override
  Future<List<TrashedHabit>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => TrashedHabit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> save(List<TrashedHabit> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((i) => i.toJson()).toList()));
  }
}
