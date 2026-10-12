/// A small Markdown subset for task notes: headings (#..###), **bold**, *italic*,
/// ~~strike~~, `code`, ``` code blocks, bullets, numbered lists, - [ ] checklists,
/// > quotes, --- dividers and links.
enum MdBlockType { blank, paragraph, heading, bullet, numbered, checkbox, quote, code, divider }

class MdBlock {
  final MdBlockType type;
  final String text;
  final int line; // index of the source line (used to toggle checklists)
  final int level; // heading level 1-3, or list indent depth
  final bool checked;
  final int number;
  const MdBlock(
    this.type,
    this.text, {
    this.line = 0,
    this.level = 0,
    this.checked = false,
    this.number = 0,
  });
}

final _checkbox = RegExp(r'^(\s*)[-*+] \[([ xX])\] ?(.*)$');
final _bullet = RegExp(r'^(\s*)[-*+] (.*)$');
final _numbered = RegExp(r'^(\s*)(\d+)\. (.*)$');
final _heading = RegExp(r'^(#{1,3}) (.*)$');
final _quote = RegExp(r'^> ?(.*)$');
final _divider = RegExp(r'^(-{3,}|\*{3,}|_{3,})\s*$');

List<MdBlock> parseMarkdown(String src) {
  final lines = src.split('\n');
  final blocks = <MdBlock>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];

    if (line.trimLeft().startsWith('```')) {
      final start = i;
      final buf = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
        buf.add(lines[i]);
        i++;
      }
      i++; // closing fence
      blocks.add(MdBlock(MdBlockType.code, buf.join('\n'), line: start));
      continue;
    }

    if (line.trim().isEmpty) {
      blocks.add(MdBlock(MdBlockType.blank, '', line: i));
    } else if (_divider.hasMatch(line)) {
      blocks.add(MdBlock(MdBlockType.divider, '', line: i));
    } else if (_checkbox.firstMatch(line) case final m?) {
      blocks.add(MdBlock(MdBlockType.checkbox, m.group(3)!,
          line: i, level: m.group(1)!.length ~/ 2, checked: m.group(2) != ' '));
    } else if (_bullet.firstMatch(line) case final m?) {
      blocks.add(MdBlock(MdBlockType.bullet, m.group(2)!,
          line: i, level: m.group(1)!.length ~/ 2));
    } else if (_numbered.firstMatch(line) case final m?) {
      blocks.add(MdBlock(MdBlockType.numbered, m.group(3)!,
          line: i, level: m.group(1)!.length ~/ 2, number: int.parse(m.group(2)!)));
    } else if (_heading.firstMatch(line) case final m?) {
      blocks.add(MdBlock(MdBlockType.heading, m.group(2)!,
          line: i, level: m.group(1)!.length));
    } else if (_quote.firstMatch(line) case final m?) {
      blocks.add(MdBlock(MdBlockType.quote, m.group(1)!, line: i));
    } else {
      blocks.add(MdBlock(MdBlockType.paragraph, line, line: i));
    }
    i++;
  }
  return blocks;
}

class MdSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool strike;
  final bool code;
  final String? url;
  const MdSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.code = false,
    this.url,
  });

  MdSpan withUrl(String url) => MdSpan(text,
      bold: bold, italic: italic, strike: strike, code: code, url: url);
}

final _inline = RegExp(
  r'\*\*(.+?)\*\*|~~(.+?)~~|`(.+?)`|\[(.+?)\]\((.+?)\)|\*(.+?)\*|(?<![A-Za-z0-9])_(.+?)_(?![A-Za-z0-9])|(https?://[^\s)]+)',
);

/// Splits one line of text into styled spans.
List<MdSpan> parseInline(String s,
    {bool bold = false, bool italic = false, bool strike = false}) {
  final out = <MdSpan>[];
  var pos = 0;
  for (final m in _inline.allMatches(s)) {
    if (m.start > pos) {
      out.add(MdSpan(s.substring(pos, m.start),
          bold: bold, italic: italic, strike: strike));
    }
    if (m.group(1) != null) {
      out.addAll(parseInline(m.group(1)!, bold: true, italic: italic, strike: strike));
    } else if (m.group(2) != null) {
      out.addAll(parseInline(m.group(2)!, bold: bold, italic: italic, strike: true));
    } else if (m.group(3) != null) {
      out.add(MdSpan(m.group(3)!, code: true));
    } else if (m.group(4) != null) {
      out.addAll(parseInline(m.group(4)!, bold: bold, italic: italic, strike: strike)
          .map((sp) => sp.withUrl(m.group(5)!)));
    } else if (m.group(6) != null) {
      out.addAll(parseInline(m.group(6)!, bold: bold, italic: true, strike: strike));
    } else if (m.group(7) != null) {
      out.addAll(parseInline(m.group(7)!, bold: bold, italic: true, strike: strike));
    } else if (m.group(8) != null) {
      out.add(MdSpan(m.group(8)!, url: m.group(8)));
    }
    pos = m.end;
  }
  if (pos < s.length) {
    out.add(MdSpan(s.substring(pos), bold: bold, italic: italic, strike: strike));
  }
  return out;
}

/// Flips the checkbox on source line [lineIndex].
String toggleCheckbox(String src, int lineIndex) {
  final lines = src.split('\n');
  if (lineIndex < 0 || lineIndex >= lines.length) return src;
  lines[lineIndex] = lines[lineIndex].replaceFirstMapped(
    RegExp(r'\[([ xX])\]'),
    (m) => m.group(1) == ' ' ? '[x]' : '[ ]',
  );
  return lines.join('\n');
}
