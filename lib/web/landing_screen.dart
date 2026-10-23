
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'landing/landing_dialogs.dart';
import 'brand_kit.dart';
import 'cms/chrome/footer_content.dart';
import 'cms/chrome/header_content.dart';
import 'cms/chrome/site_footer.dart';
import 'cms/chrome/site_header.dart';
import 'cms/data/site_providers.dart';
import 'cms/defaults/site_defaults.dart';
import 'cms/registry/public_registry.dart';
import 'cms/model/json_reader.dart';
import 'cms/render/anchor_keys.dart';
import 'cms/render/site_renderer.dart';
import 'cms/render/site_scope.dart';

/// Public marketing site.
///
/// Composition only — tokens and atoms live in `brand_kit.dart`, and
/// the two lead-capture dialogs in `landing/landing_dialogs.dart`.
///
/// The dynamic parts are unchanged from the previous version: pricing comes
/// from `PlanService.getActivePlans()` rather than being hardcoded, the
/// comparison table reads the live starter price, and Contact Sales still posts
/// through `LeadService`.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final _scroll = ScrollController();
  static const _pageKey = 'page:home';

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
    // Published content when there is some, otherwise the page as it shipped.
    // Sections that fail to draw fall back to their bundled default one by one.
    final doc = ref.watch(siteDocumentProvider(_pageKey));
    final renderer = SiteRenderer(
      registry: publicRegistry,
      fallback: siteDefaultDocument(_pageKey),
      anchors: _anchors,
      theme: ref.watch(siteThemeProvider),
    );

    final header = HeaderContent.fromJson(J.of(ref.watch(siteRawProvider('global:header'))));
    final footer = FooterContent.fromJson(J.of(ref.watch(siteRawProvider('global:footer'))));

    return SiteScope(
      onScrollTo: _anchors.scrollTo,
      child: Scaffold(
        backgroundColor: LK.white,
        endDrawer: SiteHeaderDrawer(content: header),
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [
                  ...renderer.build(context, doc),
                  SiteFooter(content: footer),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SiteHeader(content: header, scrolled: _scrolled),
            ),
            const Positioned(bottom: 26, right: 26, child: WhatsAppFab()),
          ],
        ),
      ),
    );
  }
}
