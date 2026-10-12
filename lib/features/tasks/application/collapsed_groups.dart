import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keys of task-list sections the user has collapsed (kept until the app closes).
class CollapsedGroupsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String key) =>
      state = state.contains(key) ? (Set.of(state)..remove(key)) : {...state, key};
}

final collapsedGroupsProvider =
    NotifierProvider<CollapsedGroupsNotifier, Set<String>>(CollapsedGroupsNotifier.new);
