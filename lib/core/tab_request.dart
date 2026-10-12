import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Labels of the bottom-navigation tabs.
class AppTabs {
  static const home = 'Home';
  static const tasks = 'Tasks';
  static const calendar = 'Calendar';
  static const habits = 'Habits';
  static const focus = 'Focus';
}

/// Ask the app shell to switch tabs from anywhere (e.g. "See all" on the dashboard).
class TabRequestNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String tabLabel) => state = tabLabel;
  void clear() => state = null;
}

final tabRequestProvider =
    NotifierProvider<TabRequestNotifier, String?>(TabRequestNotifier.new);
