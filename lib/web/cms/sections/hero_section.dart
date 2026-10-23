import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../model/tokens.dart';
import '../registry/section_registry.dart';
import '../render/link_action.dart';
import 'cta_band_section.dart' show CtaButtonContent;
import 'product_mock.dart';

class HeroContent {
  const HeroContent({
    required this.badge,
    required this.headline,
    required this.rotating,
    required this.body,
    required this.primary,
    required this.secondary,
    required this.ticks,
    required this.mock,
  });

  factory HeroContent.fromJson(J j) => HeroContent(
        badge: expandTokens(j.str('badge')),
        headline: expandTokens(j.str('headline')),
        rotating: j.strings('rotating').where((w) => w.isNotEmpty).toList(),
        body: expandTokens(j.str('body')),
        primary: CtaButtonContent.fromJson(j.obj('primary')),
        secondary: CtaButtonContent.fromJson(j.obj('secondary')),
        ticks: j.strings('ticks').map(expandTokens).where((t) => t.isNotEmpty).toList(),
        // The window is optional: null hides it and the copy takes the width.
        mock: j.has('mock') ? ProductMockContent.fromJson(j.obj('mock')) : null,
      );

  /// Star-rated pill above the headline; empty hides it.
  final String badge;
  final String headline;

  /// Words that cycle after the headline. May be empty.
  final List<String> rotating;
  final String body;
  final CtaButtonContent primary;
  final CtaButtonContent secondary;
  final List<String> ticks;
  final ProductMockContent? mock;
}

final heroDefinition = SectionDefinition(
  type: 'hero',
  label: 'Hero',
  builder: (context, SectionNode node) =>
      HeroSection(content: HeroContent.fromJson(node.content)),
);

class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.content});

  final HeroContent content;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final tablet = LK.isTablet(context);
    final stacked = mobile || tablet;
    final mock = content.mock;
    final copy = _HeroCopy(content: content);

    return SizedBox(
      height: stacked ? null : 760,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                children: [
                  const Positioned.fill(child: GridLines(spacing: 64)),
                  const Positioned.fill(
                    child: MeshBackdrop(blobs: [
                      (at: Alignment(-0.85, -0.7), color: LK.tealPure, size: 720, opacity: 0.16),
                      (at: Alignment(1.1, -0.2), color: LK.navy, size: 820, opacity: 0.13),
                      (at: Alignment(0.2, 1.1), color: LK.tealPure, size: 560, opacity: 0.08),
                    ]),
                  ),
                  // Fades the grid out before it meets the next section, so the
                  // hero ends rather than being cut off.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white.withValues(alpha: 0.86),
                            LK.white,
                          ],
                          stops: const [0, 0.72, 1],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: LK.navHeight + (mobile ? 48 : 72),
              bottom: mobile ? 48 : 64,
            ),
            child: Shell(
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        copy,
                        if (mock != null) ...[
                          const SizedBox(height: 48),
                          ProductMock(content: mock),
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 50, child: copy),
                        if (mock != null) ...[
                          const SizedBox(width: 56),
                          Expanded(flex: 50, child: Center(child: ProductMock(content: mock))),
                        ] else
                          const Spacer(flex: 50),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.content});

  final HeroContent content;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final display = LK.display(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content.badge.isNotEmpty) ...[
          _RatingPill(text: content.badge),
          const SizedBox(height: 26),
        ],
        Text(content.headline, style: display),
        // The rotating noun does the work three static lines used to: it names
        // every tool being replaced without making the reader scan a list.
        // Taller than one line box on purpose: the word slides in from below,
        // and at exactly line height the descenders of "spreadsheets" get
        // shaved by the clip on the way up.
        if (content.rotating.isNotEmpty)
          SizedBox(
            height: display.fontSize! * display.height! * 1.22,
            child: Align(
              alignment: Alignment.centerLeft,
              child: WordCycler(
                items: content.rotating,
                style: display.copyWith(color: LK.teal),
              ),
            ),
          ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(content.body, style: LK.lead(context)),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (content.primary.label.isNotEmpty)
              CtaButton(
                label: content.primary.label,
                icon: Icons.arrow_forward_rounded,
                onTap: () => runLink(context, content.primary.link),
              ),
            if (content.secondary.label.isNotEmpty)
              GhostButton(
                label: content.secondary.label,
                icon: Icons.play_circle_outline_rounded,
                onTap: () => runLink(context, content.secondary.link),
              ),
          ],
        ),
        if (content.ticks.isNotEmpty) ...[
          const SizedBox(height: 28),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [for (final t in content.ticks) _TickItem(t)],
          ),
        ],
        if (mobile) const SizedBox(height: 4),
      ],
    );
  }
}

class _RatingPill extends StatelessWidget {
  final String text;
  const _RatingPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: LK.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: LK.line),
        boxShadow: [
          BoxShadow(
            color: LK.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.only(right: 2),
              child: Icon(Icons.star_rounded, size: 15, color: LK.amber),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: LK.micro.copyWith(color: LK.body, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickItem extends StatelessWidget {
  final String label;
  const _TickItem(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 16, color: LK.teal),
        const SizedBox(width: 7),
        Text(label, style: LK.micro.copyWith(color: LK.body, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
