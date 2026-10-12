import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/date_utils.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../application/habit_controller.dart';
import '../domain/habit.dart';
import '../domain/habit_stats.dart';
import 'habit_form_sheet.dart';
import 'habit_icons.dart';

class HabitDetailPage extends ConsumerStatefulWidget {
  final String habitId;
  const HabitDetailPage({super.key, required this.habitId});
  @override
  ConsumerState<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends ConsumerState<HabitDetailPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final habit = ref.watch(habitByIdProvider(widget.habitId));
    if (habit == null) return const Scaffold();
    final ctrl = ref.read(habitControllerProvider.notifier);
    final color = Color(habit.color);
    final now = DateTime.now();
    final rate = (completionRate(habit, now) * 100).round();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showHabitForm(context, existing: habit),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              ctrl.remove(habit.id);
              Navigator.pop(context);
              messenger.showSnackBar(SnackBar(
                content: const Text('Habit deleted'),
                action: SnackBarAction(label: 'Undo', onPressed: () => ctrl.restore(habit)),
              ));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          AppCard(
            child: Row(children: [
              IconBadge(icon: habitIcon(habit.iconIndex), color: color, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(habit.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${habit.frequencyLabel} · ${habit.target == 1 ? 'once' : '${habit.target}×'} a day${habit.reminderAt == null ? '' : ' · ${TimeOfDay(hour: habit.reminderAt! ~/ 60, minute: habit.reminderAt! % 60).format(context)}'}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Row(children: [
              _Stat(
                  value: '${currentStreak(habit, now)}',
                  label: 'Current\nstreak',
                  color: AppColors.orange),
              _Stat(
                  value: '${bestStreak(habit, now)}',
                  label: 'Best\nstreak',
                  color: AppColors.pink),
              _Stat(
                  value: '${totalCompletedDays(habit)}',
                  label: 'Days\ncompleted',
                  color: AppColors.green),
              _Stat(value: '$rate%', label: 'Last\n30 days', color: color),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(children: [
              Row(children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _shift(-1)),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _shift(1)),
              ]),
              const SizedBox(height: 4),
              _MonthHeatmap(
                habit: habit,
                month: _month,
                onToggle: (day) => ctrl.toggleDay(habit.id, day),
              ),
              const SizedBox(height: 8),
              Text('Tap a day to mark it done or undo it.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
}

class _MonthHeatmap extends StatelessWidget {
  final Habit habit;
  final DateTime month;
  final ValueChanged<DateTime> onToggle;
  const _MonthHeatmap({required this.habit, required this.month, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(habit.color);
    final today = dateOnly(DateTime.now());
    final offset = (DateTime(month.year, month.month, 1).weekday - kFirstWeekday + 7) % 7;
    final weeks = ((offset + daysInMonth(month)) / 7).ceil();

    Widget cell(int n) {
      if (n < 1 || n > daysInMonth(month)) return const SizedBox(height: 44);
      final day = DateTime(month.year, month.month, n);
      final future = day.isAfter(today);
      final done = habit.doneOn(day);
      final partial = !done && habit.countOn(day) > 0;
      final scheduled = habit.isScheduled(day);
      final isToday = isSameDay(day, today);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: future ? null : () => onToggle(day),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? color
                    : partial
                        ? color.withValues(alpha: 0.35)
                        : (scheduled && !future
                            ? scheme.outlineVariant.withValues(alpha: 0.35)
                            : Colors.transparent),
                border: isToday ? Border.all(color: color, width: 2) : null,
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: done || isToday ? FontWeight.w800 : FontWeight.w500,
                  color: done
                      ? Colors.white
                      : (!scheduled || future ? scheme.onSurfaceVariant : null),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(children: [
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                DateFormat.E()
                    .format(DateTime(2024, 1, 1 + (kFirstWeekday - 1) + i))
                    .substring(0, 1),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      for (var w = 0; w < weeks; w++)
        Row(children: [
          for (var c = 0; c < 7; c++) Expanded(child: cell(w * 7 + c - offset + 1)),
        ]),
    ]);
  }
}
