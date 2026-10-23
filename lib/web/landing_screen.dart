import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'landing/landing_dialogs.dart';
import 'brand_kit.dart';
import 'cms/defaults/home_defaults.dart';
import 'cms/registry/section_registry.dart';
import 'cms/render/anchor_keys.dart';
import 'cms/render/site_renderer.dart';
import 'cms/render/site_scope.dart';
import 'cms/sections/before_after_section.dart';
import 'cms/sections/comparison_section.dart';
import 'cms/sections/cta_band_section.dart';
import 'cms/sections/faq_section.dart';
import 'cms/sections/feature_grid_section.dart';
import 'cms/sections/hero_section.dart';
import 'cms/sections/stats_section.dart';
import 'cms/sections/pricing_section.dart';
import 'cms/sections/steps_section.dart';
import 'cms/sections/testimonials_section.dart';

/// Public marketing site.
///
/// Composition only — tokens and atoms live in `brand_kit.dart`, and
/// the two lead-capture dialogs in `landing/landing_dialogs.dart`.
///
/// The dynamic parts are unchanged from the previous version: pricing comes
/// from `PlanService.getActivePlans()` rather than being hardcoded, the
/// comparison table reads the live starter price, and Contact Sales still posts
/// through `LeadService`.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scroll = ScrollController();
  final _anchors = AnchorKeys();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = _scroll.offset > 24;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderer = SiteRenderer(
      registry: _registry,
      fallback: homeDefaults,
      anchors: _anchors,
    );

    return SiteScope(
      onScrollTo: _anchors.scrollTo,
      child: Scaffold(
        backgroundColor: LK.white,
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [
                  ...renderer.build(context, homeDefaults),
                  const _Footer(),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _Nav(
                scrolled: _scrolled,
                onFeatures: () => _anchors.scrollTo('features'),
                onPricing: () => _anchors.scrollTo('pricing'),
              ),
            ),
            const Positioned(bottom: 26, right: 26, child: WhatsAppFab()),
          ],
        ),
      ),
    );
  }
}

/// Section types the home page can name. Each reads its content from the
/// document; see `cms/sections/`.
final _registry = SectionRegistry.of([
  heroDefinition,
  statsDefinition,
  beforeAfterDefinition,
  stepsDefinition,
  featureGridDefinition,
  comparisonDefinition,
  testimonialsDefinition,
  pricingDefinition,
  faqDefinition,
  ctaBandDefinition,
]);

// ─── Navigation ──────────────────────────────────────────────────────────────

class _Nav extends StatelessWidget {
  final bool scrolled;
  final VoidCallback onFeatures;
  final VoidCallback onPricing;
  const _Nav({required this.scrolled, required this.onFeatures, required this.onPricing});

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);

    // Frosted rather than opaque: the hero's mesh stays faintly visible
    // underneath, which reads as depth instead of a bar sitting on top.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: scrolled ? 18 : 0, sigmaY: scrolled ? 18 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: LK.navHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: scrolled ? 0.82 : 0),
            border: Border(
              bottom: BorderSide(
                color: scrolled ? LK.line : Colors.transparent,
              ),
            ),
          ),
          child: Shell(
            child: Row(
              children: [
                _Wordmark(onTap: () => context.go('/')),
                const Spacer(),
                if (!mobile) ...[
                  _NavLink('Features', onFeatures),
                  const SizedBox(width: 4),
                  _NavLink('Pricing', onPricing),
                  const SizedBox(width: 4),
                  _NavLink('Docs', () => context.go('/help')),
                  const SizedBox(width: 18),
                  _NavLink('Sign in', () => context.go('/login')),
                  const SizedBox(width: 12),
                ],
                CtaButton(
                  label: mobile ? 'Start free' : 'Start free trial',
                  onTap: () => context.go('/signup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

// ─── Footer ──────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: LK.sectionGap(context)),
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
                  const _FooterBrand(),
                  const SizedBox(height: 32),
                  _footerCols(context),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(flex: 4, child: _FooterBrand()),
                  const SizedBox(width: 40),
                  Expanded(flex: 5, child: _footerCols(context)),
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
                const Text('© 2026 HotRest. All rights reserved.', style: LK.micro),
                Wrap(
                  spacing: 22,
                  children: [
                    _FooterLink('Terms', () => context.go('/terms')),
                    _FooterLink('Privacy', () => context.go('/privacy')),
                    _FooterLink('Returns', () => context.go('/returns')),
                    _FooterLink('Help', () => context.go('/help')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerCols(BuildContext context) => Wrap(
        spacing: 56,
        runSpacing: 28,
        children: [
          _FooterCol(
            title: 'Product',
            items: [
              ('Features', () => context.go('/')),
              ('Pricing', () => context.go('/')),
              ('Guest portal', () => context.go('/help')),
            ],
          ),
          _FooterCol(
            title: 'Company',
            items: [
              ('Help centre', () => context.go('/help')),
              ('Terms of service', () => context.go('/terms')),
              ('Privacy policy', () => context.go('/privacy')),
            ],
          ),
          _FooterCol(
            title: 'Get started',
            items: [
              ('Create account', () => context.go('/signup')),
              ('Sign in', () => context.go('/login')),
            ],
          ),
        ],
      );
}

class _FooterBrand extends StatelessWidget {
  const _FooterBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/hotrest_logo_new.png',
          height: 30,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Text('HotRest', style: LK.h3(context).copyWith(color: LK.navy)),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: const Text(
            'The all-in-one hotel and restaurant management platform for modern '
            'hospitality teams.',
            style: LK.small,
          ),
        ),
      ],
    );
  }
}

class _FooterCol extends StatelessWidget {
  final String title;
  final List<(String, VoidCallback)> items;
  const _FooterCol({required this.title, required this.items});

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
        for (final (label, tap) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FooterLink(label, tap),
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
