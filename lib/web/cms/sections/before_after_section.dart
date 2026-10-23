import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../registry/section_registry.dart';
import 'section_head_content.dart';

class PanelContent {
  const PanelContent({required this.title, required this.items});

  factory PanelContent.fromJson(J j) => PanelContent(
        title: j.str('title'),
        items: j.strings('items').where((t) => t.isNotEmpty).toList(),
      );

  final String title;
  final List<String> items;
}

class BeforeAfterContent {
  const BeforeAfterContent({required this.head, required this.before, required this.after});

  factory BeforeAfterContent.fromJson(J j) => BeforeAfterContent(
        head: HeadContent.fromJson(j),
        before: PanelContent.fromJson(j.obj('before')),
        after: PanelContent.fromJson(j.obj('after')),
      );

  final HeadContent head;
  final PanelContent before;
  final PanelContent after;
}

final beforeAfterDefinition = SectionDefinition(
  type: 'beforeAfter',
  label: 'Before / after',
  builder: (context, SectionNode node) =>
      BeforeAfterSection(content: BeforeAfterContent.fromJson(node.content)),
);

class BeforeAfterSection extends StatelessWidget {
  const BeforeAfterSection({super.key, required this.content});

  final BeforeAfterContent content;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final before = _PainPanel(content: content.before, good: false);
    final after = _PainPanel(content: content.after, good: true);

    return Shell(
      child: Column(
        children: [
          SectionHead(
            eyebrow: content.head.eyebrow,
            title: content.head.title,
            lead: content.head.lead,
          ),
          SizedBox(height: mobile ? 40 : 56),
          if (mobile)
            Column(children: [before, const SizedBox(height: 16), after])
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: before),
                  const SizedBox(width: 20),
                  Expanded(child: after),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PainPanel extends StatelessWidget {
  final PanelContent content;
  final bool good;
  const _PainPanel({required this.content, required this.good});

  @override
  Widget build(BuildContext context) {
    final tint = good ? LK.teal : LK.danger;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: good ? LK.teal.withValues(alpha: 0.04) : LK.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: good ? LK.teal.withValues(alpha: 0.26) : LK.line,
          width: good ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  good ? Icons.auto_awesome_rounded : Icons.sentiment_dissatisfied_rounded,
                  size: 17,
                  color: tint,
                ),
              ),
              const SizedBox(width: 12),
              // Flexible so a long edited title wraps instead of overflowing.
              Flexible(
                child: Text(content.title,
                    style: LK.h3(context).copyWith(color: good ? LK.teal : LK.ink)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (final t in content.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    good ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 17,
                    color: good ? LK.teal : LK.muted,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      t,
                      style: LK.small.copyWith(
                        color: good ? LK.ink : LK.body,
                        fontWeight: good ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
