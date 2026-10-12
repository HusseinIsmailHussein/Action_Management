import '../../habits/domain/habit.dart';
import '../../tasks/domain/recurrence.dart';
import '../../tasks/domain/task.dart';

/// Sample items use ids starting with this prefix so they can be found and
/// removed later without touching the user's own data.
const kSamplePrefix = 'sample-';

const _welcomeNotes = '''Welcome to **TickApp**! A few things to try:

- [ ] Tick this box (notes support checklists)
- [ ] Swipe a task right to complete it, left to delete it
- [ ] Open the **Calendar**, **Habits** and **Focus** tabs
- [ ] Tap the pencil above to format these notes

> Remove all sample items any time from Settings.''';

DateTime _day(DateTime now, int plusDays, [int hour = 0]) =>
    DateTime(now.year, now.month, now.day + plusDays, hour);

List<TaskItem> sampleTasks(DateTime now) {
  // Next Friday (today if it is Friday) for the weekly review.
  final toFriday = (DateTime.friday - now.weekday + 7) % 7;
  return [
    TaskItem(
      id: '${kSamplePrefix}welcome',
      title: 'Welcome to TickApp',
      notes: _welcomeNotes,
      due: _day(now, 0),
      priority: Priority.medium,
      tags: const ['sample'],
      subtasks: const [
        Subtask(id: '${kSamplePrefix}welcome-1', title: 'Open this task'),
        Subtask(id: '${kSamplePrefix}welcome-2', title: 'Add your own task with the + button'),
      ],
      createdAt: now,
    ),
    TaskItem(
      id: '${kSamplePrefix}groceries',
      title: 'Buy groceries',
      due: _day(now, 0),
      tags: const ['errands', 'sample'],
      subtasks: const [
        Subtask(id: '${kSamplePrefix}groceries-1', title: 'Milk'),
        Subtask(id: '${kSamplePrefix}groceries-2', title: 'Eggs'),
        Subtask(id: '${kSamplePrefix}groceries-3', title: 'Bread'),
      ],
      createdAt: now,
    ),
    TaskItem(
      id: '${kSamplePrefix}plan',
      title: 'Plan the week',
      due: _day(now, 1, 9),
      hasTime: true,
      durationMinutes: 30,
      priority: Priority.high,
      tags: const ['sample'],
      createdAt: now,
    ),
    TaskItem(
      id: '${kSamplePrefix}review',
      title: 'Weekly review',
      due: _day(now, toFriday),
      recurrence: const Recurrence(unit: RepeatUnit.week, weekdays: {DateTime.friday}),
      tags: const ['sample'],
      createdAt: now,
    ),
    TaskItem(
      id: '${kSamplePrefix}read',
      title: 'Read 20 pages',
      due: _day(now, 3),
      priority: Priority.low,
      tags: const ['sample'],
      createdAt: now,
    ),
  ];
}

List<Habit> sampleHabits(DateTime now) => [
      Habit(
        id: '${kSamplePrefix}water',
        name: 'Drink water',
        iconIndex: 0,
        color: 0xFF3B82F6,
        target: 8,
        createdAt: now,
      ),
      Habit(
        id: '${kSamplePrefix}read',
        name: 'Read for 20 minutes',
        iconIndex: 2,
        color: 0xFF8B5CF6,
        createdAt: now,
      ),
      Habit(
        id: '${kSamplePrefix}stretch',
        name: 'Stretch',
        iconIndex: 3,
        color: 0xFF10B981,
        weekdays: const {1, 3, 5},
        createdAt: now,
      ),
    ];
