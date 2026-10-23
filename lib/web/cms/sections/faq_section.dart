import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../registry/section_registry.dart';
import 'section_head_content.dart';

class FaqItem {
  const FaqItem({required this.q, required this.a});
  factory FaqItem.fromJson(J j) => FaqItem(q: j.str('q'), a: j.str('a'));
  final String q;
  final String a;
}

class FaqContent {
  const FaqContent({required this.head, required this.items});

  factory FaqContent.fromJson(J j) => FaqContent(
        head: HeadContent.fromJson(j),
        // A question with no text is dropped: it would render an empty tile.
        items: j.list('items', FaqItem.fromJson).where((i) => i.q.isNotEmpty).toList(),
      );

  final HeadContent head;
  final List<FaqItem> items;
}

final faqDefinition = SectionDefinition(
  type: 'faq',
  label: 'Frequently asked questions',
  builder: (context, SectionNode node) =>
      FaqSection(content: FaqContent.fromJson(node.content)),
);

class FaqSection extends StatelessWidget {
  const FaqSection({super.key, required this.content});

  final FaqContent content;

  @override
  Widget build(BuildContext context) {
    return Shell(
      maxWidth: 820,
      child: Column(
        children: [
          SectionHead(
            eyebrow: content.head.eyebrow,
            title: content.head.title,
            lead: content.head.lead,
          ),
          SizedBox(height: LK.isMobile(context) ? 32 : 48),
          for (final it in content.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FaqTile(q: it.q, a: it.a),
            ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String q;
  final String a;
  const _FaqTile({required this.q, required this.a});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: _open ? LK.white : LK.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _open ? LK.teal.withValues(alpha: 0.3) : LK.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.q,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: LK.ink,
                        fontSize: 15.5,
                        fontWeight: _open ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _open ? 0.125 : 0,
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: _open ? LK.teal : LK.muted,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState:
                    _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 28),
                  child: Text(widget.a, style: LK.small),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
