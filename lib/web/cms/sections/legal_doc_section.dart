import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/site_providers.dart';
import '../model/json_reader.dart';
import '../model/link_target.dart';
import '../model/site_document.dart';
import '../model/tokens.dart';
import '../registry/section_registry.dart';
import '../render/link_action.dart';

// The legal pages predate the marketing palette and use the slate one; kept as
// it was so the pages look the same after the move.
const _text = Color(0xFF0F172A);
const _subtext = Color(0xFF64748B);
const _muted = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _accent = Color(0xFF0A7D77);

enum LegalBlockKind { paragraph, bullet }

class LegalBlock {
  const LegalBlock(this.kind, this.text);

  factory LegalBlock.fromJson(J j, Map<String, String> vars) => LegalBlock(
        j.str('kind') == 'bullet' ? LegalBlockKind.bullet : LegalBlockKind.paragraph,
        expandTokens(j.str('text'), vars),
      );

  final LegalBlockKind kind;
  final String text;
}

class LegalSectionContent {
  const LegalSectionContent({required this.heading, required this.blocks});

  factory LegalSectionContent.fromJson(J j, Map<String, String> vars) => LegalSectionContent(
        heading: expandTokens(j.str('heading'), vars),
        blocks: j.list('blocks', (b) => LegalBlock.fromJson(b, vars)).where((b) => b.text.isNotEmpty).toList(),
      );

  final String heading;
  final List<LegalBlock> blocks;
}

class LegalFooterLink {
  const LegalFooterLink({required this.label, required this.link});

  factory LegalFooterLink.fromJson(J j) =>
      LegalFooterLink(label: j.str('label'), link: LinkTarget.fromJson(j.obj('link')));

  final String label;
  final LinkTarget link;
}

class LegalDocContent {
  const LegalDocContent({
    required this.title,
    required this.updated,
    required this.updatedLabel,
    required this.backLabel,
    required this.copyright,
    required this.sections,
    required this.footerLinks,
  });

  /// [vars] fills placeholders the page itself does not know, such as the
  /// support address, which lives in the site settings.
  factory LegalDocContent.fromJson(J j, {Map<String, String> vars = const {}}) => LegalDocContent(
        title: expandTokens(j.str('title'), vars),
        updated: j.str('updated'),
        updatedLabel: j.str('updatedLabel', 'Last updated: {date}'),
        backLabel: j.str('backLabel', 'Back to Home'),
        copyright: expandTokens(j.str('copyright'), vars),
        sections: j
            .list('sections', (s) => LegalSectionContent.fromJson(s, vars))
            .where((s) => s.heading.isNotEmpty || s.blocks.isNotEmpty)
            .toList(),
        footerLinks: j.list('footerLinks', LegalFooterLink.fromJson).where((l) => l.label.isNotEmpty && !l.link.isNone).toList(),
      );

  final String title;

  /// "April 8, 2025": a date the admin states, not one derived from publishing,
  /// because it records when the legal text itself last changed.
  final String updated;

  /// "Last updated: {date}".
  final String updatedLabel;
  final String backLabel;
  final String copyright;
  final List<LegalSectionContent> sections;
  final List<LegalFooterLink> footerLinks;
}

final legalDocDefinition = SectionDefinition(
  type: 'legalDoc',
  label: 'Legal document',
  builder: (context, SectionNode node) => LegalDocSection(node: node),
);

/// The body of a legal page: title, date, numbered sections, links to the other
/// legal pages, copyright. The page chrome (top bar, scrolling) belongs to the
/// screen, so the studio preview can draw the same body without it.
class LegalDocSection extends ConsumerWidget {
  const LegalDocSection({super.key, required this.node, this.activeRoute});

  final SectionNode node;

  /// The route being shown, so its link in the footer reads as current.
  final String? activeRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = J.of(ref.watch(siteRawProvider('global:site')));
    final content = LegalDocContent.fromJson(
      node.content,
      vars: {'supportEmail': site.str('supportEmail')},
    );
    final mobile = MediaQuery.sizeOf(context).width < 768;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 20 : 40, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.title,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _text, letterSpacing: -0.5),
              ),
              if (content.updated.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(expandTokens(content.updatedLabel, {'date': content.updated}),
                    style: const TextStyle(color: _muted, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              const Divider(color: _border),
              const SizedBox(height: 32),
              for (final s in content.sections) _Section(content: s),
              const SizedBox(height: 64),
              const Divider(color: _border),
              const SizedBox(height: 20),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  for (final l in content.footerLinks)
                    _FooterLink(link: l, active: activeRoute != null && l.link.value == activeRoute),
                ],
              ),
              const SizedBox(height: 8),
              Text(content.copyright, style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.link, required this.active});

  final LegalFooterLink link;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: active ? null : () => runLink(context, link.link),
      style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero),
      child: Text(
        link.label,
        style: TextStyle(
          fontSize: 13,
          color: active ? _accent : _muted,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.content});

  final LegalSectionContent content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.heading.isNotEmpty) ...[
            Text(content.heading, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _text)),
            const SizedBox(height: 10),
          ],
          for (final b in content.blocks)
            b.kind == LegalBlockKind.bullet ? _Bullet(b.text) : _Body(b.text),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 14, color: _subtext, height: 1.7)),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: CircleAvatar(radius: 3, backgroundColor: _accent),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: _subtext, height: 1.7))),
          ],
        ),
      );
}
