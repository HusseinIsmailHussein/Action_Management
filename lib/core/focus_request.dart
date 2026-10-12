import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Start focusing on this task": set by the task screen, consumed by the
/// focus feature and the app shell. Keeps the two features from importing
/// each other's UI.
class FocusRequestNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void request(String taskId) => state = taskId;
  void clear() => state = null;
}

final focusRequestProvider =
    NotifierProvider<FocusRequestNotifier, String?>(FocusRequestNotifier.new);
