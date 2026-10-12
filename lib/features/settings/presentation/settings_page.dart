import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../backup/presentation/backup_page.dart';
import '../../onboarding/application/sample_data_service.dart';
import '../../onboarding/presentation/onboarding_page.dart';
import '../../habits/application/habit_trash_controller.dart';
import '../../tasks/application/trash_controller.dart';
import 'trash_page.dart';
import 'appearance_controls.dart';

/// App settings. Add new sections here.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: IconBadge(icon: icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );

  Future<void> _removeSamples(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove sample data?'),
        content: const Text(
            'This deletes the sample tasks and habits. Anything you created yourself stays.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(sampleDataServiceProvider).remove();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSamples = ref.watch(hasSampleDataProvider);
    final trashCount = (ref.watch(trashProvider).value?.length ?? 0) +
        (ref.watch(habitTrashProvider).value?.length ?? 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          _label(context, 'APPEARANCE'),
          const AppCard(child: AppearanceControls()),
          _label(context, 'DATA'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _tile(
                icon: Icons.backup_rounded,
                color: AppColors.teal,
                title: 'Backup & restore',
                subtitle: 'Export or import all your data',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const BackupPage())),
              ),
              const Divider(indent: 72),
              _tile(
                icon: Icons.delete_outline_rounded,
                color: AppColors.red,
                title: 'Trash',
                subtitle: trashCount == 0
                    ? 'Deleted tasks and habits are kept for 30 days'
                    : '$trashCount deleted ${trashCount == 1 ? 'item' : 'items'}',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const TrashPage())),
              ),
              if (hasSamples) ...[
                const Divider(indent: 72),
                _tile(
                  icon: Icons.cleaning_services_rounded,
                  color: AppColors.orange,
                  title: 'Remove sample data',
                  subtitle: 'Delete the example tasks and habits',
                  onTap: () => _removeSamples(context, ref),
                ),
              ],
            ]),
          ),
          _label(context, 'ABOUT'),
          AppCard(
            padding: EdgeInsets.zero,
            child: _tile(
              icon: Icons.waving_hand_rounded,
              color: AppColors.pink,
              title: 'Welcome tour',
              subtitle: 'See the quick intro again',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingPage(firstRun: false)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
