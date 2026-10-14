import 'package:flutter_test/flutter_test.dart';
import 'package:ticktick_app/features/calendar/domain/day_layout.dart';

void main() {
  snapTests();
  resizeTests();

  test('blocks that do not overlap each get the full width', () {
    final placed = layoutLanes([(start: 0, end: 60), (start: 60, end: 120)]);
    expect(placed.map((p) => p.lanes), [1, 1]);
    expect(placed.map((p) => p.lane), [0, 0]);
  });

  test('overlapping blocks sit side by side', () {
    final placed = {
      for (final p in layoutLanes([(start: 0, end: 90), (start: 30, end: 60)])) p.index: p
    };
    expect(placed[0]!.lane, 0);
    expect(placed[1]!.lane, 1);
    expect(placed[0]!.lanes, 2);
    expect(placed[1]!.lanes, 2);
  });

  test('a later block reuses a lane that has become free', () {
    // A 0-60, B 0-120, C 70-100: C overlaps only B, so it takes A's old lane.
    final placed = {
      for (final p in layoutLanes([
        (start: 0, end: 60),
        (start: 0, end: 120),
        (start: 70, end: 100),
      ]))
        p.index: p
    };
    expect(placed[1]!.lane, 0); // B (the longest) starts first
    expect(placed[0]!.lane, 1); // A
    expect(placed[2]!.lane, 1); // C reuses A's lane
    expect(placed.values.every((p) => p.lanes == 2), true);
  });

  test('separate clusters are laid out independently', () {
    final placed = {
      for (final p in layoutLanes([
        (start: 0, end: 60),
        (start: 30, end: 90),
        (start: 200, end: 260),
      ]))
        p.index: p
    };
    expect(placed[0]!.lanes, 2);
    expect(placed[2]!.lanes, 1);
  });
}

void snapTests() {
  test('snapMinute rounds to the nearest step', () {
    expect(snapMinute(22, latestStart: 1425), 15);
    expect(snapMinute(23, latestStart: 1425), 30);
    expect(snapMinute(60, latestStart: 1425), 60);
  });

  test('snapMinute stays within the day', () {
    expect(snapMinute(-40, latestStart: 1425), 0);
    expect(snapMinute(1500, latestStart: 1425), 1425);
  });
}

void resizeTests() {
  test('snapDuration rounds to the nearest step', () {
    expect(snapDuration(40, max: 600), 45);
    expect(snapDuration(52, max: 600), 45);
    expect(snapDuration(53, max: 600), 60);
  });

  test('snapDuration keeps a minimum and a maximum', () {
    expect(snapDuration(2, max: 600), 15);
    expect(snapDuration(-30, max: 600), 15);
    expect(snapDuration(900, max: 600), 600);
  });
}
