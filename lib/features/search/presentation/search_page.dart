import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/date_utils.dart';
import '../../../core/tab_request.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../habits/application/habit_controller.dart';
import '../../habits/presentation/habit_detail_page.dart';
import '../../habits/presentation/habit_icons.dart';
import '../../tasks/application/list_controller.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/domain/task_list.dart';
import '../../tasks/presentation/task_detail_page.dart';
import '../../tasks/presentation/task_tile.dart';
import '../application/recent_searches_controller.dart';
import '../application/search_providers.dart';
import '../domain/search.dart';

/// Search across tasks (title, notes, subtasks, comments, tags), habits, lists,
/// tags, saved filters and the trash.
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});
  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _controller = TextEditingController();
  static const _maxTasks = 25;

  @override
  void initState() {
    super.initState();
    // Start fresh each time (the query provider outlives the page).
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(searchQueryProvider.notifier).set(''));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Save the current query to "Recent" (when a search is submitted or a result opened).
  void _remember() =>
      ref.read(recentSearchesProvider.notifier).add(ref.read(searchQueryProvider));

  void _setQuery(String q) {
    _controller.value =
        TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    ref.read(searchQueryProvider.notifier).set(q);
  }

  /// Show [view] on the Tasks tab and leave the search screen.
  void _showInTasks(ViewSelection view) {
    _remember();
    ref.read(selectedViewProvider.notifier).select(view);
    ref.read(tabRequestProvider.notifier).open(AppTabs.tasks);
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Widget _header(String title, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
        child: Row(children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final words = queryWords(query);
    final accent = AppAccent.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Search everything',
          ),
          onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
          onSubmitted: (_) => _remember(),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => _setQuery('')),
        ],
      ),
      body: words.isEmpty
          ? _Suggestions(onPick: _setQuery)
          : results.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  subtitle: 'Nothing found for "$query".',
                  color: accent,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    if (results.tasks.isNotEmpty) ...[
                      _header('Tasks', results.tasks.length),
                      for (final hit in results.tasks.take(_maxTasks))
                        _TaskHitRow(hit: hit, words: words, onOpen: _remember),
                      if (results.tasks.length > _maxTasks)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                          child: Text('+${results.tasks.length - _maxTasks} more, refine your search',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ),
                    ],
                    if (results.habits.isNotEmpty) ...[
                      _header('Habits', results.habits.length),
                      for (final h in results.habits)
                        _SimpleRow(
                          icon: habitIcon(h.iconIndex),
                          color: Color(h.color),
                          title: h.name,
                          subtitle: h.frequencyLabel,
                          words: words,
                          onTap: () {
                            _remember();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => HabitDetailPage(habitId: h.id)));
                          },
                        ),
                    ],
                    if (results.lists.isNotEmpty) ...[
                      _header('Lists', results.lists.length),
                      for (final l in results.lists)
                        _ListRow(
                          list: l,
                          words: words,
                          onTap: () => _showInTasks(ViewSelection.list(l.id)),
                        ),
                    ],
                    if (results.tags.isNotEmpty) ...[
                      _header('Tags', results.tags.length),
                      for (final (name, count) in results.tags)
                        _SimpleRow(
                          icon: Icons.tag_rounded,
                          color: AppColors.pink,
                          title: '#$name',
                          subtitle: '$count open ${count == 1 ? 'task' : 'tasks'}',
                          words: words,
                          onTap: () => _showInTasks(ViewSelection.tagged(name)),
                        ),
                    ],
                    if (results.filters.isNotEmpty) ...[
                      _header('Filters', results.filters.length),
                      for (final f in results.filters)
                        _SimpleRow(
                          icon: Icons.filter_alt_rounded,
                          color: AppColors.teal,
                          title: f.name,
                          subtitle: 'Saved filter',
                          words: words,
                          onTap: () => _showInTasks(ViewSelection.saved(f.id)),
                        ),
                    ],
                    if (results.trashedTasks.isNotEmpty || results.trashedHabits.isNotEmpty) ...[
                      _header('In trash',
                          results.trashedTasks.length + results.trashedHabits.length),
                      for (final t in results.trashedTasks)
                        _SimpleRow(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.grey,
                          title: t.task.title,
                          subtitle: 'Task · ${t.daysLeft(DateTime.now())} days left',
                          words: words,
                          trailing: IconButton(
                            tooltip: 'Restore',
                            icon: const Icon(Icons.restore_from_trash_rounded,
                                color: AppColors.green),
                            onPressed: () {
                              ref.read(taskControllerProvider.notifier).restore(t.task);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Task restored')));
                            },
                          ),
                        ),
                      for (final t in results.trashedHabits)
                        _SimpleRow(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.grey,
                          title: t.habit.name,
                          subtitle: 'Habit · ${t.daysLeft(DateTime.now())} days left',
                          words: words,
                          trailing: IconButton(
                            tooltip: 'Restore',
                            icon: const Icon(Icons.restore_from_trash_rounded,
                                color: AppColors.green),
                            onPressed: () {
                              ref.read(habitControllerProvider.notifier).restore(t.habit);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Habit restored')));
                            },
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }
}

/// Text with the matching words emphasized.
class _Highlight extends StatelessWidget {
  final String text;
  final List<String> words;
  final TextStyle? style;
  final int? maxLines;
  const _Highlight(this.text, this.words, {this.style, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    if (words.isEmpty) return Text(text, style: base, maxLines: maxLines);
    final marker = AppAccent.of(context);
    final re = RegExp(words.map(RegExp.escape).join('|'), caseSensitive: false);
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(
            fontWeight: FontWeight.w800, backgroundColor: marker.withValues(alpha: 0.18)),
      ));
      pos = m.end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

class _TaskHitRow extends StatelessWidget {
  final TaskHit hit;
  final List<String> words;
  final VoidCallback onOpen;
  const _TaskHitRow({required this.hit, required this.words, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = hit.task;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () {
        onOpen();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: t.id)));
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            t.wontDo
                ? Icons.do_not_disturb_on_rounded
                : (t.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
            size: 22,
            color: t.done ? Colors.grey : priorityColor(t.priority),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Highlight(
              t.title,
              words,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: t.done ? TextDecoration.lineThrough : null,
                color: t.done ? Colors.grey : null,
              ),
            ),
            if (hit.snippet != null) ...[
              const SizedBox(height: 2),
              _Highlight(hit.snippet!, words,
                  style: TextStyle(fontSize: 13, color: muted), maxLines: 2),
            ],
            if (t.due != null) ...[
              const SizedBox(height: 4),
              Text(friendlyDue(t.due!, hasTime: t.hasTime),
                  style: TextStyle(fontSize: 12, color: muted)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> words;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _SimpleRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.words,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        onTap: onTap,
        child: Row(children: [
          IconBadge(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Highlight(title, words,
                  style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded),
        ]),
      );
}

class _ListRow extends ConsumerWidget {
  final TaskList list;
  final List<String> words;
  final VoidCallback onTap;
  const _ListRow({required this.list, required this.words, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(listCountProvider(list.id));
    return _SimpleRow(
      icon: Icons.folder_rounded,
      color: Color(list.color),
      title: list.name,
      subtitle: '$count open ${count == 1 ? 'task' : 'tasks'}',
      words: words,
      onTap: onTap,
    );
  }
}

/// Shown before typing: tap a tag or list to search for it.
class _Suggestions extends ConsumerWidget {
  final ValueChanged<String> onPick;
  const _Suggestions({required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider);
    final lists = ref.watch(listControllerProvider).value ?? [];
    final recent = ref.watch(recentSearchesProvider).value ?? <String>[];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Search tasks (titles, notes, subtasks, comments), habits, lists, tags, '
          'saved filters and the trash.',
          style: TextStyle(color: muted, height: 1.4),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [
            Text('Recent', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            TextButton(
              onPressed: ref.read(recentSearchesProvider.notifier).clear,
              child: const Text('Clear'),
            ),
          ]),
          for (final q in recent)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(q),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => ref.read(recentSearchesProvider.notifier).remove(q),
              ),
              onTap: () => onPick(q),
            ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Tags', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final (name, _) in tags.take(12))
              ActionChip(label: Text('#$name'), onPressed: () => onPick('#$name')),
          ]),
        ],
        if (lists.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Lists', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final l in lists)
              ActionChip(
                avatar: Icon(Icons.circle, size: 12, color: Color(l.color)),
                label: Text(l.name),
                onPressed: () => onPick(l.name),
              ),
          ]),
        ],
      ],
    );
  }
}
