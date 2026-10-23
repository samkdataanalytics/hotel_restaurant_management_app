import 'package:flutter/widgets.dart';

import '../model/json_reader.dart';
import '../platform/page_meta.dart';

/// Applies a page's SEO title and description while it is on screen, and puts the
/// site default back when it leaves, so a stale title never follows the visitor to
/// the next page.
class SeoScope extends StatefulWidget {
  const SeoScope({super.key, required this.seo, this.fallbackTitle = 'HotRest', required this.child});

  /// The document's `seo` object: `{title, description}`.
  final J seo;
  final String fallbackTitle;
  final Widget child;

  static const defaultTitle = 'HotRest';

  @override
  State<SeoScope> createState() => _SeoScopeState();
}

class _SeoScopeState extends State<SeoScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  @override
  void didUpdateWidget(SeoScope old) {
    super.didUpdateWidget(old);
    _apply();
  }

  void _apply() {
    final title = widget.seo.strOrNull('title')?.trim();
    setPageMeta(
      title: title == null || title.isEmpty ? widget.fallbackTitle : title,
      description: widget.seo.strOrNull('description')?.trim(),
    );
  }

  @override
  void dispose() {
    setPageMeta(title: SeoScope.defaultTitle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
