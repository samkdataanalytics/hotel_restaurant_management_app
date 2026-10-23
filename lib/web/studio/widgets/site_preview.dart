import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../../cms/chrome/footer_content.dart';
import '../../cms/chrome/header_content.dart';
import '../../cms/chrome/site_footer.dart';
import '../../cms/chrome/site_header.dart';
import '../../cms/defaults/site_defaults.dart';
import '../../cms/model/site_document.dart';
import '../../cms/model/site_theme.dart';
import '../../cms/registry/public_registry.dart';
import '../../cms/render/anchor_keys.dart';
import '../../cms/render/site_renderer.dart';
import '../../cms/render/site_scope.dart';
import '../studio_theme.dart';

/// Simulated viewport widths. They straddle the site's real breakpoints
/// (`< 768` mobile, `< 1100` tablet), so each one exercises a different layout.
const kDeviceWidth = {
  Device.desktop: 1280.0,
  Device.tablet: 900.0,
  Device.mobile: 390.0,
};

/// The live page, drawn by the real section widgets at a chosen width.
///
/// Not an iframe of the site: a signed-in user is redirected away from `/`, and
/// an iframe would share that session. This builds the same widgets in-process,
/// with links and dialogs switched off ([SiteMode.preview]) so a click can only
/// ever select, never navigate or submit anything.
class SitePreview extends StatelessWidget {
  const SitePreview({
    super.key,
    required this.doc,
    required this.device,
    this.theme = SiteTheme.none,
    this.header,
    this.footer,
    this.selectedId,
    this.onSelect,
    this.onSelectChrome,
  });

  final SiteDocument doc;
  final Device device;
  final SiteTheme theme;
  final HeaderContent? header;
  final FooterContent? footer;
  final String? selectedId;
  final ValueChanged<String>? onSelect;

  /// Tapping the header or footer, to jump to the navigation workspace.
  final VoidCallback? onSelectChrome;

  @override
  Widget build(BuildContext context) {
    final width = kDeviceWidth[device]!;

    return LayoutBuilder(builder: (context, box) {
      final scale = math.min(1.0, (box.maxWidth - 24) / width);
      // The page is laid out at its true width and height, then scaled to fit, so
      // media queries inside see the simulated device and not the studio window.
      final height = box.maxHeight / scale;

      return Center(
        child: Container(
          width: width * scale,
          height: box.maxHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: SC.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: Size(width, height)),
                child: _Page(
                  doc: doc,
                  theme: theme,
                  header: header,
                  footer: footer,
                  selectedId: selectedId,
                  onSelect: onSelect,
                  onSelectChrome: onSelectChrome,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _Page extends StatefulWidget {
  const _Page({
    required this.doc,
    required this.theme,
    required this.header,
    required this.footer,
    required this.selectedId,
    required this.onSelect,
    required this.onSelectChrome,
  });

  final SiteDocument doc;
  final SiteTheme theme;
  final HeaderContent? header;
  final FooterContent? footer;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final VoidCallback? onSelectChrome;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final _anchors = AnchorKeys();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderer = SiteRenderer(
      registry: publicRegistry,
      anchors: _anchors,
      theme: widget.theme,
      wrap: (ctx, node, built) => _Selectable(
        selected: node.id == widget.selectedId,
        label: publicRegistry[node.type]?.label ?? node.type,
        onTap: () => widget.onSelect?.call(node.id),
        child: built,
      ),
    );

    return SiteScope(
      mode: SiteMode.preview,
      child: Material(
        color: LK.white,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [
                  ...renderer.build(context, widget.doc),
                  if (widget.footer != null)
                    _ChromeTap(onTap: widget.onSelectChrome, child: SiteFooter(content: widget.footer!)),
                ],
              ),
            ),
            if (widget.header != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ChromeTap(
                  onTap: widget.onSelectChrome,
                  child: SiteHeader(content: widget.header!, scrolled: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Selects a section on any pointer-down inside it, including on buttons and
/// links. A `Listener` rather than a tap handler: the section's own buttons win
/// the gesture arena, and a click on one must still select its section.
class _Selectable extends StatefulWidget {
  const _Selectable({required this.selected, required this.label, required this.onTap, required this.child});

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Selectable> createState() => _SelectableState();
}

class _SelectableState extends State<_Selectable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final show = widget.selected || _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => widget.onTap(),
        child: Stack(
          children: [
            widget.child,
            if (show)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.selected ? SC.accent : SC.accent.withValues(alpha: 0.45),
                        width: widget.selected ? 3 : 2,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.selected)
              Positioned(
                top: 0,
                left: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    color: SC.accent,
                    child: Text(widget.label,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChromeTap extends StatelessWidget {
  const _ChromeTap({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => onTap?.call(),
        child: child,
      );
}

/// Convenience for callers that hold raw JSON.
SiteDocument previewDocument(Map<String, dynamic> raw, String key) {
  final doc = SiteDocument.fromJson(raw);
  final hadSections = raw['sections'] is List && (raw['sections'] as List).isNotEmpty;
  // An editor with every section invalid should still show something to fix.
  return doc.sections.isEmpty && hadSections ? siteDefaultDocument(key) : doc;
}
