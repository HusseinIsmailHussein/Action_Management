import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/shortcut_service.dart';

/// Defaults to a no-op; main.dart plugs in the real service.
final shortcutServiceProvider =
    Provider<ShortcutService>((ref) => const NoopShortcutService());
