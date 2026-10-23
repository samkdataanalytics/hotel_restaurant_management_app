import 'json_reader.dart';
import 'link_target.dart';

/// A deliberately small markup: paragraphs, `##` headings, `-` bullets, and
/// `**bold**`, `*italic*`, `[label](target)` inside a line.
///
/// There is no HTML anywhere, so there is nothing to sanitise: the output is a
/// list of plain spans, and a link is only live if its target passes the same
/// [LinkTarget] allowlist as every other link on the site.
enum RichBlockKind { paragraph, heading, bullet }

class RichSpan {
  const RichSpan(this.text, {this.bold = false, this.italic = false, this.link});

  final String text;
  final bool bold;
  final bool italic;

  /// Non-null only for a link that passed validation.
  final LinkTarget? link;

  @override
  bool operator ==(Object o) =>
      o is RichSpan && o.text == text && o.bold == bold && o.italic == italic && o.link == link;

  @override
  int get hashCode => Object.hash(text, bold, italic, link);

  @override
  String toString() => 'RichSpan($text${bold ? ', b' : ''}${italic ? ', i' : ''}${link != null ? ', $link' : ''})';
}

class RichBlock {
  const RichBlock(this.kind, this.spans);

  final RichBlockKind kind;
  final List<RichSpan> spans;

  String get plain => spans.map((s) => s.text).join();
}

class MiniMarkdown {
  MiniMarkdown._();

  /// Parses [source] into blocks. Never throws.
  static List<RichBlock> parse(String source) {
    final blocks = <RichBlock>[];
    final para = <String>[];

    void flushParagraph() {
      if (para.isEmpty) return;
      blocks.add(RichBlock(RichBlockKind.paragraph, inline(para.join(' '))));
      para.clear();
    }

    for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        flushParagraph();
      } else if (line.startsWith('## ')) {
        flushParagraph();
        blocks.add(RichBlock(RichBlockKind.heading, inline(line.substring(3).trim())));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        blocks.add(RichBlock(RichBlockKind.bullet, inline(line.substring(2).trim())));
      } else {
        para.add(line.trim());
      }
    }
    flushParagraph();
    return blocks;
  }

  static final _token = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|\[([^\]]+)\]\(([^)\s]+)\)');

  /// Inline spans for one line.
  static List<RichSpan> inline(String s) {
    final out = <RichSpan>[];
    var last = 0;
    for (final m in _token.allMatches(s)) {
      if (m.start > last) out.add(RichSpan(s.substring(last, m.start)));
      if (m[1] != null) {
        out.add(RichSpan(m[1]!, bold: true));
      } else if (m[2] != null) {
        out.add(RichSpan(m[2]!, italic: true));
      } else {
        out.add(RichSpan(m[3]!, link: _target(m[4]!)));
      }
      last = m.end;
    }
    if (last < s.length) out.add(RichSpan(s.substring(last)));
    return out;
  }

  /// Turns the text in `[label](target)` into a [LinkTarget], or null when it is
  /// not one the site allows (the label is then shown as plain text).
  static LinkTarget? _target(String t) {
    final LinkTarget target;
    if (t.startsWith('/')) {
      target = LinkTarget.fromJson(J({'type': 'internal', 'value': t}));
    } else if (t.startsWith('#')) {
      target = LinkTarget.fromJson(J({'type': 'anchor', 'value': t.substring(1)}));
    } else {
      target = LinkTarget.fromJson(J({'type': 'external', 'value': t, 'newTab': true}));
    }
    return target.isNone ? null : target;
  }
}
