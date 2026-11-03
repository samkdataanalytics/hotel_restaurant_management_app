import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'cms/data/site_providers.dart';
import 'cms/defaults/site_defaults.dart';
import 'cms/model/json_reader.dart';
import 'cms/model/site_document.dart';
import 'cms/render/seo_scope.dart';
import 'cms/sections/legal_doc_section.dart';

// Slate palette the legal and help pages keep (older than the marketing palette).
const _bg = Color(0xFFFFFFFF);
const _border = Color(0xFFE2E8F0);
const _gold = Color(0xFF0A7D77);
const _goldLight = Color(0xFF0D9B94);
const _subtext = Color(0xFF64748B);

enum LegalPage { terms, returns, privacy }

extension LegalPageX on LegalPage {
  /// The document this page reads (`page:terms`, …).
  String get key => 'page:$name';

  String get route => switch (this) {
        LegalPage.terms => '/terms',
        LegalPage.returns => '/returns',
        LegalPage.privacy => '/privacy',
      };
}

/// A legal page: the site's top bar, and the page's text from its document.
///
/// The text, dates and links are content (edited in the studio); this widget only
/// supplies the chrome. If the published document is missing or unusable, the
/// text as it shipped is shown instead.
class LegalScreen extends ConsumerWidget {
  final LegalPage page;
  const LegalScreen({super.key, required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final doc = ref.watch(siteDocumentProvider(page.key));
    final node = _legalNode(doc) ?? _legalNode(siteDefaultDocument(page.key));
    final back =
        node == null ? 'Back to Home' : J.of(node.content.raw).str('backLabel', 'Back to Home');

    return SeoScope(
        seo: doc.seo,
        fallbackTitle: 'HotRest',
        child: Scaffold(
          backgroundColor: _bg,
          body: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: 20),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Image.asset('assets/images/hotrest_mark.png',
                            width: 34, height: 34, fit: BoxFit.contain),
                        const SizedBox(width: 8),
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (b) =>
                              const LinearGradient(colors: [_goldLight, _gold]).createShader(b),
                          child: const Text('HotRest',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        ),
                      ]),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: _subtext),
                      label: Text(back, style: const TextStyle(color: _subtext, fontSize: 13)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    ),
                  ],
                ),
              ),

              // ── Scrollable content ───────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: node == null
                      ? const SizedBox.shrink()
                      : LegalDocSection(node: node, activeRoute: page.route),
                ),
              ),
            ],
          ),
        ));
  }

  SectionNode? _legalNode(SiteDocument d) {
    for (final s in d.sections) {
      if (s.type == 'legalDoc' && s.enabled) return s;
    }
    return null;
  }
}
