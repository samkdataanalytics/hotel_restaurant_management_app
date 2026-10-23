import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/rich_text.dart' as md;
import '../model/site_document.dart';
import '../registry/section_registry.dart';
import '../render/link_action.dart';

class RichTextContent {
  const RichTextContent({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.centered,
    required this.wide,
  });

  factory RichTextContent.fromJson(J j) => RichTextContent(
        eyebrow: j.str('eyebrow'),
        title: j.str('title'),
        body: j.str('body'),
        centered: j.str('align') == 'center',
        wide: j.str('width') == 'wide',
      );

  final String eyebrow;
  final String title;
  final String body;
  final bool centered;
  final bool wide;
}

final richTextDefinition = SectionDefinition(
  type: 'richText',
  label: 'Text block',
  builder: (context, SectionNode node) =>
      RichTextSection(content: RichTextContent.fromJson(node.content)),
);

class RichTextSection extends StatelessWidget {
  const RichTextSection({super.key, required this.content});

  final RichTextContent content;

  @override
  Widget build(BuildContext context) {
    final align = content.centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = content.centered ? TextAlign.center : TextAlign.start;

    return Shell(
      maxWidth: content.wide ? 980 : 720,
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (content.eyebrow.isNotEmpty) ...[
            Eyebrow(content.eyebrow),
            const SizedBox(height: 18),
          ],
          if (content.title.isNotEmpty) ...[
            Text(content.title, textAlign: textAlign, style: LK.h2(context)),
            const SizedBox(height: 22),
          ],
          RichBody(source: content.body, textAlign: textAlign),
        ],
      ),
    );
  }
}

/// Renders the restricted markdown from [md.RichText]. Stateful only to own the
/// tap recognisers that links need, and dispose them.
class RichBody extends StatefulWidget {
  const RichBody({super.key, required this.source, this.textAlign = TextAlign.start});

  final String source;
  final TextAlign textAlign;

  @override
  State<RichBody> createState() => _RichBodyState();
}

class _RichBodyState extends State<RichBody> {
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

  TextSpan _span(md.RichSpan s, TextStyle base) {
    final link = s.link;
    TapGestureRecognizer? tap;
    if (link != null) {
      tap = TapGestureRecognizer()..onTap = () => runLink(context, link);
      _recognizers.add(tap);
    }
    return TextSpan(
      text: s.text,
      recognizer: tap,
      style: base.copyWith(
        fontWeight: s.bold ? FontWeight.w700 : null,
        fontStyle: s.italic ? FontStyle.italic : null,
        color: link != null ? LK.teal : null,
        decoration: link != null ? TextDecoration.underline : null,
        decorationColor: link != null ? LK.teal : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final blocks = md.MiniMarkdown.parse(widget.source);
    final body = LK.lead(context).copyWith(fontSize: 16.5);

    final children = <Widget>[];
    for (final b in blocks) {
      switch (b.kind) {
        case md.RichBlockKind.heading:
          children.add(Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text.rich(
              TextSpan(children: [for (final s in b.spans) _span(s, LK.h3(context))]),
              textAlign: widget.textAlign,
            ),
          ));
        case md.RichBlockKind.bullet:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 11, right: 12),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: LK.tealPure, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text.rich(TextSpan(children: [for (final s in b.spans) _span(s, body)])),
                ),
              ],
            ),
          ));
        case md.RichBlockKind.paragraph:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text.rich(
              TextSpan(children: [for (final s in b.spans) _span(s, body)]),
              textAlign: widget.textAlign,
            ),
          ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
