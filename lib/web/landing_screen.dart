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

/// Section types the document can name. Sections still drawn by their original
/// widget are wrapped here and ignore their content; each moves into
/// `cms/sections/` and out of this list as it is converted to read its content.
SectionDefinition _legacy(String type, Widget Function() build) =>
    SectionDefinition(type: type, label: type, builder: (_, __) => build());

final _registry = SectionRegistry.of([
  _legacy('hero', () => const _Hero()),
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

// ─── Hero ────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final tablet = LK.isTablet(context);
    final stacked = mobile || tablet;

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
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroCopy(),
                        SizedBox(height: 48),
                        ProductMock(),
                      ],
                    )
                  : const Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 50, child: _HeroCopy()),
                        SizedBox(width: 56),
                        Expanded(flex: 50, child: Center(child: ProductMock())),
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
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final display = LK.display(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RatingPill(),
        const SizedBox(height: 26),
        Text('Stop running your property on', style: display),
        // The rotating noun does the work three static lines used to: it names
        // every tool being replaced without making the reader scan a list.
        // Taller than one line box on purpose: the word slides in from below,
        // and at exactly line height the descenders of "spreadsheets" get
        // shaved by the clip on the way up.
        SizedBox(
          height: display.fontSize! * display.height! * 1.22,
          child: Align(
            alignment: Alignment.centerLeft,
            child: WordCycler(
              items: const ['WhatsApp.', 'spreadsheets.', 'paper tickets.', 'phone calls.'],
              style: display.copyWith(color: LK.teal),
            ),
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Independent hotels and restaurants lose hours every day juggling '
            'check-ins on WhatsApp, menus on paper and finances in Excel. '
            'HotRest replaces all of it — one dashboard for every department.',
            style: LK.lead(context),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            CtaButton(
              label: 'Start free trial',
              icon: Icons.arrow_forward_rounded,
              onTap: () => context.go('/signup'),
            ),
            GhostButton(
              label: 'Watch demo',
              icon: Icons.play_circle_outline_rounded,
              onTap: () => showDialog(
                context: context,
                builder: (_) => const DemoDialog(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _TickItem('45-day free trial'),
            _TickItem('Full access'),
            _TickItem('No credit card'),
          ],
        ),
        if (mobile) const SizedBox(height: 4),
      ],
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill();

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
          Text(
            'Trusted by 500+ properties worldwide',
            style: LK.micro.copyWith(color: LK.body, fontWeight: FontWeight.w600),
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

/// Stylised product window used as the hero visual.
///
/// Drawn in Flutter rather than shipped as a screenshot: a real screenshot
/// would date the moment the panel changes, would need re-exporting per
/// breakpoint, and would carry whatever test data happened to be on screen.
class ProductMock extends StatelessWidget {
  const ProductMock({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: LK.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LK.line),
              boxShadow: [
                BoxShadow(
                  color: LK.navy.withValues(alpha: 0.13),
                  blurRadius: 60,
                  offset: const Offset(0, 28),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Window chrome
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: const BoxDecoration(
                    color: LK.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                    border: Border(bottom: BorderSide(color: LK.line)),
                  ),
                  child: Row(
                    children: [
                      for (final c in const [Color(0xFFFF5F57), Color(0xFFFEBC2E), Color(0xFF28C840)])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: LK.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: LK.line),
                          ),
                          alignment: Alignment.center,
                          child: Text('app.hotrest.app/dashboard',
                              style: LK.micro.copyWith(fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Good morning, Alex',
                                    style: LK.h3(context).copyWith(fontSize: 15)),
                                Text('Grand Ocean Hotel', style: LK.micro.copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: LK.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Live',
                                style: LK.micro.copyWith(
                                    fontSize: 10, color: LK.teal, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Expanded(child: _MiniKpi(label: 'Occupancy', value: '87%', delta: '+6%')),
                          SizedBox(width: 9),
                          Expanded(child: _MiniKpi(label: "Today's revenue", value: '4,280', delta: '+12%')),
                          SizedBox(width: 9),
                          Expanded(child: _MiniKpi(label: 'Active orders', value: '12', delta: 'Now')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _MiniChart(),
                      const SizedBox(height: 14),
                      const _MiniRooms(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Floating cards give the flat window depth and call out two
          // specifics the headline claims.
          if (!mobile) ...[
            const Positioned(
              left: -34,
              // Anchored from the bottom, not the top: the window's height
              // shifts with how the KPI labels wrap, so a top offset lands in
              // a different band at different widths — it was sitting on top
              // of the occupancy figure.
              bottom: 112,
              child: const _FloatCard(
                icon: Icons.qr_code_2_rounded,
                tint: LK.teal,
                title: 'Guest checked in',
                sub: 'via QR · 24 seconds',
              ),
            ),
            const Positioned(
              right: -26,
              bottom: 56,
              child: const _FloatCard(
                icon: Icons.restaurant_rounded,
                tint: LK.navy,
                title: 'Table 6 · order fired',
                sub: 'sent to kitchen display',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  const _MiniKpi({required this.label, required this.value, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LK.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: LK.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: LK.micro.copyWith(fontSize: 9.5)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: LK.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(delta,
              style: LK.micro.copyWith(
                  fontSize: 9.5, color: LK.teal, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart();

  // Shaped like a real week: a midweek dip and a weekend peak, so it reads as
  // data rather than decoration.
  static const _bars = [0.42, 0.55, 0.38, 0.62, 0.78, 1.0, 0.86];
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: LK.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: LK.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue · last 7 days', style: LK.micro.copyWith(fontSize: 9.5)),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < _bars.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 46 * _bars[i],
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                LK.tealPure,
                                LK.tealPure.withValues(alpha: 0.45),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_days[i], style: LK.micro.copyWith(fontSize: 8.5)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRooms extends StatelessWidget {
  const _MiniRooms();

  // 0 free, 1 occupied, 2 cleaning
  static const _state = [1, 1, 0, 2, 1, 0, 0, 1, 2, 0, 1, 1];

  @override
  Widget build(BuildContext context) {
    Color tint(int s) => switch (s) {
          1 => LK.navy,
          2 => LK.amber,
          _ => LK.teal,
        };

    return Row(
      children: [
        for (var i = 0; i < _state.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                color: tint(_state[i]).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: tint(_state[i]).withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FloatCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String sub;
  const _FloatCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: LK.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LK.line),
        boxShadow: [
          BoxShadow(
            color: LK.ink.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: tint),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: LK.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              Text(sub, style: LK.micro.copyWith(fontSize: 10.5)),
            ],
          ),
        ],
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
