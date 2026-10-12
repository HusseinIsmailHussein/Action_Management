import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/habit.dart';
import '../domain/habit_repository.dart';

class LocalHabitRepository implements HabitRepository {
  static const _key = 'habits_v1';

  @override
  Future<List<Habit>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Habit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> save(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(habits.map((h) => h.toJson()).toList()));
  }
}
