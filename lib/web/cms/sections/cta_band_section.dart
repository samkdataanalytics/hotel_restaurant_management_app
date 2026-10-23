import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/link_target.dart';
import '../model/site_document.dart';
import '../registry/section_registry.dart';
import '../render/link_action.dart';

class CtaButtonContent {
  const CtaButtonContent({required this.label, required this.link});

  factory CtaButtonContent.fromJson(J j) => CtaButtonContent(
        label: j.str('label'),
        link: LinkTarget.fromJson(j.obj('link')),
      );

  final String label;
  final LinkTarget link;
}

class CtaBandContent {
  const CtaBandContent({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
    required this.ticks,
  });

  factory CtaBandContent.fromJson(J j) => CtaBandContent(
        eyebrow: j.str('eyebrow'),
        title: j.str('title'),
        body: j.str('body'),
        primary: CtaButtonContent.fromJson(j.obj('primary')),
        secondary: CtaButtonContent.fromJson(j.obj('secondary')),
        ticks: j.strings('ticks').where((t) => t.isNotEmpty).toList(),
      );

  final String eyebrow;
  final String title;
  final String body;
  final CtaButtonContent primary;
  final CtaButtonContent secondary;
  final List<String> ticks;
}

final ctaBandDefinition = SectionDefinition(
  type: 'ctaBand',
  label: 'Call to action band',
  builder: (context, SectionNode node) =>
      CtaBandSection(content: CtaBandContent.fromJson(node.content)),
);

class CtaBandSection extends StatelessWidget {
  const CtaBandSection({super.key, required this.content});

  final CtaBandContent content;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);

    return Shell(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 26 : 56,
          vertical: mobile ? 48 : 72,
        ),
        decoration: BoxDecoration(
          color: LK.navy,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: const MeshBackdrop(blobs: [
                  (at: Alignment(-1.0, -1.0), color: LK.tealPure, size: 520, opacity: 0.35),
                  (at: Alignment(1.0, 1.2), color: LK.tealPure, size: 420, opacity: 0.22),
                ]),
              ),
            ),
            Column(
              children: [
                if (content.eyebrow.isNotEmpty) ...[
                  Eyebrow(content.eyebrow, onDark: true),
                  const SizedBox(height: 20),
                ],
                Text(
                  content.title,
                  textAlign: TextAlign.center,
                  style: LK.h2(context).copyWith(color: Colors.white),
                ),
                if (content.body.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      content.body,
                      textAlign: TextAlign.center,
                      style: LK.lead(context)
                          .copyWith(color: Colors.white.withValues(alpha: 0.72)),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (content.primary.label.isNotEmpty)
                      CtaButton(
                        label: content.primary.label,
                        icon: Icons.arrow_forward_rounded,
                        onDark: true,
                        onTap: () => runLink(context, content.primary.link),
                      ),
                    if (content.secondary.label.isNotEmpty)
                      GhostButton(
                        label: content.secondary.label,
                        onDark: true,
                        onTap: () => runLink(context, content.secondary.link),
                      ),
                  ],
                ),
                if (content.ticks.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 22,
                    runSpacing: 10,
                    children: [for (final t in content.ticks) _DarkTick(t)],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkTick extends StatelessWidget {
  final String label;
  const _DarkTick(this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 15, color: LK.tealLift),
          const SizedBox(width: 7),
          Text(label,
              style: LK.micro.copyWith(color: Colors.white.withValues(alpha: 0.7))),
        ],
      );
}
