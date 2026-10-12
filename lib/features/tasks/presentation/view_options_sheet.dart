import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/view_options_controller.dart';
import '../domain/view_options.dart';

/// Choose how the task list is sorted and grouped.
Future<void> showViewOptionsSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ViewOptionsSheet(),
    );

class _ViewOptionsSheet extends ConsumerWidget {
  const _ViewOptionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(viewOptionsProvider).value ?? const ViewOptions();
    final ctrl = ref.read(viewOptionsProvider.notifier);
    final label = Theme.of(context).textTheme.labelLarge;
    final fixedOrder = options.sort == SortBy.smart || options.sort == SortBy.manual;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Sort & group',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                  onPressed: options.isDefault ? null : ctrl.reset,
                  child: const Text('Reset')),
            ]),
            const SizedBox(height: 8),
            Text('Sort by', style: label),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final s in SortBy.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: options.sort == s,
                  onSelected: (_) => ctrl.setSort(s),
                ),
            ]),
            if (options.sort == SortBy.manual)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Long-press a task and drag it to reorder. Dragging works when Group by is None.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reverse order'),
              value: options.reversed && !fixedOrder,
              onChanged: fixedOrder ? null : ctrl.setReversed,
            ),
            const SizedBox(height: 4),
            Text('Group by', style: label),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final g in GroupBy.values)
                ChoiceChip(
                  label: Text(g.label),
                  selected: options.group == g,
                  onSelected: (_) => ctrl.setGroup(g),
                ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Pinned tasks stay on top (except in Manual order) and finished tasks stay at the bottom.',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
