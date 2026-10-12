/// What a home-screen shortcut (long-press the app icon) can do.
/// Add a value here and handle it in the app shell to offer a new shortcut.
enum ShortcutAction { newTask, newHabit, focus }

extension ShortcutActionX on ShortcutAction {
  String get title => switch (this) {
        ShortcutAction.newTask => 'New task',
        ShortcutAction.newHabit => 'New habit',
        ShortcutAction.focus => 'Start focus',
      };
}

/// Registers the shortcuts with the OS and reports which one launched the app.
abstract class ShortcutService {
  /// [onAction] is called when the user opens the app via a shortcut.
  Future<void> init(void Function(ShortcutAction action) onAction);
}

/// Used on platforms without shortcuts (web, desktop) or if setup failed.
class NoopShortcutService implements ShortcutService {
  const NoopShortcutService();
  @override
  Future<void> init(void Function(ShortcutAction action) onAction) async {}
}
