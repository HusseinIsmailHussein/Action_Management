import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/markdown.dart';

/// Renders task notes. Tapping a checklist item calls [onChanged] with the
/// updated text (pass null for a read-only view).
class MarkdownView extends StatelessWidget {
  final String text;
  final ValueChanged<String>? onChanged;
  const MarkdownView({super.key, required this.text, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocks = parseMarkdown(text);

    Widget build(MdBlock b) {
      switch (b.type) {
        case MdBlockType.blank:
          return const SizedBox(height: 8);
        case MdBlockType.divider:
          return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider());
        case MdBlockType.heading:
          return Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: _MdText(b.text,
                style: TextStyle(
                  fontSize: const [26.0, 21.0, 18.0][b.level - 1],
                  fontWeight: FontWeight.w800,
                )),
          );
        case MdBlockType.bullet:
          return _listRow(b.level, const Text('•', style: TextStyle(fontSize: 16)), b.text);
        case MdBlockType.numbered:
          return _listRow(
              b.level, Text('${b.number}.', style: const TextStyle(fontWeight: FontWeight.w600)), b.text);
        case MdBlockType.checkbox:
          return Padding(
            padding: EdgeInsets.only(left: 16.0 * b.level),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(toggleCheckbox(text, b.line)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                    b.checked
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 22,
                    color: b.checked ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MdText(
                      b.text,
                      style: b.checked
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough, color: Colors.grey)
                          : null,
                    ),
                  ),
                ]),
              ),
            ),
          );
        case MdBlockType.quote:
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: scheme.primary, width: 3)),
            ),
            child: _MdText(b.text,
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
          );
        case MdBlockType.code:
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(b.text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          );
        case MdBlockType.paragraph:
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _MdText(b.text),
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final b in blocks) build(b)],
    );
  }

  Widget _listRow(int level, Widget marker, String text) => Padding(
        padding: EdgeInsets.only(left: 16.0 * level, top: 2, bottom: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 24, child: marker),
          Expanded(child: _MdText(text)),
        ]),
      );
}

/// One line of inline-formatted text. Tapping a link copies it.
class _MdText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _MdText(this.text, {this.style});
  @override
  State<_MdText> createState() => _MdTextState();
}

class _MdTextState extends State<_MdText> {
  final _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  InlineSpan _span(MdSpan s, ColorScheme scheme) {
    final decorations = <TextDecoration>[
      if (s.strike) TextDecoration.lineThrough,
      if (s.url != null) TextDecoration.underline,
    ];
    TapGestureRecognizer? recognizer;
    if (s.url != null) {
      recognizer = TapGestureRecognizer()
        ..onTap = () {
          Clipboard.setData(ClipboardData(text: s.url!));
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Link copied')));
        };
      _recognizers.add(recognizer);
    }
    return TextSpan(
      text: s.text,
      recognizer: recognizer,
      style: TextStyle(
        fontWeight: s.bold ? FontWeight.w700 : null,
        fontStyle: s.italic ? FontStyle.italic : null,
        fontFamily: s.code ? 'monospace' : null,
        backgroundColor: s.code ? scheme.outlineVariant.withValues(alpha: 0.3) : null,
        color: s.url != null ? scheme.primary : null,
        decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final scheme = Theme.of(context).colorScheme;
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    return Text.rich(
      TextSpan(
        style: base.copyWith(fontSize: widget.style?.fontSize ?? 15, height: 1.35),
        children: [for (final s in parseInline(widget.text)) _span(s, scheme)],
      ),
    );
  }
}
