import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/search_launcher.dart';
import '../../../core/tab_request.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_banner.dart';
import '../../../core/widgets/gradient_fab.dart';
import '../../focus/application/focus_providers.dart';
import '../../focus/application/focus_timer_controller.dart';
import '../../focus/domain/pomodoro.dart';
import '../../focus/presentation/focus_stats_card.dart';
import '../../habits/application/habit_controller.dart';
import '../../review/presentation/review_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../habits/domain/habit.dart';
import '../../habits/presentation/habit_detail_page.dart';
import '../../habits/presentation/habit_icons.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/presentation/add_task_sheet.dart';
import '../../tasks/presentation/task_tile.dart';
import '../../archive/application/activity_providers.dart';
import '../../archive/presentation/archive_page.dart';
import '../application/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static const _maxTasks = 5;

  (String, IconData) _greeting(DateTime now) {
    if (now.hour < 12) return ('Good morning', Icons.wb_sunny_rounded);
    if (now.hour < 18) return ('Good afternoon', Icons.wb_twilight_rounded);
    return ('Good evening', Icons.nights_stay_rounded);
  }

  void _openTodayTasks(WidgetRef ref) {
    ref
        .read(selectedViewProvider.notifier)
        .select(const ViewSelection.smart(SmartView.today));
    ref.read(tabRequestProvider.notifier).open(AppTabs.tasks);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final (greeting, greetingIcon) = _greeting(now);
    final progress = ref.watch(dayProgressProvider);
    final tasksProgress = ref.watch(todayProgressProvider);
    final habitsProgress = ref.watch(habitProgressProvider);
    final focusToday = ref.watch(focusTodayProvider);
    final todayTasks = ref.watch(todayTasksProvider);
    final overdue = ref.watch(overdueCountProvider);
    final weekDone = ref.watch(completedThisWeekProvider);
    final allDone = progress.$2 > 0 && progress.$1 >= progress.$2;
    void openTab(String label) => ref.read(tabRequestProvider.notifier).open(label);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => ref.read(openSearchProvider)(context),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          GradientBanner(
            color: AppAccent.of(context),
            icon: greetingIcon,
            title: greeting,
            subtitle: allDone
                ? "You're all caught up today"
                : DateFormat.MMMMEEEEd().format(now),
            progress: progress,
          ),

          // ---- at-a-glance stats ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _StatCard(
                icon: Icons.check_circle_rounded,
                color: AppColors.blue,
                value: '${tasksProgress.$1}/${tasksProgress.$2}',
                label: 'Tasks today',
                onTap: () => _openTodayTasks(ref),
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.pink,
                value: '${habitsProgress.$1}/${habitsProgress.$2}',
                label: 'Habits',
                onTap: () => openTab(AppTabs.habits),
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.timer_rounded,
                color: AppColors.violet,
                value: formatFocus(focusToday.$1),
                label: 'Focused',
                onTap: () => openTab(AppTabs.focus),
              ),
            ]),
          ),

          // ---- up next ----
          _SectionHeader(
            title: 'Up next',
            actionLabel: 'See all',
            onAction: () => _openTodayTasks(ref),
          ),
          if (overdue > 0)
            AppCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              onTap: () => _openTodayTasks(ref),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('$overdue overdue ${overdue == 1 ? 'task' : 'tasks'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.red)),
                ),
                const Text('Review'),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          if (todayTasks.isEmpty)
            const _EmptyCard(
              icon: Icons.wb_sunny_rounded,
              color: AppColors.orange,
              text: 'Nothing due today. Tap + to plan something.',
            )
          else ...[
            for (final t in todayTasks.take(_maxTasks)) TaskTile(task: t),
            if (todayTasks.length > _maxTasks)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TextButton(
                    onPressed: () => _openTodayTasks(ref),
                    child: Text('+${todayTasks.length - _maxTasks} more'),
                  ),
                ),
              ),
          ],

          // ---- habits ----
          _SectionHeader(
            title: 'Habits',
            actionLabel: 'Open',
            onAction: () => openTab(AppTabs.habits),
          ),
          const _HabitBubbles(),

          // ---- focus ----
          const _SectionHeader(title: 'Focus'),
          _FocusCard(
            todaySeconds: focusToday.$1,
            sessions: focusToday.$2,
            onOpen: () => openTab(AppTabs.focus),
          ),

          // ---- history ----
          const _SectionHeader(title: 'Activity'),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ArchivePage())),
            child: Row(children: [
              const IconBadge(icon: Icons.history_rounded, color: AppColors.teal),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Completed history',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '$weekDone ${weekDone == 1 ? 'task' : 'tasks'} finished this week',
                    style: TextStyle(
                        fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
          const SizedBox(height: 8),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ReviewPage())),
            child: Row(children: [
              const IconBadge(icon: Icons.insights_rounded, color: AppColors.violet),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Weekly & monthly review',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    'See how it went and plan what\'s next',
                    style: TextStyle(
                        fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ],
      ),
      floatingActionButton: GradientFab(onPressed: () => showAddTaskSheet(context)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 12, 6),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ]),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          onTap: onTap,
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

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _EmptyCard({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => AppCard(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          IconBadge(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(child: Text(text)),
        ]),
      );
}

/// Today's habits as tappable rings; tap to check in, long-press for details.
class _HabitBubbles extends ConsumerWidget {
  const _HabitBubbles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitGroupsProvider).today;
    final ctrl = ref.read(habitControllerProvider.notifier);
    final now = DateTime.now();

    if (habits.isEmpty) {
      return const _EmptyCard(
        icon: Icons.local_fire_department_rounded,
        color: AppColors.pink,
        text: 'No habits scheduled today.',
      );
    }

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: habits.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final h = habits[i];
          return _HabitBubble(
            habit: h,
            now: now,
            onTap: () => ctrl.tap(h.id, now),
            onLongPress: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => HabitDetailPage(habitId: h.id))),
          );
        },
      ),
    );
  }
}

class _HabitBubble extends StatelessWidget {
  final Habit habit;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _HabitBubble({
    required this.habit,
    required this.now,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.color);
    final done = habit.doneOn(now);
    final fraction = (habit.countOn(now) / habit.target).clamp(0.0, 1.0).toDouble();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 72,
        child: Column(children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 4,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : color.withValues(alpha: 0.12),
                ),
                child: Icon(done ? Icons.check_rounded : habitIcon(habit.iconIndex),
                    color: done ? Colors.white : color),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(habit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Today's focus time, or the live timer when one is running.
class _FocusCard extends ConsumerWidget {
  final int todaySeconds;
  final int sessions;
  final VoidCallback onOpen;
  const _FocusCard({
    required this.todaySeconds,
    required this.sessions,
    required this.onOpen,
  });

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(focusTimerProvider);
    final active = timer.status != TimerStatus.idle;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.violet.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              active
                  ? '${timer.phase.label}${timer.status == TimerStatus.paused ? ' (paused)' : ''}'
                  : 'Focused today',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              active ? _mmss(timer.remainingSeconds) : formatFocus(todaySeconds),
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
            ),
            if (!active)
              Text('$sessions ${sessions == 1 ? 'session' : 'sessions'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          ]),
        ),
        FilledButton(
          onPressed: onOpen,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.violet,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          child: Text(active ? 'Open' : 'Start focus'),
        ),
      ]),
    );
  }
}
