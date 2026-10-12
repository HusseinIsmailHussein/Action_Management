import 'package:flutter_test/flutter_test.dart';
import 'package:ticktick_app/features/tasks/domain/quick_add.dart';
import 'package:ticktick_app/features/tasks/domain/recurrence.dart';
import 'package:ticktick_app/features/tasks/domain/task.dart';

void main() {
  // A Monday, 10:00.
  final now = DateTime(2026, 10, 12, 10, 0);

  QuickAddResult parse(String text,
          {List<QuickList> lists = const [], Set<QuickKind> ignore = const {}}) =>
      parseQuickAdd(text, now, lists: lists, ignore: ignore);

  test('tomorrow with a time', () {
    final r = parse('Buy milk tomorrow at 5pm');
    expect(r.title, 'Buy milk');
    expect(r.due, DateTime(2026, 10, 13, 17));
    expect(r.hasTime, true);
  });

  test('weekday name means the upcoming one', () {
    final r = parse('Call mom friday');
    expect(r.title, 'Call mom');
    expect(r.due, DateTime(2026, 10, 16));
    expect(r.hasTime, false);
  });

  test('next monday is in the following week', () {
    expect(parse('Plan trip next monday').due, DateTime(2026, 10, 19));
  });

  test('day of the month rolls to next month when past', () {
    final r = parse('Pay rent on the 1st');
    expect(r.title, 'Pay rent');
    expect(r.due, DateTime(2026, 11, 1));
  });

  test('month and day with a time', () {
    final r = parse('Meeting Oct 15 at 3pm');
    expect(r.title, 'Meeting');
    expect(r.due, DateTime(2026, 10, 15, 15));
  });

  test('relative days and minutes', () {
    expect(parse('Dentist in 2 days').due, DateTime(2026, 10, 14));
    final r = parse('Call Bob in 30 minutes');
    expect(r.title, 'Call Bob');
    expect(r.due, DateTime(2026, 10, 12, 10, 30));
    expect(r.hasTime, true);
  });

  test('repeat on chosen weekdays starts on one of them', () {
    final r = parse('Gym every mon and thu at 7am');
    expect(r.title, 'Gym');
    expect(r.recurrence?.weekdays, {DateTime.monday, DateTime.thursday});
    expect(r.due, DateTime(2026, 10, 15, 7)); // Monday 7am has passed -> Thursday
  });

  test('daily repeat with time and duration', () {
    final r = parse('Standup daily at 9:30 for 15 min');
    expect(r.title, 'Standup');
    expect(r.recurrence?.unit, RepeatUnit.day);
    expect(r.durationMinutes, 15);
    expect(r.due, DateTime(2026, 10, 13, 9, 30)); // today 9:30 has passed
  });

  test('tags, priority and list', () {
    final r = parse('Report #work !high ~Work', lists: [(id: 'w', name: 'Work')]);
    expect(r.title, 'Report');
    expect(r.tags, ['work']);
    expect(r.priority, Priority.high);
    expect(r.listId, 'w');
  });

  test('remind me at the start drops the leading "to"', () {
    final r = parse('remind me to call mom tomorrow 9am');
    expect(r.title, 'call mom');
    expect(r.reminders, [0]);
    expect(r.due, DateTime(2026, 10, 13, 9));
  });

  test('dangling words are removed', () {
    expect(parse('Submit report by friday').title, 'Submit report');
  });

  test('ordinary text is left alone', () {
    final r = parse('Buy 2 apples');
    expect(r.title, 'Buy 2 apples');
    expect(r.due, isNull);
    expect(r.kinds, isEmpty);
  });

  test('ignored kinds stay in the title', () {
    final r = parse('Buy milk tomorrow', ignore: {QuickKind.date});
    expect(r.title, 'Buy milk tomorrow');
    expect(r.due, isNull);
  });
}
