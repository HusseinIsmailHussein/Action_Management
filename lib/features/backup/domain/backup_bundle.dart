import 'dart:convert';
import '../../focus/domain/focus_session.dart';
import '../../focus/domain/pomodoro.dart';
import '../../habits/domain/habit.dart';
import '../../tasks/domain/saved_filter.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/domain/task_list.dart';

const kBackupApp = 'tickapp';
const kBackupVersion = 1;

/// Thrown when pasted text isn't a usable backup. [message] is safe to show.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);
  @override
  String toString() => message;
}

typedef BackupSummary = ({int tasks, int lists, int filters, int habits, int sessions});

String describeSummary(BackupSummary s) =>
    '${s.tasks} tasks, ${s.lists} lists, ${s.filters} filters, ${s.habits} habits, ${s.sessions} focus sessions';

/// Everything the app stores, as one JSON document.
/// To back up a new kind of data: add a field here (+ toJson/parse) and
/// read/write it in BackupService.
class BackupBundle {
  final List<TaskItem> tasks;
  final List<TaskList> lists;
  final List<SavedFilter> savedFilters;
  final List<Habit> habits;
  final List<FocusSession> focusSessions;
  final FocusSettings focusSettings;
  final DateTime exportedAt;

  const BackupBundle({
    required this.tasks,
    required this.lists,
    required this.savedFilters,
    required this.habits,
    required this.focusSessions,
    required this.focusSettings,
    required this.exportedAt,
  });

  BackupSummary get summary => (
        tasks: tasks.length,
        lists: lists.length,
        filters: savedFilters.length,
        habits: habits.length,
        sessions: focusSessions.length,
      );

  String get fileName {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'tickapp-backup-${exportedAt.year}-${two(exportedAt.month)}-${two(exportedAt.day)}.json';
  }

  Map<String, dynamic> toJson() => {
        'app': kBackupApp,
        'version': kBackupVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'data': {
          'tasks': tasks.map((t) => t.toJson()).toList(),
          'lists': lists.map((l) => l.toJson()).toList(),
          'savedFilters': savedFilters.map((f) => f.toJson()).toList(),
          'habits': habits.map((h) => h.toJson()).toList(),
          'focusSessions': focusSessions.map((s) => s.toJson()).toList(),
          'focusSettings': focusSettings.toJson(),
        },
      };

  String encode() => jsonEncode(toJson());

  /// Parses and validates backup text. Throws [BackupFormatException].
  factory BackupBundle.parse(String text) {
    Object? raw;
    try {
      raw = jsonDecode(text.trim());
    } on FormatException {
      throw const BackupFormatException("That text isn't a valid backup.");
    }
    if (raw is! Map<String, dynamic> || raw['app'] != kBackupApp) {
      throw const BackupFormatException("That isn't a TickApp backup.");
    }
    final version = raw['version'];
    if (version is! int || version > kBackupVersion) {
      throw const BackupFormatException(
          'This backup was made by a newer version of the app. Update the app first.');
    }
    final data = raw['data'];
    if (data is! Map<String, dynamic>) {
      throw const BackupFormatException('The backup is missing its data.');
    }

    try {
      List<T> section<T>(String key, T Function(Map<String, dynamic>) from) =>
          ((data[key] ?? const []) as List)
              .map((e) => from(e as Map<String, dynamic>))
              .toList();

      return BackupBundle(
        tasks: section('tasks', TaskItem.fromJson),
        lists: section('lists', TaskList.fromJson),
        savedFilters: section('savedFilters', SavedFilter.fromJson),
        habits: section('habits', Habit.fromJson),
        focusSessions: section('focusSessions', FocusSession.fromJson),
        focusSettings: data['focusSettings'] == null
            ? const FocusSettings()
            : FocusSettings.fromJson(data['focusSettings'] as Map<String, dynamic>),
        exportedAt: DateTime.tryParse((raw['exportedAt'] ?? '') as String) ?? DateTime.now(),
      );
    } catch (_) {
      throw const BackupFormatException('The backup is damaged or incomplete.');
    }
  }
}
