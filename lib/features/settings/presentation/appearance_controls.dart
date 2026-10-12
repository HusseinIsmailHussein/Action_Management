import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/settings_controller.dart';
import '../domain/app_settings.dart';

/// Theme mode + accent color pickers (used in Settings and the welcome flow).
class AppearanceControls extends ConsumerWidget {
  const AppearanceControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final ctrl = ref.read(appSettingsProvider.notifier);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Theme', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<AppThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: AppThemeMode.system, label: Text('System')),
            ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
            ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (s) => ctrl.setThemeMode(s.first),
        ),
      ),
      const SizedBox(height: 22),
      Text('Accent color', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 12),
      Wrap(spacing: 14, runSpacing: 12, children: [
        for (final c in kAccentChoices)
          GestureDetector(
            onTap: () => ctrl.setAccent(c),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: c == settings.accent ? Border.all(color: onSurface, width: 3) : null,
              ),
              child: c == settings.accent
                  ? const Icon(Icons.check_rounded, color: Colors.white)
                  : null,
            ),
          ),
      ]),
    ]);
  }
}
