import 'package:flutter/material.dart';
import '../domain/duration_options.dart';

/// [onSelected] gets minutes, or null for "no duration".
Future<void> showDurationSheet(
  BuildContext context, {
  required int? current,
  required ValueChanged<int?> onSelected,
}) {
  Widget option(BuildContext ctx, String label, int? minutes) => ListTile(
        title: Text(label),
        trailing: minutes == current ? const Icon(Icons.check) : null,
        onTap: () {
          Navigator.pop(ctx);
          onSelected(minutes);
        },
      );

  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          option(ctx, 'No duration', null),
          for (final m in kDurationPresets) option(ctx, durationLabel(m), m),
        ]),
      ),
    ),
  );
}
