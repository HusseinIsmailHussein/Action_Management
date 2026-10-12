import 'recurrence.dart';
import 'task_list.dart';

enum Priority { none, low, medium, high }

class Comment {
  final String id;
  final String text;
  final DateTime createdAt;
  const Comment({required this.id, required this.text, required this.createdAt});

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'createdAt': createdAt.toIso8601String()};

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// A checklist item with its own optional date, time and reminders.
class Subtask {
  final String id;
  final String title;
  final bool done;
  final DateTime? due;
  final bool hasTime; // false = all-day
  final List<int> reminders; // minutes before due

  const Subtask({
    required this.id,
    required this.title,
    this.done = false,
    this.due,
    this.hasTime = false,
    this.reminders = const [],
  });

  Subtask copyWith({
    String? id,
    String? title,
    bool? done,
    DateTime? due,
    bool clearDue = false,
    bool? hasTime,
    List<int>? reminders,
  }) =>
      Subtask(
        id: id ?? this.id,
        title: title ?? this.title,
        done: done ?? this.done,
        due: clearDue ? null : (due ?? this.due),
        hasTime: clearDue ? false : (hasTime ?? this.hasTime),
        reminders: clearDue ? const [] : (reminders ?? this.reminders),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'due': due?.toIso8601String(),
        'hasTime': hasTime,
        'reminders': reminders,
      };

  factory Subtask.fromJson(Map<String, dynamic> j) => Subtask(
        id: j['id'] as String,
        title: j['title'] as String,
        done: (j['done'] ?? false) as bool,
        due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
        hasTime: (j['hasTime'] ?? false) as bool,
        reminders: List<int>.from((j['reminders'] ?? const []) as List),
      );
}

class TaskItem {
  final String id;
  final String title;
  final String notes; // markdown
  final DateTime? due;
  final bool hasTime; // false = all-day
  final int? durationMinutes; // only with a time
  final List<int> reminders; // minutes before due; several allowed
  final Recurrence? recurrence;
  final List<String> tags; // normalized, see normalizeTag()
  final Priority priority;
  final String listId;
  final bool done; // also true for "won't do"
  final bool wontDo;
  final bool pinned;
  final List<Subtask> subtasks;
  final List<Comment> comments;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double? order; // position in Manual sort; null = never dragged

  const TaskItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.due,
    this.hasTime = false,
    this.durationMinutes,
    this.reminders = const [],
    this.recurrence,
    this.tags = const [],
    this.priority = Priority.none,
    this.listId = inboxId,
    this.done = false,
    this.wontDo = false,
    this.pinned = false,
    this.subtasks = const [],
    this.comments = const [],
    required this.createdAt,
    this.completedAt,
    this.order,
  });

  /// Clearing the date also clears everything that depends on it
  /// (time, duration, reminders, repeat).
  TaskItem copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? due,
    bool clearDue = false,
    bool? hasTime,
    int? durationMinutes,
    bool clearDuration = false,
    List<int>? reminders,
    Recurrence? recurrence,
    bool clearRecurrence = false,
    List<String>? tags,
    Priority? priority,
    String? listId,
    bool? done,
    bool? wontDo,
    bool? pinned,
    List<Subtask>? subtasks,
    List<Comment>? comments,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompleted = false,
    double? order,
  }) {
    final newHasTime = clearDue ? false : (hasTime ?? this.hasTime);
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      due: clearDue ? null : (due ?? this.due),
      hasTime: newHasTime,
      durationMinutes: (clearDue || clearDuration || !newHasTime)
          ? null
          : (durationMinutes ?? this.durationMinutes),
      reminders: clearDue ? const [] : (reminders ?? this.reminders),
      recurrence: (clearDue || clearRecurrence) ? null : (recurrence ?? this.recurrence),
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      listId: listId ?? this.listId,
      done: done ?? this.done,
      wontDo: wontDo ?? this.wontDo,
      pinned: pinned ?? this.pinned,
      subtasks: subtasks ?? this.subtasks,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'due': due?.toIso8601String(),
        'hasTime': hasTime,
        'durationMinutes': durationMinutes,
        'reminders': reminders,
        'recurrence': recurrence?.toJson(),
        'tags': tags,
        'priority': priority.index,
        'listId': listId,
        'done': done,
        'wontDo': wontDo,
        'pinned': pinned,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'comments': comments.map((c) => c.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'order': order,
      };

  /// Tolerates data saved by earlier versions (single `reminderMinutes`,
  /// no listId / subtasks / tags / ...).
  factory TaskItem.fromJson(Map<String, dynamic> j) {
    final reminders = j['reminders'] != null
        ? List<int>.from(j['reminders'] as List)
        : (j['reminderMinutes'] != null ? [j['reminderMinutes'] as int] : <int>[]);
    return TaskItem(
      id: j['id'] as String,
      title: j['title'] as String,
      notes: (j['notes'] ?? '') as String,
      due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
      hasTime: (j['hasTime'] ?? false) as bool,
      durationMinutes: j['durationMinutes'] as int?,
      reminders: reminders,
      recurrence: j['recurrence'] == null
          ? null
          : Recurrence.fromJson(j['recurrence'] as Map<String, dynamic>),
      tags: List<String>.from((j['tags'] ?? const []) as List),
      priority: Priority.values[(j['priority'] ?? 0) as int],
      listId: (j['listId'] ?? inboxId) as String,
      done: (j['done'] ?? false) as bool,
      wontDo: (j['wontDo'] ?? false) as bool,
      pinned: (j['pinned'] ?? false) as bool,
      subtasks: ((j['subtasks'] ?? const []) as List)
          .map((e) => Subtask.fromJson(e as Map<String, dynamic>))
          .toList(),
      comments: ((j['comments'] ?? const []) as List)
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      completedAt: j['completedAt'] == null
          ? null
          : DateTime.parse(j['completedAt'] as String),
      order: (j['order'] as num?)?.toDouble(),
    );
  }
}
