import 'package:quick_actions/quick_actions.dart';
import '../domain/shortcut_service.dart';

/// Android app shortcuts / iOS home-screen quick actions via the quick_actions plugin.
class QuickActionsService implements ShortcutService {
  @override
  Future<void> init(void Function(ShortcutAction action) onAction) async {
    try {
      const quickActions = QuickActions();
      quickActions.initialize((type) {
        for (final a in ShortcutAction.values) {
          if (a.name == type) {
            onAction(a);
            return;
          }
        }
      });
      await quickActions.setShortcutItems([
        for (final a in ShortcutAction.values)
          ShortcutItem(type: a.name, localizedTitle: a.title),
      ]);
    } catch (_) {
      // Not supported here (web, desktop, old Android): the app works without shortcuts.
    }
  }
}
