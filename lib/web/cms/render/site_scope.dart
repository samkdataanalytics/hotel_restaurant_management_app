import 'package:flutter/widgets.dart';

/// What is showing the page.
///
/// [public] is the real site. [preview] is the editor's live preview and [test]
/// is a widget test: in both, links and dialogs are inert, so clicking inside a
/// preview can never navigate the admin away, open a lead form, or submit
/// anything real. (The alternative — an iframe of `/` — cannot work: a signed-in
/// user is redirected away from `/`, and the iframe shares that session.)
enum SiteMode { public, preview, test }

class SiteScope extends InheritedWidget {
  const SiteScope({
    super.key,
    this.mode = SiteMode.public,
    this.onScrollTo,
    required super.child,
  });

  final SiteMode mode;

  /// Scrolls the page to an anchor. Provided by whoever owns the scroll view.
  final void Function(String anchor)? onScrollTo;

  /// True only on the real site.
  bool get live => mode == SiteMode.public;

  /// The nearest scope, or null when a widget is built outside one (a bare
  /// widget test). Outside a scope links behave as on the real site.
  static SiteScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SiteScope>();

  @override
  bool updateShouldNotify(SiteScope old) => mode != old.mode || onScrollTo != old.onScrollTo;
}
