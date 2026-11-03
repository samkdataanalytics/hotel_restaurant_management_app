import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/link_target.dart';
import '../render/link_action.dart';
import 'header_content.dart';
import 'nav_item.dart';

/// The frosted top bar. Frosted rather than opaque: the hero's mesh stays faintly
/// visible underneath, which reads as depth instead of a bar sitting on top.
class SiteHeader extends StatelessWidget {
  const SiteHeader({super.key, required this.content, required this.scrolled});

  final HeaderContent content;
  final bool scrolled;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final signIn = content.signIn;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: scrolled ? 18 : 0, sigmaY: scrolled ? 18 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: LK.navHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: scrolled ? 0.82 : 0),
            border: Border(
              bottom: BorderSide(color: scrolled ? LK.line : Colors.transparent),
            ),
          ),
          child: Shell(
            child: Row(
              children: [
                _Wordmark(onTap: () => runLink(context, _home)),
                const Spacer(),
                if (!mobile) ...[
                  for (var i = 0; i < content.items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _NavLink(content.items[i].label, () => runLink(context, content.items[i].link)),
                  ],
                  if (signIn != null && signIn.visible) ...[
                    SizedBox(width: content.items.isEmpty ? 0 : 18),
                    _NavLink(signIn.label, () => runLink(context, signIn.link)),
                    const SizedBox(width: 12),
                  ] else if (content.items.isNotEmpty)
                    const SizedBox(width: 12),
                ],
                if (mobile && content.hasMenu) ...[
                  IconButton(
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.maybeOf(context)?.openEndDrawer(),
                    icon: const Icon(Icons.menu_rounded, color: LK.ink),
                  ),
                  const SizedBox(width: 6),
                ],
                if (content.cta.visible)
                  CtaButton(
                    label: mobile ? content.cta.mobileLabel : content.cta.label,
                    onTap: () => runLink(context, content.cta.link),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The logo links home. A constant rather than a document field: a logo that
  /// goes anywhere else is a surprise.
  static const _home = LinkTarget(LinkKind.internal, '/');
}

class _Wordmark extends StatelessWidget {
  final VoidCallback onTap;
  const _Wordmark({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Image.asset(
          'assets/images/hotrest_logo_new.png',
          height: 30,
          fit: BoxFit.contain,
          // The lockup already contains the wordmark, so no text beside it —
          // the old nav said "HotRest" twice, once as art and once as type.
          errorBuilder: (_, __, ___) => Text(
            'HotRest',
            style: LK.h3(context).copyWith(fontSize: 21, color: LK.navy),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Outfit',
              color: _hover ? LK.ink : LK.body,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// The phone menu: the same links, in a drawer.
class SiteHeaderDrawer extends StatelessWidget {
  const SiteHeaderDrawer({super.key, required this.content});

  final HeaderContent content;

  @override
  Widget build(BuildContext context) {
    final entries = <NavItem>[
      ...content.items,
      if (content.signIn != null && content.signIn!.visible) content.signIn!,
    ];

    return Drawer(
      backgroundColor: LK.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/hotrest_logo_new.png',
                    height: 28,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, color: LK.ink),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final e in entries)
                InkWell(
                  onTap: () {
                    Navigator.of(context).maybePop();
                    runLink(context, e.link);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      e.label,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: LK.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
