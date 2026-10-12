import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pressing Enter on a list item starts the next item; Enter on an empty item ends the list.
class ListContinuationFormatter extends TextInputFormatter {
  static final _item = RegExp(r'^(\s*)(- \[[ xX]\] |[-*+] |(\d+)\. )(.*)$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue neu) {
    if (neu.text.length != old.text.length + 1) return neu;
    final cursor = neu.selection.baseOffset;
    if (cursor <= 0 || neu.text[cursor - 1] != '\n') return neu;

    final lineStart = cursor >= 2 ? neu.text.lastIndexOf('\n', cursor - 2) + 1 : 0;
    final prevLine = neu.text.substring(lineStart, cursor - 1);
    final m = _item.firstMatch(prevLine);
    if (m == null) return neu;

    final indent = m.group(1)!;
    final marker = m.group(2)!;
    final content = m.group(4)!;

    if (content.trim().isEmpty) {
      // Empty item: remove it and leave the list.
      return TextEditingValue(
        text: neu.text.replaceRange(lineStart, cursor, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    final String next;
    if (marker.startsWith('- [')) {
      next = '- [ ] ';
    } else if (m.group(3) != null) {
      next = '${int.parse(m.group(3)!) + 1}. ';
    } else {
      next = marker;
    }
    final insert = indent + next;
    return TextEditingValue(
      text: neu.text.replaceRange(cursor, cursor, insert),
      selection: TextSelection.collapsed(offset: cursor + insert.length),
    );
  }
}

/// A text field for Markdown notes with a formatting toolbar.
class MarkdownEditor extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    this.autofocus = false,
  });

  TextSelection get _selection => controller.selection.isValid
      ? controller.selection
      : TextSelection.collapsed(offset: controller.text.length);

  void _apply(TextEditingValue value) {
    controller.value = value;
    onChanged(value.text);
  }

  /// Wraps the selection (or inserts an empty pair) with [left]/[right].
  void _wrap(String left, String right) {
    final sel = _selection;
    final text = controller.text;
    final selected = text.substring(sel.start, sel.end);
    _apply(TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, '$left$selected$right'),
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: sel.start + left.length)
          : TextSelection(
              baseOffset: sel.start + left.length,
              extentOffset: sel.start + left.length + selected.length),
    ));
  }

  /// Toggles [prefix] at the start of the current line.
  void _linePrefix(String prefix) {
    final sel = _selection;
    final text = controller.text;
    final lineStart = sel.start == 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
    final nl = text.indexOf('\n', sel.start);
    final lineEnd = nl == -1 ? text.length : nl;
    final line = text.substring(lineStart, lineEnd);

    final stripped = line.replaceFirst(
        RegExp(r'^(#{1,3} |- \[[ xX]\] |[-*+] |\d+\. |> )'), '');
    final newLine = line.startsWith(prefix) ? stripped : '$prefix$stripped';
    _apply(TextEditingValue(
      text: text.replaceRange(lineStart, lineEnd, newLine),
      selection: TextSelection.collapsed(offset: lineStart + newLine.length),
    ));
  }

  @override
  Widget build(BuildContext context) {
    Widget tool(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 22),
          onPressed: onTap,
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          tool(Icons.format_bold_rounded, 'Bold', () => _wrap('**', '**')),
          tool(Icons.format_italic_rounded, 'Italic', () => _wrap('*', '*')),
          tool(Icons.format_strikethrough_rounded, 'Strikethrough', () => _wrap('~~', '~~')),
          tool(Icons.code_rounded, 'Code', () => _wrap('`', '`')),
          tool(Icons.title_rounded, 'Heading', () => _linePrefix('## ')),
          tool(Icons.format_list_bulleted_rounded, 'Bullet list', () => _linePrefix('- ')),
          tool(Icons.format_list_numbered_rounded, 'Numbered list', () => _linePrefix('1. ')),
          tool(Icons.checklist_rounded, 'Checklist', () => _linePrefix('- [ ] ')),
          tool(Icons.format_quote_rounded, 'Quote', () => _linePrefix('> ')),
        ]),
      ),
      TextField(
        controller: controller,
        autofocus: autofocus,
        maxLines: null,
        minLines: 4,
        inputFormatters: [ListContinuationFormatter()],
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Write notes... bold, lists and checklists supported',
        ),
        onChanged: onChanged,
      ),
    ]);
  }
}
