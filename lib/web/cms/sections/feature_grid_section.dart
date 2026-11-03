import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../registry/icon_registry.dart';
import '../registry/section_registry.dart';
import 'section_head_content.dart';

class FeatureGroup {
  const FeatureGroup({required this.icon, required this.title, required this.bullets});

  factory FeatureGroup.fromJson(J j) => FeatureGroup(
        icon: IconRegistry.resolve(j.strOrNull('icon')),
        title: j.str('title'),
        bullets: j.strings('bullets').where((b) => b.isNotEmpty).toList(),
      );

  final IconData icon;
  final String title;
  final List<String> bullets;
}

class FeatureGridContent {
  const FeatureGridContent({required this.head, required this.items});

  factory FeatureGridContent.fromJson(J j) => FeatureGridContent(
        head: HeadContent.fromJson(j),
        items: j.list('items', FeatureGroup.fromJson).where((g) => g.title.isNotEmpty).toList(),
      );

  final HeadContent head;
  final List<FeatureGroup> items;
}

final featureGridDefinition = SectionDefinition(
  type: 'featureGrid',
  label: 'Feature grid',
  builder: (context, SectionNode node) =>
      FeatureGridSection(content: FeatureGridContent.fromJson(node.content)),
);

class FeatureGridSection extends StatelessWidget {
  const FeatureGridSection({super.key, required this.content});

  final FeatureGridContent content;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final tablet = LK.isTablet(context);
    final cols = mobile ? 1 : (tablet ? 2 : 3);

    return Shell(
      child: Column(
        children: [
          SectionHead(
            eyebrow: content.head.eyebrow,
            title: content.head.title,
            lead: content.head.lead,
          ),
          SizedBox(height: mobile ? 40 : 60),
          LayoutBuilder(builder: (_, c) {
            const gap = 18.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < content.items.length; i++)
                  SizedBox(
                    width: w,
                    child: Reveal(
                      delayMs: (i % cols) * 70,
                      child: _FeatureCard(group: content.items[i]),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final FeatureGroup group;
  const _FeatureCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: LK.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(group.icon, size: 21, color: LK.teal),
          ),
          const SizedBox(height: 18),
          Text(group.title, style: LK.h3(context)),
          const SizedBox(height: 14),
          for (final b in group.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(color: LK.tealPure, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Text(b, style: LK.small.copyWith(fontSize: 14))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
