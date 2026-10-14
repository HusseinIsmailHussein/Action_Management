import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../application/filter_controller.dart';
import '../application/list_controller.dart';
import '../application/saved_filter_controller.dart';
import '../application/task_controller.dart';
import '../domain/saved_filter.dart';
import '../domain/tag.dart';
import '../domain/task.dart';
import '../domain/task_filter.dart';
import '../domain/task_list.dart';
import 'filter_sheet.dart';
import 'list_dialog.dart';
import 'name_dialog.dart';
import 'tag_dialog.dart';
import 'view_style.dart';

/// Navigation drawer: smart views, lists, saved filters, tags.
/// [hostContext] belongs to the page that owns the drawer, so dialogs
/// opened after the drawer closes still have a live context.
class AppDrawer extends ConsumerWidget {
  final BuildContext hostContext;
  const AppDrawer({super.key, required this.hostContext});

  /// "X deleted" bar with Undo. Uses the host page's context, so it keeps working
  /// after the drawer has closed (and callers must not use `ref` in [undo]).
  void _undoBar(String text, VoidCallback undo) {
    ScaffoldMessenger.of(hostContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Undo', onPressed: undo),
        ),
      );
  }

  // ---- lists ----
  void _listMenu(BuildContext context, WidgetRef ref, TaskList l) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                showListDialog(context, ref, existing: l);
              },
            ),
            if (l.id != inboxId)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete list'),
                subtitle: const Text('Its tasks move to Inbox'),
                onTap: () {
                  Navigator.pop(ctx); // close the sheet
                  final lists = ref.read(listControllerProvider.notifier);
                  final taskIds = [
                    for (final t
                        in ref.read(taskControllerProvider).value ??
                            <TaskItem>[])
                      if (t.listId == l.id) t.id,
                  ];
                  lists.remove(l.id);
                  Navigator.pop(
                    context,
                  ); // close the drawer so the Undo bar is visible
                  _undoBar(
                    'List "${l.name}" deleted',
                    () => lists.restore(l, taskIds),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---- saved filters ----
  Future<void> _newSavedFilter(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context); // close the drawer
    final name = await showNameDialog(hostContext, title: 'New filter');
    if (name == null || name.trim().isEmpty) return;
    final saved = await ref
        .read(savedFilterControllerProvider.notifier)
        .add(name, const TaskFilter());
    ref
        .read(selectedViewProvider.notifier)
        .select(ViewSelection.saved(saved.id));
    if (hostContext.mounted) showSavedFilterEditor(hostContext, saved.id);
  }

  void _filterMenu(BuildContext context, WidgetRef ref, SavedFilter f) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Edit criteria'),
              onTap: () {
                Navigator.pop(ctx);
                showSavedFilterEditor(context, f.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.pop(ctx);
                final name = await showNameDialog(
                  context,
                  title: 'Rename filter',
                  initial: f.name,
                );
                if (name != null && name.trim().isNotEmpty) {
                  ref
                      .read(savedFilterControllerProvider.notifier)
                      .rename(f.id, name);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete filter'),
              onTap: () {
                Navigator.pop(ctx);
                final filters = ref.read(
                  savedFilterControllerProvider.notifier,
                );
                filters.remove(f.id);
                _undoBar(
                  'Filter "${f.name}" deleted',
                  () => filters.restore(f),
                );
                Navigator.pop(
                  context,
                ); // close the drawer so the Undo bar is visible
                if (ref.read(selectedViewProvider).filterId == f.id) {
                  ref
                      .read(selectedViewProvider.notifier)
                      .select(const ViewSelection.smart(SmartView.today));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- tags ----
  void _tagMenu(BuildContext context, WidgetRef ref, String tag) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename tag'),
              subtitle: const Text('Renaming to an existing tag merges them'),
              onTap: () async {
                Navigator.pop(ctx);
                final raw = await showTagDialog(
                  context,
                  title: 'Rename tag',
                  initial: tag,
                );
                if (raw != null) _renameTag(ref, tag, raw);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove tag from all tasks'),
              onTap: () {
                Navigator.pop(ctx);
                _renameTag(ref, tag, '');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Renames [from] everywhere; an empty [raw] name removes the tag.
  Future<void> _renameTag(WidgetRef ref, String from, String raw) async {
    final to = normalizeTag(raw);
    if (to == from) return;
    await ref.read(taskControllerProvider.notifier).renameTag(from, to);
    if (ref.read(taskFilterProvider).tags.contains(from)) {
      ref.read(taskFilterProvider.notifier).toggleTag(from);
    }
    if (ref.read(selectedViewProvider).tag == from) {
      ref
          .read(selectedViewProvider.notifier)
          .select(
            to.isEmpty
                ? const ViewSelection.smart(SmartView.today)
                : ViewSelection.tagged(to),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedViewProvider);
    final lists = ref.watch(listControllerProvider).value ?? [TaskList.inbox()];
    final savedFilters = ref.watch(savedFilterControllerProvider).value ?? [];
    final tags = ref.watch(allTagsProvider);

    void select(ViewSelection v) {
      ref.read(selectedViewProvider.notifier).select(v);
      Navigator.pop(context);
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _DrawerHeader(),

            for (final v in SmartView.values)
              _NavTile(
                icon: smartIcon(v),
                color: smartColor(v),
                title: v.label,
                count: ref.watch(smartCountProvider(v)),
                selected: sel.smart == v,
                onTap: () => select(ViewSelection.smart(v)),
              ),

            _SectionHeader('Lists', onAdd: () => showListDialog(context, ref)),

            for (final l in lists)
              _NavTile(
                icon: Icons.folder_rounded,
                color: Color(l.color),
                title: l.name,
                count: ref.watch(listCountProvider(l.id)),
                selected: sel.listId == l.id,
                onTap: () => select(ViewSelection.list(l.id)),
                onLongPress: () => _listMenu(context, ref, l),
              ),

            // TAGS SECTION
            if (tags.isNotEmpty) ...[
              _SectionHeader(
                'Tags',
                onAdd: () async {
                  final raw = await showTagDialog(
                    context,
                    title: 'Add tag',
                    suggestions: [
                      for (final (name, _) in ref.read(allTagsProvider)) name,
                    ],
                  );
                },
              ),
              for (final (name, count) in tags)
                _NavTile(
                  icon: Icons.tag_rounded,
                  color: AppColors.pink,
                  title: name,
                  count: count,
                  selected: sel.tag == name,
                  onTap: () => select(ViewSelection.tagged(name)),
                  onLongPress: () => _tagMenu(context, ref, name),
                ),
            ],

            // FILTERS SECTION
            _SectionHeader(
              'Filters',
              onAdd: () => _newSavedFilter(context, ref),
            ),

            if (savedFilters.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Tap + or use the funnel on the task list to save one.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

            for (final f in savedFilters)
              _NavTile(
                icon: Icons.filter_alt_rounded,
                color: AppColors.teal,
                title: f.name,
                count: ref.watch(savedFilterCountProvider(f.id)),
                selected: sel.filterId == f.id,
                onTap: () => select(ViewSelection.saved(f.id)),
                onLongPress: () => _filterMenu(context, ref, f),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: AppAccent.of(context).gradient,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Action Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Get things done',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  const _SectionHeader(this.title, {this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 8, 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (onAdd != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            onPressed: onAdd,
          ),
      ],
    ),
  );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _NavTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.selected,
    required this.onTap,
    this.count,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: Material(
      color: selected ? color.withValues(alpha: 0.13) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              IconBadge(icon: icon, color: color, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : null,
                  ),
                ),
              ),
              if (count != null)
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
