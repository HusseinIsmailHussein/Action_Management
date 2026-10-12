import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../habits/application/habit_controller.dart';
import '../../tasks/application/task_controller.dart';
import '../domain/activity.dart';

/// Days with finished tasks / met habit goals within the last N days.
final activityDaysProvider = Provider.family<List<ActivityDay>, int>((ref, days) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final habits = ref.watch(habitControllerProvider).value ?? [];
  return buildActivity(tasks, habits, DateTime.now(), days: days);
});

/// Tasks completed per day for the last 14 days (oldest first).
final completionChartProvider = Provider<List<(DateTime, int)>>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  return completedPerDay(tasks, DateTime.now(), days: 14);
});

final completedTodayProvider = Provider<int>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final now = DateTime.now();
  return completedBetween(tasks, now, now);
});

/// Today and the six days before it.
final completedThisWeekProvider = Provider<int>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final now = DateTime.now();
  return completedBetween(tasks, DateTime(now.year, now.month, now.day - 6), now);
});

final completedThisMonthProvider = Provider<int>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final now = DateTime.now();
  return completedBetween(tasks, DateTime(now.year, now.month, 1), now);
});
