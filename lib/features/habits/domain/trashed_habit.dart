import '../../../core/trash.dart';
import 'habit.dart';

/// A deleted habit (with its whole check-in history) waiting in the trash.
class TrashedHabit {
  final Habit habit;
  final DateTime deletedAt;
  const TrashedHabit({required this.habit, required this.deletedAt});

  /// Days before this habit is permanently removed (never negative).
  int daysLeft(DateTime now) {
    final left = kTrashRetentionDays - now.difference(deletedAt).inDays;
    return left < 0 ? 0 : left;
  }

  Map<String, dynamic> toJson() =>
      {'habit': habit.toJson(), 'deletedAt': deletedAt.toIso8601String()};

  factory TrashedHabit.fromJson(Map<String, dynamic> j) => TrashedHabit(
        habit: Habit.fromJson(j['habit'] as Map<String, dynamic>),
        deletedAt: DateTime.parse(j['deletedAt'] as String),
      );
}

List<TrashedHabit> habitsWithoutExpired(List<TrashedHabit> items, DateTime now) => items
    .where((i) => now.difference(i.deletedAt).inDays < kTrashRetentionDays)
    .toList();
