import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../application/habit_controller.dart';
import '../domain/habit.dart';
import '../domain/habit_stats.dart';
import 'habit_detail_page.dart';
import 'habit_icons.dart';

/// A habit for today: check button, streak, and a 7-day strip.
class HabitCard extends ConsumerWidget {
  final Habit habit;
  final bool scheduledToday;
  const HabitCard({super.key, required this.habit, this.scheduledToday = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(habitControllerProvider.notifier);
    final now = DateTime.now();
    final color = Color(habit.color);
    final count = habit.countOn(now);
    final done = habit.doneOn(now);
    final streak = currentStreak(habit, now);

    final card = AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => HabitDetailPage(habitId: habit.id))),
      child: Column(children: [
        Row(children: [
          IconBadge(icon: habitIcon(habit.iconIndex), color: color, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(habit.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (streak > 0) _StreakPill(streak: streak),
                if (habit.reminderAt != null) _ReminderLabel(minutes: habit.reminderAt!),
                if (!scheduledToday)
                  Text('Not today',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant))
                else if (habit.target > 1)
                  Text('$count/${habit.target} today',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ]),
          ),
          if (scheduledToday)
            _CheckButton(
              color: color,
              done: done,
              count: count,
              target: habit.target,
              onTap: () => ctrl.tap(habit.id, now),
              onLongPress: () => ctrl.clearDay(habit.id, now),
            ),
        ]),
        const SizedBox(height: 12),
        _WeekStrip(habit: habit, color: color),
      ]),
    );

    return scheduledToday ? card : Opacity(opacity: 0.65, child: card);
  }
}

class _StreakPill extends StatelessWidget {
  final int streak;
  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 14, color: AppColors.orange),
          const SizedBox(width: 3),
          Text('$streak ${streak == 1 ? 'day' : 'days'}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
        ]),
      );
}

class _CheckButton extends StatelessWidget {
  final Color color;
  final bool done;
  final int count;
  final int target;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _CheckButton({
    required this.color,
    required this.done,
    required this.count,
    required this.target,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Stack(alignment: Alignment.center, children: [
            if (target > 1)
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  value: (count / target).clamp(0.0, 1.0).toDouble(),
                  strokeWidth: 4,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? color : color.withValues(alpha: 0.12),
              ),
              child: Icon(
                done
                    ? Icons.check_rounded
                    : (target > 1 ? Icons.add_rounded : Icons.check_rounded),
                color: done ? Colors.white : color,
              ),
            ),
          ]),
        ),
      );
}

/// Last 7 days; tap a scheduled day to toggle it.
class _WeekStrip extends ConsumerWidget {
  final Habit habit;
  final Color color;
  const _WeekStrip({required this.habit, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(habitControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Row(children: [
      for (var i = 0; i < 7; i++)
        Expanded(
          child: Builder(builder: (context) {
            final day = DateTime(now.year, now.month, now.day - 6 + i);
            final scheduled = habit.isScheduled(day);
            final done = habit.doneOn(day);
            final partial = !done && habit.countOn(day) > 0;
            final isToday = i == 6;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: scheduled ? () => ctrl.toggleDay(habit.id, day) : null,
              child: Column(children: [
                Text(
                  DateFormat.E().format(day).substring(0, 1),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? color
                        : partial
                            ? color.withValues(alpha: 0.35)
                            : scheduled
                                ? scheme.outlineVariant.withValues(alpha: 0.4)
                                : Colors.transparent,
                    border: isToday ? Border.all(color: color, width: 2) : null,
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : (!scheduled
                          ? Center(
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: scheme.outlineVariant,
                                    shape: BoxShape.circle),
                              ),
                            )
                          : null),
                ),
              ]),
            );
          }),
        ),
    ]);
  }
}

class _ReminderLabel extends StatelessWidget {
  final int minutes;
  const _ReminderLabel({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.notifications_active_rounded, size: 13, color: muted),
      const SizedBox(width: 3),
      Text(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context),
          style: TextStyle(fontSize: 12, color: muted)),
    ]);
  }
}
