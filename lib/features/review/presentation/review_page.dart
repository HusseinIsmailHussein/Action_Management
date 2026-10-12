import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/date_utils.dart';
import '../../../core/tab_request.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_banner.dart';
import '../../focus/presentation/focus_stats_card.dart';
import '../../habits/presentation/habit_icons.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_tile.dart';
import '../application/review_providers.dart';
import '../domain/review.dart';
import '../domain/review_text.dart';

/// Weekly / monthly review: what got done, what slipped, how habits and focus
/// went, and what's coming next.
class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  String _label(ReviewPeriod p) => p.isMonth
      ? DateFormat.yMMMM().format(p.start)
      : '${DateFormat.MMMd().format(p.start)} – ${DateFormat.MMMd().format(p.end)}';

  /// Share the review as text; where sharing isn't available, copy it instead.
  Future<void> _export(BuildContext context, WidgetRef ref, ReviewData data,
      {required bool share}) async {
    final text = formatReviewText(
      data,
      titleOf: (id) => ref.read(taskByIdProvider(id))?.title ?? 'Deleted task',
    );
    final messenger = ScaffoldMessenger.of(context);
    if (share) {
      try {
        await ref
            .read(reviewSharerProvider)
            .shareText(subject: reviewHeading(data.period), text: text);
        return;
      } catch (_) {
        // fall through to the clipboard
      }
    }
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(
      content: Text(share
          ? "Sharing isn't available here. Review copied to the clipboard."
          : 'Review copied to the clipboard.'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reviewProvider);
    final period = data.period;
    final ctrl = ref.read(reviewPeriodProvider.notifier);
    final now = DateTime.now();
    final canGoNext = !period.shifted(1).isInFuture(now);
    final unit = period.isMonth ? 'month' : 'week';
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final completedCount = data.completed.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (share) => _export(context, ref, data, share: share),
            itemBuilder: (_) => const [
              PopupMenuItem(value: true, child: Text('Share summary')),
              PopupMenuItem(value: false, child: Text('Copy as text')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ---- period picker ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Week')),
                  ButtonSegment(value: true, label: Text('Month')),
                ],
                selected: {period.isMonth},
                onSelectionChanged: (s) => ctrl.showMonth(s.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => ctrl.shift(-1)),
              Expanded(
                child: Center(
                  child: Text(
                    period.contains(now) ? 'This $unit' : _label(period),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: canGoNext ? () => ctrl.shift(1) : null),
            ]),
          ),

          // ---- headline ----
          GradientBanner(
            color: AppAccent.of(context),
            icon: Icons.insights_rounded,
            title: _label(period),
            subtitle: '$completedCount ${completedCount == 1 ? 'task' : 'tasks'} completed',
            progress: data.dueCount == 0 ? null : (data.dueDoneCount, data.dueCount),
          ),

          // ---- key numbers ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              Row(children: [
                _StatCard(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.green,
                  value: '$completedCount',
                  label: 'Completed',
                ),
                const SizedBox(width: 10),
                _StatCard(
                  icon: Icons.flag_rounded,
                  color: AppColors.blue,
                  value: data.completionRate == null
                      ? '-'
                      : '${(data.completionRate! * 100).round()}%',
                  label: 'Of due tasks done',
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.pink,
                  value: data.habitRate == null
                      ? '-'
                      : '${(data.habitRate! * 100).round()}%',
                  label: 'Habit goals met',
                ),
                const SizedBox(width: 10),
                _StatCard(
                  icon: Icons.timer_rounded,
                  color: AppColors.violet,
                  value: formatFocus(data.focusSeconds),
                  label: 'Focused',
                ),
              ]),
            ]),
          ),

          // ---- chart ----
          _Section(
            title: 'Completed per day',
            child: _Bars(data: data.perDay, month: period.isMonth),
          ),

          // ---- wins ----
          _Section(
            title: 'Wins',
            child: completedCount == 0
                ? Text('Nothing completed in this $unit yet.', style: TextStyle(color: muted))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (data.bestDay != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Best day: ${DateFormat.MMMEd().format(data.bestDay!.$1)} with '
                          '${data.bestDay!.$2} ${data.bestDay!.$2 == 1 ? 'task' : 'tasks'}.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    for (final t in data.completed.take(5)) _TaskLine(task: t),
                    if (completedCount > 5)
                      Text('+${completedCount - 5} more', style: TextStyle(color: muted)),
                  ]),
          ),

          // ---- slipped ----
          _Section(
            title: 'Slipped',
            subtitle: data.slipped.isEmpty ? null : '${data.slipped.length} due but not done',
            child: data.slipped.isEmpty
                ? Text('Nothing slipped. Nice work!', style: TextStyle(color: muted))
                : Column(children: [
                    for (final t in data.slipped.take(8))
                      _TaskLine(task: t, trailing: _RescheduleMenu(task: t)),
                    if (data.slipped.length > 8)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('+${data.slipped.length - 8} more',
                            style: TextStyle(color: muted)),
                      ),
                  ]),
          ),

          // ---- habits ----
          _Section(
            title: 'Habits',
            child: data.habits.isEmpty
                ? Text('No habit days in this $unit.', style: TextStyle(color: muted))
                : Column(children: [
                    for (final h in data.habits) _HabitLine(review: h),
                  ]),
          ),

          // ---- focus ----
          _Section(
            title: 'Focus',
            child: data.focusSessions == 0
                ? Text('No focus sessions in this $unit.', style: TextStyle(color: muted))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${formatFocus(data.focusSeconds)} across ${data.focusSessions} '
                      '${data.focusSessions == 1 ? 'session' : 'sessions'}.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (data.focusByTask.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Most focused tasks', style: TextStyle(fontSize: 12, color: muted)),
                      for (final e in data.focusByTask)
                        _FocusTaskLine(taskId: e.$1, seconds: e.$2),
                    ],
                  ]),
          ),

          // ---- looking ahead ----
          _Section(
            title: 'Next $unit',
            subtitle: data.upcoming.isEmpty ? null : '${data.upcoming.length} planned',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (data.upcoming.isEmpty)
                Text('Nothing planned yet.', style: TextStyle(color: muted))
              else
                for (final t in data.upcoming.take(3)) _TaskLine(task: t, showDue: true),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range_rounded),
                label: const Text('Open Upcoming'),
                onPressed: () {
                  ref
                      .read(selectedViewProvider.notifier)
                      .select(const ViewSelection.smart(SmartView.upcoming));
                  ref.read(tabRequestProvider.notifier).open(AppTabs.tasks);
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Section({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => AppCard(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBadge(icon: icon, color: color, size: 34),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
}

/// One line for a task: priority-colored dot, title, optional date and trailing widget.
class _TaskLine extends StatelessWidget {
  final TaskItem task;
  final Widget? trailing;
  final bool showDue;
  const _TaskLine({required this.task, this.trailing, this.showDue = false});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(Icons.circle, size: 10, color: priorityColor(task.priority)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (showDue && task.due != null)
          Text(friendlyDue(task.due!, hasTime: task.hasTime),
              style: TextStyle(fontSize: 12, color: muted))
        else if (task.due != null && trailing != null)
          Text(friendlyDue(task.due!, hasTime: false),
              style: const TextStyle(fontSize: 12, color: AppColors.red)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

enum _Move { today, tomorrow, nextWeek }

/// Quick reschedule for a slipped task.
class _RescheduleMenu extends ConsumerWidget {
  final TaskItem task;
  const _RescheduleMenu({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<_Move>(
        tooltip: 'Reschedule',
        icon: const Icon(Icons.event_repeat_rounded, size: 20),
        onSelected: (m) {
          final now = DateTime.now();
          final toMonday = (DateTime.monday - now.weekday + 7) % 7;
          final day = switch (m) {
            _Move.today => now,
            _Move.tomorrow => DateTime(now.year, now.month, now.day + 1),
            _Move.nextWeek =>
              DateTime(now.year, now.month, now.day + (toMonday == 0 ? 7 : toMonday)),
          };
          ref.read(taskControllerProvider.notifier).edit(
              task.id, (t) => t.copyWith(due: withDay(t.due, day, keepTime: t.hasTime)));
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: _Move.today, child: Text('Move to today')),
          PopupMenuItem(value: _Move.tomorrow, child: Text('Move to tomorrow')),
          PopupMenuItem(value: _Move.nextWeek, child: Text('Move to next Monday')),
        ],
      );
}

class _HabitLine extends StatelessWidget {
  final HabitReview review;
  const _HabitLine({required this.review});

  @override
  Widget build(BuildContext context) {
    final h = review.habit;
    final color = Color(h.color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        IconBadge(icon: habitIcon(h.iconIndex), color: color, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: review.rate,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Text('${review.done}/${review.scheduled}',
            style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _FocusTaskLine extends ConsumerWidget {
  final String taskId;
  final int seconds;
  const _FocusTaskLine({required this.taskId, required this.seconds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskByIdProvider(taskId));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        const Icon(Icons.timer_rounded, size: 16, color: AppColors.violet),
        const SizedBox(width: 10),
        Expanded(
          child: Text(task?.title ?? 'Deleted task',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Text(formatFocus(seconds),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.violet)),
      ]),
    );
  }
}

class _Bars extends StatelessWidget {
  final List<(DateTime, int)> data;
  final bool month;
  const _Bars({required this.data, required this.month});

  @override
  Widget build(BuildContext context) {
    final maxCount = data.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final scheme = Theme.of(context).colorScheme;
    final accent = AppAccent.of(context);
    final today = dateOnly(DateTime.now());
    const maxBar = 80.0;

    return SizedBox(
      height: maxBar + 40,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final e in data)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (!month && e.$2 > 0)
                Text('${e.$2}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Container(
                width: month ? 5 : 18,
                height: maxCount == 0
                    ? 4
                    : (maxBar * e.$2 / maxCount).clamp(4.0, maxBar).toDouble(),
                decoration: BoxDecoration(
                  color: e.$2 == 0
                      ? scheme.outlineVariant.withValues(alpha: 0.5)
                      : (isSameDay(e.$1, today) ? accent : accent.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(month ? 3 : 6),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 14,
                child: Text(
                  month
                      ? (e.$1.day == 1 || e.$1.day % 5 == 0 ? '${e.$1.day}' : '')
                      : DateFormat.E().format(e.$1).substring(0, 1),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
