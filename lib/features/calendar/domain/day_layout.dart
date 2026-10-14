/// A time span within one day, in minutes after midnight.
typedef TimeSpan = ({int start, int end});

/// Where a span sits when overlapping spans share a column's width:
/// it uses lane [lane] of [lanes] side-by-side lanes.
typedef PlacedSpan = ({int index, int lane, int lanes});

/// Places [spans] (indices refer to the input list) so that overlapping ones
/// sit side by side. Spans that don't overlap anything get one full-width lane.
List<PlacedSpan> layoutLanes(List<TimeSpan> spans) {
  final order = List<int>.generate(spans.length, (i) => i)
    ..sort((a, b) {
      final byStart = spans[a].start.compareTo(spans[b].start);
      return byStart != 0 ? byStart : spans[b].end.compareTo(spans[a].end);
    });

  final result = <PlacedSpan>[];
  var cluster = <int>[]; // spans overlapping each other (directly or through a chain)
  final laneEnds = <int>[]; // when the last span in each lane ends
  final laneOf = <int, int>{};
  var clusterEnd = -1;

  void flush() {
    for (final i in cluster) {
      result.add((index: i, lane: laneOf[i]!, lanes: laneEnds.length));
    }
    cluster = [];
    laneEnds.clear();
    clusterEnd = -1;
  }

  for (final i in order) {
    final s = spans[i];
    if (cluster.isNotEmpty && s.start >= clusterEnd) flush();
    var lane = laneEnds.indexWhere((end) => end <= s.start);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(s.end);
    } else {
      laneEnds[lane] = s.end;
    }
    laneOf[i] = lane;
    cluster.add(i);
    if (s.end > clusterEnd) clusterEnd = s.end;
  }
  flush();
  return result;
}

/// [minutes] (after midnight) rounded to the nearest [step], kept between
/// midnight and [latestStart]. Used to snap a dragged task to the grid.
int snapMinute(double minutes, {int step = 15, required int latestStart}) {
  final snapped = (minutes / step).round() * step;
  return snapped < 0 ? 0 : (snapped > latestStart ? latestStart : snapped);
}

/// A duration in minutes rounded to the nearest [step] and kept between
/// [min] and [max]. Used to snap a task block that is being resized.
int snapDuration(double minutes, {int step = 15, int min = 15, required int max}) {
  final snapped = (minutes / step).round() * step;
  return snapped < min ? min : (snapped > max ? max : snapped);
}
