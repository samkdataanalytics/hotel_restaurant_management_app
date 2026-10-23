import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../render/link_action.dart';
import 'footer_content.dart';
import 'nav_item.dart';

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key, required this.content, this.gap});

  final FooterContent content;

  /// Space above the footer. Defaults to the standard section gap.
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final cols = _columns(context);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: gap ?? LK.sectionGap(context)),
      padding: EdgeInsets.symmetric(vertical: mobile ? 48 : 64),
      decoration: const BoxDecoration(
        color: LK.white,
        border: Border(top: BorderSide(color: LK.line)),
      ),
      child: Shell(
        child: Column(
          children: [
            if (mobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Brand(tagline: content.tagline),
                  if (content.columns.isNotEmpty) ...[const SizedBox(height: 32), cols],
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: _Brand(tagline: content.tagline)),
                  const SizedBox(width: 40),
                  Expanded(flex: 5, child: cols),
                ],
              ),
            const SizedBox(height: 40),
            const Divider(height: 1, color: LK.line),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(content.copyright, style: LK.micro),
                Wrap(
                  spacing: 22,
                  children: [
                    for (final l in content.legalLinks) _FooterLink(l.label, () => runLink(context, l.link)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _columns(BuildContext context) => Wrap(
        spacing: 56,
        runSpacing: 28,
        children: [
          for (final c in content.columns) _Column(title: c.title, items: c.links),
        ],
      );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/hotrest_logo_new.png',
          height: 30,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text('HotRest', style: LK.h3(context).copyWith(color: LK.navy)),
        ),
        if (tagline.isNotEmpty) ...[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(tagline, style: LK.small),
          ),
        ],
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.title, required this.items});

  final String title;
  final List<NavItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Outfit',
            color: LK.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (final l in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FooterLink(l.label, () => runLink(context, l.link)),
          ),
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink(this.label, this.onTap);

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: LK.micro.copyWith(
            color: _hover ? LK.teal : LK.body,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
