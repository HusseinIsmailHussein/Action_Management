import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/date_utils.dart';
import '../data/local_task_repository.dart';
import '../domain/next_occurrence.dart';
import '../domain/recurrence.dart';
import '../domain/tag.dart';
import '../domain/task.dart';
import '../domain/task_list.dart';
import '../domain/task_repository.dart';
import '../domain/task_sorting.dart';
import '../domain/view_options.dart';
import 'filter_controller.dart';
import 'saved_filter_controller.dart';
import 'trash_controller.dart';
import 'view_options_controller.dart';
import 'reminder_providers.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => LocalTaskRepository(),
);

class TaskController extends AsyncNotifier<List<TaskItem>> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);
  List<TaskItem> get _current => state.value ?? [];

  @override
  Future<List<TaskItem>> build() async {
    final tasks = await _repo.load();
    _syncReminders(tasks);
    return tasks;
  }

  /// Fire-and-forget: reminders must never block or break task edits.
  void _syncReminders(List<TaskItem> tasks) {
    ref.read(reminderSchedulerProvider).sync(tasks).catchError((_) {});
  }

  /// Re-plan after the app returns to the foreground (no-op until loaded).
  void resyncReminders() {
    if (state.hasValue) _syncReminders(_current);
  }

  Future<void> _commit(List<TaskItem> next) async {
    state = AsyncData(next);
    await _repo.save(next);
    _syncReminders(next);
  }

  TaskItem? _find(String id) {
    for (final t in _current) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> add(
    String title, {
    DateTime? due,
    bool hasTime = false,
    int? durationMinutes,
    List<int> reminders = const [],
    Recurrence? recurrence,
    List<String> tags = const [],
    Priority priority = Priority.none,
    String listId = inboxId,
  }) {
    final t = TaskItem(
      id: const Uuid().v4(),
      title: title.trim(),
      due: due,
      hasTime: hasTime,
      durationMinutes: durationMinutes,
      reminders: reminders,
      recurrence: recurrence,
      tags: tags,
      priority: priority,
      listId: listId,
      createdAt: DateTime.now(),
    );
    return _commit([t, ..._current]);
  }

  /// Completing a repeating task logs a finished copy and rolls the task
  /// forward to its next occurrence. "Won't do" tasks reopen. Others toggle.
  Future<void> toggle(String id) {
    final task = _find(id);
    if (task == null) return Future.value();
    if (task.wontDo) {
      return edit(
        id,
        (t) => t.copyWith(done: false, wontDo: false, clearCompleted: true),
      );
    }
    if (task.done) {
      return edit(id, (t) => t.copyWith(done: false, clearCompleted: true));
    }
    final now = DateTime.now();
    final next = nextOccurrence(task, now);
    if (next == null) {
      return edit(id, (t) => t.copyWith(done: true, completedAt: now));
    }
    final finished = task.copyWith(
      id: const Uuid().v4(),
      done: true,
      completedAt: now,
      clearRecurrence: true,
    );
    return _commit([finished, for (final t in _current) t.id == id ? next : t]);
  }

  /// Close a task without completing it (or reopen it).
  Future<void> setWontDo(String id, bool value) => edit(
    id,
    (t) => value
        ? t.copyWith(done: true, wontDo: true, completedAt: DateTime.now())
        : t.copyWith(done: false, wontDo: false, clearCompleted: true),
  );

  Future<void> togglePin(String id) =>
      edit(id, (t) => t.copyWith(pinned: !t.pinned));

  Future<void> duplicate(String id) {
    final t = _find(id);
    if (t == null) return Future.value();
    const uuid = Uuid();
    final copy = t.copyWith(
      id: uuid.v4(),
      done: false,
      wontDo: false,
      clearCompleted: true,
      pinned: false,
      createdAt: DateTime.now(),
      subtasks: [
        for (final s in t.subtasks) s.copyWith(id: uuid.v4(), done: false),
      ],
      comments: const [],
    );
    return _commit([copy, ..._current]);
  }

  Future<void> addAll(Iterable<TaskItem> items) {
    final existing = _current.map((t) => t.id).toSet();
    return _commit([
      ...items.where((t) => !existing.contains(t.id)),
      ..._current,
    ]);
  }

  /// Applies a drag-and-drop arrangement of the tasks in [idsInNewOrder].
  /// The positions those tasks already occupy are re-dealt in the new order,
  /// so tasks that aren't on screen keep their place and no new numbers
  /// (with their precision limits) are ever invented.
  Future<void> applyManualOrder(List<String> idsInNewOrder) {
    final byId = {for (final t in _current) t.id: t};
    final items = [
      for (final id in idsInNewOrder)
        if (byId[id] != null) byId[id]!,
    ];
    final slots = items.map(effectiveOrder).toList()..sort();
    for (var i = 1; i < slots.length; i++) {
      if (slots[i] <= slots[i - 1]) {
        slots[i] = slots[i - 1] + 0.01; // break ties
      }
    }
    final assigned = {
      for (var i = 0; i < items.length; i++) items[i].id: slots[i],
    };
    return _commit([
      for (final t in _current)
        assigned.containsKey(t.id) ? t.copyWith(order: assigned[t.id]) : t,
    ]);
  }

  /// Puts a deleted task back (used by "Undo").
  Future<void> restore(TaskItem task) async {
    final commit = _commit([task, ..._current.where((t) => t.id != task.id)]);
    await ref.read(trashProvider.notifier).discard(task.id);
    await commit;
  }

  Future<void> removeWhere(bool Function(TaskItem) test) =>
      _commit(_current.where((t) => !test(t)).toList());

  /// Single entry point for changing any field of a task.
  Future<void> edit(String id, TaskItem Function(TaskItem) change) =>
      _commit([for (final t in _current) t.id == id ? change(t) : t]);

  /// Deletes a task, keeping a copy in the trash for 30 days.
  Future<void> remove(String id) async {
    final task = _find(id);
    // Update the list right away (a swiped-away tile must leave the tree at once).
    final commit = _commit(_current.where((t) => t.id != id).toList());
    if (task != null) await ref.read(trashProvider.notifier).add(task);
    await commit;
  }

  /// Moves the given tasks into [listId] (used when a list delete is undone).
  Future<void> assignList(Iterable<String> taskIds, String listId) {
    final ids = taskIds.toSet();
    return _commit([
      for (final t in _current)
        ids.contains(t.id) ? t.copyWith(listId: listId) : t,
    ]);
  }

  Future<void> reassignList(String from, String to) => _commit([
    for (final t in _current) t.listId == from ? t.copyWith(listId: to) : t,
  ]);

  Future<void> addTag(String taskId, String raw) {
    final tag = normalizeTag(raw);

    if (tag.isEmpty) {
      return Future.value();
    }

    return edit(
      taskId,
      (t) => t.tags.contains(tag) ? t : t.copyWith(tags: [...t.tags, tag]),
    );
  }

  Future<void> removeTag(String taskId, String tag) => edit(
    taskId,
    (t) => t.copyWith(tags: t.tags.where((x) => x != tag).toList()),
  );

  /// Renames [from] on every task. An empty [to] removes the tag;
  /// renaming to an existing tag merges the two.
  Future<void> renameTag(String from, String to) => _commit([
    for (final t in _current)
      t.tags.contains(from)
          ? t.copyWith(tags: _replaceTag(t.tags, from, to))
          : t,
  ]);

  static List<String> _replaceTag(List<String> tags, String from, String to) {
    final out = <String>[];
    for (final x in tags) {
      final y = x == from ? to : x;
      if (y.isNotEmpty && !out.contains(y)) out.add(y);
    }
    return out;
  }

  // ---- Subtasks ----
  Future<void> addSubtask(String taskId, String title) => edit(
    taskId,
    (t) => t.copyWith(
      subtasks: [
        ...t.subtasks,
        Subtask(id: const Uuid().v4(), title: title.trim()),
      ],
    ),
  );

  Future<void> editSubtask(
    String taskId,
    String subId,
    Subtask Function(Subtask) change,
  ) => edit(
    taskId,
    (t) => t.copyWith(
      subtasks: [for (final s in t.subtasks) s.id == subId ? change(s) : s],
    ),
  );

  Future<void> toggleSubtask(String taskId, String subId) =>
      editSubtask(taskId, subId, (s) => s.copyWith(done: !s.done));

  Future<void> removeSubtask(String taskId, String subId) => edit(
    taskId,
    (t) =>
        t.copyWith(subtasks: t.subtasks.where((s) => s.id != subId).toList()),
  );

  // ---- Comments ----
  Future<void> addComment(String taskId, String text) {
    if (text.trim().isEmpty) return Future.value();
    return edit(
      taskId,
      (t) => t.copyWith(
        comments: [
          ...t.comments,
          Comment(
            id: const Uuid().v4(),
            text: text.trim(),
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );
  }

  Future<void> removeComment(String taskId, String commentId) => edit(
    taskId,
    (t) => t.copyWith(
      comments: t.comments.where((c) => c.id != commentId).toList(),
    ),
  );
}

final taskControllerProvider =
    AsyncNotifierProvider<TaskController, List<TaskItem>>(TaskController.new);

final taskByIdProvider = Provider.family<TaskItem?, String>((ref, id) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  for (final t in tasks) {
    if (t.id == id) return t;
  }
  return null;
});

// ---- Views: a smart view (Today...) OR a custom list ----

enum SmartView { all, today, upcoming, noDate, completed }

extension SmartViewX on SmartView {
  String get label => switch (this) {
    SmartView.today => 'Today',
    SmartView.upcoming => 'Upcoming',
    SmartView.all => 'All',
    SmartView.completed => 'Completed',
    SmartView.noDate => 'No Date',
  };
}

class ViewSelection {
  final SmartView? smart;
  final String? listId;
  final String? tag;
  final String? filterId; // a saved filter
  const ViewSelection.smart(SmartView this.smart)
    : listId = null,
      tag = null,
      filterId = null;
  const ViewSelection.list(String this.listId)
    : smart = null,
      tag = null,
      filterId = null;
  const ViewSelection.tagged(String this.tag)
    : smart = null,
      listId = null,
      filterId = null;
  const ViewSelection.saved(String this.filterId)
    : smart = null,
      listId = null,
      tag = null;

  @override
  bool operator ==(Object other) =>
      other is ViewSelection &&
      other.smart == smart &&
      other.listId == listId &&
      other.tag == tag &&
      other.filterId == filterId;
  @override
  int get hashCode => Object.hash(smart, listId, tag, filterId);
}

class SelectedViewNotifier extends Notifier<ViewSelection> {
  @override
  ViewSelection build() => const ViewSelection.smart(SmartView.today);
  void select(ViewSelection v) => state = v;
}

final selectedViewProvider =
    NotifierProvider<SelectedViewNotifier, ViewSelection>(
      SelectedViewNotifier.new,
    );

bool matchesSmart(TaskItem t, SmartView v, DateTime now) {
  final today = dateOnly(now);
  final tomorrow = today.add(const Duration(days: 1));
  switch (v) {
    case SmartView.today:
      return t.due != null &&
          (isSameDay(t.due!, now) || t.due!.isBefore(today)); // incl. overdue
    case SmartView.upcoming:
      return !t.done && t.due != null && !t.due!.isBefore(tomorrow);
    case SmartView.all:
      return !t.done;
    case SmartView.completed:
      return t.done;
    case SmartView.noDate:
      return t.due == null;
  }
}

final visibleTasksProvider = Provider<List<TaskItem>>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final sel = ref.watch(selectedViewProvider);
  final now = DateTime.now();

  final filter = ref.watch(taskFilterProvider);
  final saved = sel.filterId == null
      ? null
      : ref.watch(savedFilterByIdProvider(sel.filterId!));
  final base = sel.listId != null
      ? tasks.where((t) => t.listId == sel.listId)
      : sel.tag != null
      ? tasks.where((t) => t.tags.contains(sel.tag))
      : sel.filterId != null
      ? tasks.where((t) => !t.done && (saved?.filter.matches(t, now) ?? false))
      : tasks.where((t) => matchesSmart(t, sel.smart!, now));
  final list = base.where((t) => filter.matches(t, now)).toList();

  final options = ref.watch(viewOptionsProvider).value ?? const ViewOptions();
  sortTasks(list, options);
  return list;
});

final smartCountProvider = Provider.family<int, SmartView>((ref, v) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final now = DateTime.now();

  return tasks.where((t) {
    if (t.done) return false; // don't count completed tasks
    return matchesSmart(t, v, now);
  }).length;
});

final listCountProvider = Provider.family<int, String>((ref, listId) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  return tasks.where((t) => t.listId == listId && !t.done).length;
});

/// Every tag in use with its count of open tasks, A-Z.
final allTagsProvider = Provider<List<(String, int)>>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final counts = <String, int>{};
  for (final t in tasks) {
    for (final tag in t.tags) {
      counts[tag] = (counts[tag] ?? 0) + (t.done ? 0 : 1);
    }
  }
  final names = counts.keys.toList()..sort();
  return [for (final n in names) (n, counts[n]!)];
});

/// Open tasks matching a saved filter (drawer badge).
final savedFilterCountProvider = Provider.family<int, String>((ref, id) {
  final saved = ref.watch(savedFilterByIdProvider(id));
  if (saved == null) return 0;
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final now = DateTime.now();
  return tasks.where((t) => !t.done && saved.filter.matches(t, now)).length;
});

/// (done, total) for the Today banner: tasks due today, finished or still open.
final todayProgressProvider = Provider<(int, int)>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final now = DateTime.now();
  final done = tasks
      .where(
        (t) => t.done && !t.wontDo && t.due != null && isSameDay(t.due!, now),
      )
      .length;
  final total = tasks
      .where((t) => matchesSmart(t, SmartView.today, now))
      .length;
  return (done, total);
});
