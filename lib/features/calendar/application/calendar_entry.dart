import '../../tasks/domain/task.dart';

/// One item on the calendar. A [projected] entry is a future occurrence of a
/// repeating task: it carries the real task's id (tap opens it) but its
/// `task.due` is the occurrence date, and it can't be completed or deleted.
class CalendarEntry {
  final TaskItem task;
  final bool projected;
  const CalendarEntry(this.task, {this.projected = false});
}
