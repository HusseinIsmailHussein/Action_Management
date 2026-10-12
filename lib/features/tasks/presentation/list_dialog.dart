import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/list_controller.dart';
import '../domain/task_list.dart';

const listColors = [
  0xFF4772FA, 0xFFE53935, 0xFFFB8C00, 0xFF43A047, 0xFF8E24AA, 0xFF00ACC1,
];

Future<void> showListDialog(BuildContext context, WidgetRef ref,
    {TaskList? existing}) {
  final name = TextEditingController(text: existing?.name ?? '');
  var color = existing?.color ?? listColors.first;

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(existing == null ? 'New list' : 'Edit list'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existing?.id != inboxId)
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'List name'),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                for (final c in listColors)
                  GestureDetector(
                    onTap: () => setState(() => color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(c),
                      child: color == c
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              final ctrl = ref.read(listControllerProvider.notifier);
              if (existing == null) {
                if (n.isEmpty) return;
                ctrl.add(n, color);
              } else {
                ctrl.edit(existing.id,
                    name: existing.id == inboxId || n.isEmpty ? null : n,
                    color: color);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
