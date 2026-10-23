import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'cms/data/site_providers.dart';
import 'cms/defaults/site_defaults.dart';
import 'cms/model/site_document.dart';
import 'cms/render/seo_scope.dart';
import 'cms/sections/help_topics_section.dart';

// Slate palette the help and legal pages keep (older than the marketing palette).
const _bg = Color(0xFFFFFFFF);
const _surface = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _sub = Color(0xFF64748B);
const _gold = Color(0xFF0A7D77);

/// The help centre. The topics, categories and wording come from the `page:help`
/// document; this widget supplies the page chrome and the "/" search shortcut.
class HelpScreen extends ConsumerStatefulWidget {
  /// When true (public /help route) shows a slim top-bar with a back-to-home link.
  final bool standalone;
  const HelpScreen({super.key, this.standalone = false});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _searchFocus = FocusNode();
  final _keyboardFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  SectionNode? _node(SiteDocument d) {
    for (final s in d.sections) {
      if (s.type == 'helpTopics' && s.enabled) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(siteDocumentProvider('page:help'));
    final node = _node(doc) ?? _node(siteDefaultDocument('page:help'));
    final content = node == null ? null : HelpContent.fromJson(node.content);

    return SeoScope(
        seo: doc.seo,
        fallbackTitle: 'Help centre — HotRest',
        child: KeyboardListener(
          focusNode: _keyboardFocus,
          autofocus: true,
          onKeyEvent: (e) {
            if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.slash) {
              _searchFocus.requestFocus();
            }
          },
          child: Scaffold(
            backgroundColor: _surface,
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.standalone) _buildStandaloneTopBar(content),
                  if (content != null)
                    HelpTopicsSection(content: content, searchFocus: _searchFocus),
                ],
              ),
            ),
          ),
        ));
  }

  // ── Standalone top bar (public /help route) ─────────────────────────────────

  Widget _buildStandaloneTopBar(HelpContent? content) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(children: [
        Image.asset('assets/images/hotrest_mark.png', width: 36, height: 36, fit: BoxFit.contain),
        const SizedBox(width: 10),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF0D9B94), _gold],
          ).createShader(bounds),
          child: const Text('HotRest', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded, size: 14, color: _sub),
          label: Text(content?.backLabel ?? 'Back to home',
              style: const TextStyle(color: _sub, fontSize: 13)),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _gold),
            foregroundColor: _gold,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(content?.signInLabel ?? 'Sign In',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
