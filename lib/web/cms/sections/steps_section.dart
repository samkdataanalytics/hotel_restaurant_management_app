import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../registry/icon_registry.dart';
import '../registry/section_registry.dart';
import 'section_head_content.dart';

class StepItem {
  const StepItem({required this.icon, required this.title, required this.desc});

  factory StepItem.fromJson(J j) => StepItem(
        icon: IconRegistry.resolve(j.strOrNull('icon')),
        title: j.str('title'),
        desc: j.str('desc'),
      );

  final IconData icon;
  final String title;
  final String desc;
}

class StepsContent {
  const StepsContent({required this.head, required this.items});

  factory StepsContent.fromJson(J j) => StepsContent(
        head: HeadContent.fromJson(j),
        items: j.list('items', StepItem.fromJson).where((s) => s.title.isNotEmpty).toList(),
      );

  final HeadContent head;
  final List<StepItem> items;
}

final stepsDefinition = SectionDefinition(
  type: 'steps',
  label: 'How it works',
  builder: (context, SectionNode node) =>
      StepsSection(content: StepsContent.fromJson(node.content)),
);

class StepsSection extends StatelessWidget {
  const StepsSection({super.key, required this.content});

  final StepsContent content;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final steps = content.items;

    // The big "01" is the position, not stored: reordering steps renumbers them
    // instead of leaving "03, 01, 02".
    String number(int i) => (i + 1).toString().padLeft(2, '0');

    return Shell(
      child: Column(
        children: [
          SectionHead(
            eyebrow: content.head.eyebrow,
            title: content.head.title,
            lead: content.head.lead,
          ),
          SizedBox(height: mobile ? 40 : 60),
          if (mobile)
            Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _StepCard(step: steps[i], n: number(i)),
                  ),
              ],
            )
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Center(
                          child: Icon(Icons.arrow_forward_rounded, size: 18, color: LK.muted),
                        ),
                      ),
                    Expanded(child: _StepCard(step: steps[i], n: number(i))),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final StepItem step;
  final String n;
  const _StepCard({required this.step, required this.n});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: LK.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(step.icon, size: 20, color: LK.tealLift),
              ),
              const Spacer(),
              Text(
                n,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: LK.ink.withValues(alpha: 0.08),
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(step.title, style: LK.h3(context)),
          const SizedBox(height: 9),
          Text(step.desc, style: LK.small),
        ],
      ),
    );
  }
}
