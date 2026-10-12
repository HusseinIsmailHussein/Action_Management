import 'package:flutter/material.dart';
import '../domain/reminder.dart';

/// Pick one reminder to add. Options in [taken] are hidden.
/// [onSelected] gets minutes before due (0 = at the time).
Future<void> showReminderSheet(
  BuildContext context, {
  required bool hasTime,
  required ValueChanged<int> onSelected,
  Set<int> taken = const {},
}) {
  final options = [
    for (final m in reminderPresetsFor(hasTime))
      if (!taken.contains(m)) m
  ];
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (options.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('All reminder options are already added.'),
          ),
        for (final m in options)
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: Text(reminderLabel(m, hasTime: hasTime)),
            onTap: () {
              Navigator.pop(ctx);
              onSelected(m);
            },
          ),
      ]),
    ),
  );
}
