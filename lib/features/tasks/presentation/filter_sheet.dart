import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/filter_controller.dart';
import '../application/list_controller.dart';
import '../application/saved_filter_controller.dart';
import '../application/task_controller.dart';
import '../domain/task.dart';
import '../domain/task_filter.dart';
import 'name_dialog.dart';
import 'task_tile.dart';

/// Temporary filter over the current view; can be saved as a named filter.
Future<void> showFilterSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _OverlaySheet(),
    );

/// Edits the criteria of a saved filter (changes apply immediately).
Future<void> showSavedFilterEditor(BuildContext context, String savedFilterId) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SavedSheet(id: savedFilterId),
    );

class _OverlaySheet extends ConsumerWidget {
  const _OverlaySheet();

  Future<void> _save(BuildContext context, WidgetRef ref, TaskFilter filter) async {
    final name = await showNameDialog(context, title: 'Save filter as');
    if (name == null || name.trim().isEmpty) return;
    final saved =
        await ref.read(savedFilterControllerProvider.notifier).add(name, filter);
    ref.read(taskFilterProvider.notifier).clear();
    ref.read(selectedViewProvider.notifier).select(ViewSelection.saved(saved.id));
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    final ctrl = ref.read(taskFilterProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Filter', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: filter.isActive ? () => _save(context, ref, filter) : null,
                child: const Text('Save as...'),
              ),
              TextButton(
                  onPressed: filter.isActive ? ctrl.clear : null,
                  child: const Text('Clear')),
            ]),
            FilterEditor(filter: filter, onChanged: ctrl.set),
          ],
        ),
      ),
    );
  }
}

class _SavedSheet extends ConsumerWidget {
  final String id;
  const _SavedSheet({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedFilterByIdProvider(id));
    if (saved == null) return const SizedBox.shrink();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(saved.name, style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ]),
            if (!saved.filter.isActive)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('No criteria yet: this filter shows all open tasks.'),
              ),
            FilterEditor(
              filter: saved.filter,
              onChanged: (f) =>
                  ref.read(savedFilterControllerProvider.notifier).updateFilter(id, f),
            ),
          ],
        ),
      ),
    );
  }
}

/// The criteria pickers, shared by the temporary filter and saved filters.
class FilterEditor extends ConsumerWidget {
  final TaskFilter filter;
  final ValueChanged<TaskFilter> onChanged;
  const FilterEditor({super.key, required this.filter, required this.onChanged});

  Widget _section(BuildContext context, String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: chips),
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listControllerProvider).value ?? [];
    final tags = ref.watch(allTagsProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(context, 'Priority', [
        for (final p in Priority.values.reversed)
          FilterChip(
            avatar: Icon(Icons.flag, size: 16, color: priorityColor(p)),
            label: Text(p.name),
            selected: filter.priorities.contains(p),
            onSelected: (_) => onChanged(filter.togglePriority(p)),
          ),
      ]),
      _section(context, 'Due', [
        for (final r in DueRange.values)
          FilterChip(
            label: Text(r.label),
            selected: filter.due == r,
            onSelected: (on) => onChanged(filter.withDue(on ? r : null)),
          ),
      ]),
      if (lists.length > 1)
        _section(context, 'List (any of)', [
          for (final l in lists)
            FilterChip(
              avatar: Icon(Icons.circle, size: 12, color: Color(l.color)),
              label: Text(l.name),
              selected: filter.listIds.contains(l.id),
              onSelected: (_) => onChanged(filter.toggleList(l.id)),
            ),
        ]),
      if (tags.isNotEmpty)
        _section(context, 'Tags (any of)', [
          for (final (name, _) in tags)
            FilterChip(
              label: Text('#$name'),
              selected: filter.tags.contains(name),
              onSelected: (_) => onChanged(filter.toggleTag(name)),
            ),
        ]),
    ]);
  }
}
