import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/date_utils.dart';
import '../../focus/application/focus_providers.dart';
import '../../habits/application/habit_controller.dart';
import '../../tasks/application/task_controller.dart';
import '../data/share_plus_review_sharer.dart';
import '../domain/review.dart';
import '../domain/review_sharer.dart';

/// Which week or month the review shows. Starts on the current week.
class ReviewPeriodController extends Notifier<ReviewPeriod> {
  @override
  ReviewPeriod build() =>
      ReviewPeriod.week(DateTime.now(), weekStart: kFirstWeekday);

  void showMonth(bool month) {
    final now = DateTime.now();
    state = month
        ? ReviewPeriod.month(now, weekStart: kFirstWeekday)
        : ReviewPeriod.week(now, weekStart: kFirstWeekday);
  }

  /// Move to an earlier (negative) or later period.
  void shift(int delta) => state = state.shifted(delta);
}

final reviewPeriodProvider =
    NotifierProvider<ReviewPeriodController, ReviewPeriod>(ReviewPeriodController.new);

final reviewProvider = Provider<ReviewData>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final habits = ref.watch(habitControllerProvider).value ?? [];
  final sessions = ref.watch(focusSessionsProvider).value ?? [];
  final period = ref.watch(reviewPeriodProvider);
  return buildReview(
    tasks: tasks,
    habits: habits,
    sessions: sessions,
    period: period,
    now: DateTime.now(),
  );
});

final reviewSharerProvider = Provider<ReviewSharer>((ref) => SharePlusReviewSharer());
