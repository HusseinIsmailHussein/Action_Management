import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_banner.dart';
import '../../../core/widgets/gradient_fab.dart';
import '../application/habit_controller.dart';
import 'habit_card.dart';
import 'habit_form_sheet.dart';

class HabitsPage extends ConsumerWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(habitControllerProvider).isLoading;
    final groups = ref.watch(habitGroupsProvider);
    final progress = ref.watch(habitProgressProvider);
    final isEmpty = groups.today.isEmpty && groups.other.isEmpty;

    return Scaffold(
      appBar: AppBar(),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: GradientBanner(
            color: AppColors.pink,
            icon: Icons.local_fire_department_rounded,
            title: 'Habits',
            subtitle: DateFormat.MMMMEEEEd().format(DateTime.now()),
            progress: progress,
          ),
        ),
        if (loading)
          const SliverFillRemaining(
              hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
        else if (isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.local_fire_department_rounded,
              title: 'Build a habit',
              subtitle: 'Tap + to track something you want to do regularly.',
              color: AppColors.pink,
            ),
          )
        else
          SliverList(
            delegate: SliverChildListDelegate([
              for (final h in groups.today) HabitCard(habit: h),
              if (groups.today.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No habits scheduled today.')),
                ),
              if (groups.other.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                  child: Text(
                    'NOT SCHEDULED TODAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final h in groups.other) HabitCard(habit: h, scheduledToday: false),
              ],
            ]),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
      floatingActionButton: GradientFab(
        color: AppColors.pink,
        onPressed: () => showHabitForm(context),
      ),
    );
  }
}
