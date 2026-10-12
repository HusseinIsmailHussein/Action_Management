import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../application/backup_service.dart';
import '../domain/backup_bundle.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Share as a file; where sharing isn't available, copy the text instead.
  Future<void> _share(BuildContext context, WidgetRef ref) async {
    try {
      final bundle = await ref.read(backupServiceProvider).collect();
      try {
        await ref
            .read(backupExporterProvider)
            .shareFile(fileName: bundle.fileName, contents: bundle.encode());
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: bundle.encode()));
        if (context.mounted) {
          _snack(context, "Sharing isn't available here. Backup copied to the clipboard instead.");
        }
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not create the backup: $e');
    }
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    try {
      final bundle = await ref.read(backupServiceProvider).collect();
      await Clipboard.setData(ClipboardData(text: bundle.encode()));
      if (context.mounted) _snack(context, 'Backup copied to the clipboard.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not create the backup: $e');
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final text = await _askForBackupText(context);
    if (text == null || text.trim().isEmpty || !context.mounted) return;

    final BackupBundle bundle;
    try {
      bundle = BackupBundle.parse(text);
    } on BackupFormatException catch (e) {
      _snack(context, e.message);
      return;
    }

    final service = ref.read(backupServiceProvider);
    final current = (await service.collect()).summary;
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace all data?'),
        content: Text(
          'This backup has ${describeSummary(bundle.summary)}.\n\n'
          'Restoring replaces everything currently in the app '
          '(${describeSummary(current)}).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await service.restore(bundle);
    if (context.mounted) _snack(context, 'Backup restored.');
  }

  Future<String?> _askForBackupText(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Paste the backup text you copied from the other device.'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
                hintText: '{"app":"tickapp", ...}', border: OutlineInputBorder()),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('Paste from clipboard'),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) controller.text = data!.text!;
              },
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          AppCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconBadge(icon: Icons.info_outline_rounded, color: AppColors.blue),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Your tasks, lists, habits and focus history are stored only on this '
                  'device. Make a backup to keep them safe or move them to another phone.',
                  style: TextStyle(color: muted, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Back up',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _share(context, ref),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share backup file'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context, ref),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy backup to clipboard'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Restore',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Open the backup file in any text app, copy everything, then paste it here. '
                'Restoring replaces all current data.',
                style: TextStyle(color: muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _restore(context, ref),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restore from pasted backup'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
