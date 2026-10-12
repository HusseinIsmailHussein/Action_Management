import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seconds of focus time logged for a task. Defaults to 0; main.dart plugs in
/// the focus feature's data, so tasks never import the focus feature.
final taskFocusSecondsProvider = Provider.family<int, String>((ref, taskId) => 0);
