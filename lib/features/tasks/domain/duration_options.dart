/// Offered task durations in minutes.
const kDurationPresets = <int>[15, 30, 45, 60, 90, 120, 180, 240];

String durationLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return h == 1 ? '1 hour' : '$h hours';
  return '${h}h ${m}m';
}
