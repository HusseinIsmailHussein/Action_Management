import 'package:flutter/material.dart';

/// Asks for a tag name (typed or picked from [suggestions]).
/// Returns the raw text; callers run it through normalizeTag().
Future<String?> showTagDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  List<String> suggestions = const [],
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(prefixText: '#', hintText: 'tag name'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final s in suggestions)
                ActionChip(label: Text('#$s'), onPressed: () => Navigator.pop(ctx, s)),
            ]),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save')),
      ],
    ),
  );
}
