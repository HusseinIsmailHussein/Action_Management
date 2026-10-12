import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/search_launcher.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_banner.dart';
import '../../../core/widgets/gradient_fab.dart';
import '../application/collapsed_groups.dart';
import '../application/filter_controller.dart';
import '../application/grouped_tasks.dart';
import '../application/view_options_controller.dart';
import '../domain/task_grouping.dart';
import '../domain/view_options.dart';
import 'view_options_sheet.dart';
import '../application/list_controller.dart';
import '../application/saved_filter_controller.dart';
import '../application/task_controller.dart';
import '../domain/task.dart';
import '../domain/task_filter.dart';
import 'add_task_sheet.dart';
import 'app_drawer.dart';
import 'filter_sheet.dart';
import 'task_tile.dart';
import 'view_style.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  (IconData, String, String) _empty(ViewSelection sel, bool filtered) {
    if (filtered || sel.filterId != null) {
      return (Icons.filter_alt_off_rounded, 'No matches', 'No tasks match this filter.');
    }
    if (sel.smart == SmartView.today) {
      return (Icons.wb_sunny_rounded, 'All clear for today',
          'Nothing due. Tap + to plan something.');
    }
    if (sel.smart == SmartView.completed) {
      return (Icons.task_alt_rounded, 'Nothing completed yet',
          'Finished tasks will show up here.');
    }
    return (Icons.inbox_rounded, 'Nothing here yet', 'Tap + to add a task.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedViewProvider);
    final tasks = ref.watch(visibleTasksProvider);
    final filter = ref.watch(taskFilterProvider);
    final options = ref.watch(viewOptionsProvider).value ?? const ViewOptions();
    final groups = ref.watch(groupedTasksProvider);
    final canReorder = options.sort == SortBy.manual && options.group == GroupBy.none;
    final collapsed = ref.watch(collapsedGroupsProvider);
    final rows = <Object>[
      for (final g in groups) ...[
        if (g.title.isNotEmpty) g,
        if (!collapsed.contains(g.key)) ...g.tasks,
      ]
    ];
    final loading = ref.watch(taskControllerProvider).isLoading;
    final list = sel.listId != null ? ref.watch(listByIdProvider(sel.listId!)) : null;
    final style = styleFor(sel, list: list);

    final title = sel.listId != null
        ? (list?.name ?? 'Inbox')
        : sel.tag != null
            ? '#${sel.tag}'
            : sel.filterId != null
                ? (ref.watch(savedFilterByIdProvider(sel.filterId!))?.name ?? 'Filter')
                : sel.smart!.label;

    final open = tasks.where((t) => !t.done).length;
    final isToday = sel.smart == SmartView.today;
    final subtitle = isToday
        ? DateFormat.MMMMEEEEd().format(DateTime.now())
        : '$open open ${open == 1 ? 'task' : 'tasks'}';
    final empty = _empty(sel, filter.isActive);

    return Scaffold(
      drawer: AppDrawer(hostContext: context),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => ref.read(openSearchProvider)(context),
          ),
          IconButton(
            tooltip: 'Sort & group',
            icon: Badge(
              isLabelVisible: !options.isDefault,
              smallSize: 8,
              child: const Icon(Icons.sort_rounded),
            ),
            onPressed: () => showViewOptionsSheet(context),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: filter.isActive,
              smallSize: 8,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: () => showFilterSheet(context),
          ),
        ],
      ),
      body: Column(children: [
        if (filter.isActive) _ActiveFilters(filter: filter),
        Expanded(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: GradientBanner(
                color: style.color,
                icon: style.icon,
                title: title,
                subtitle: subtitle,
                progress: isToday ? ref.watch(todayProgressProvider) : null,
              ),
            ),
            if (loading)
              const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()))
            else if (tasks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                    icon: empty.$1,
                    title: empty.$2,
                    subtitle: empty.$3,
                    color: style.color),
              )
            else
              canReorder
                  ? SliverReorderableList(
                      itemCount: tasks.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        // Open tasks come first; finished ones can't be moved.
                        final open =
                            tasks.where((t) => !t.done).map((t) => t.id).toList();
                        if (oldIndex >= open.length) return;
                        newIndex = newIndex.clamp(0, open.length - 1).toInt();
                        open.insert(newIndex, open.removeAt(oldIndex));
                        ref.read(taskControllerProvider.notifier).applyManualOrder(open);
                      },
                      itemBuilder: (_, i) {
                        final t = tasks[i];
                        return t.done
                            ? KeyedSubtree(key: ValueKey(t.id), child: TaskTile(task: t))
                            : ReorderableDelayedDragStartListener(
                                key: ValueKey(t.id),
                                index: i,
                                child: TaskTile(task: t),
                              );
                      },
                    )
                  : SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final row = rows[i];
                        return row is TaskGroup
                            ? _GroupHeader(group: row)
                            : TaskTile(task: row as TaskItem);
                      },
                    ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]),
        ),
      ]),
      floatingActionButton: GradientFab(
        color: style.color,
        onPressed: () => showAddTaskSheet(context),
      ),
    );
  }
}

/// Removable chips summarising the temporary filter.
class _ActiveFilters extends ConsumerWidget {
  final TaskFilter filter;
  const _ActiveFilters({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(taskFilterProvider.notifier);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Wrap(spacing: 8, runSpacing: 4, children: [
          for (final p in filter.priorities)
            InputChip(
                label: Text('${p.name} priority'),
                onDeleted: () => ctrl.togglePriority(p)),
          if (filter.due != null)
            InputChip(label: Text(filter.due!.label), onDeleted: () => ctrl.setDue(null)),
          for (final id in filter.listIds)
            InputChip(
                label: Text(ref.watch(listByIdProvider(id))?.name ?? 'List'),
                onDeleted: () => ctrl.toggleList(id)),
          for (final tag in filter.tags)
            InputChip(label: Text('#$tag'), onDeleted: () => ctrl.toggleTag(tag)),
        ]),
      ),
    );
  }
}

/// Section title above a group of tasks (e.g. "Overdue", "High priority").
/// Tap to collapse or expand the section.
class _GroupHeader extends ConsumerWidget {
  final TaskGroup group;
  const _GroupHeader({required this.group});

  Color _color(BuildContext context) {
    if (group.color != null) return Color(group.color!);
    return switch (group.key) {
      'overdue' || 'p3' => AppColors.red,
      'today' => AppColors.blue,
      'tomorrow' || 'p2' => AppColors.orange,
      'week' => AppColors.violet,
      'later' || 'p1' => AppColors.teal,
      'done' => AppColors.green,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _color(context);
    final collapsed = ref.watch(collapsedGroupsProvider).contains(group.key);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => ref.read(collapsedGroupsProvider.notifier).toggle(group.key),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 20, 4),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            group.title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text('${group.tasks.length}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
          const Spacer(),
          Icon(collapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
              color: muted),
        ]),
      ),
    );
  }
}
