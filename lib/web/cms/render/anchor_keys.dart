import 'package:flutter/widgets.dart';

/// Stable [GlobalKey]s for in-page anchors, handed out by name.
///
/// Whoever owns the scroll view keeps one of these for its lifetime, so a key
/// survives rebuilds and `scrollTo` can find the widget it belongs to.
class AnchorKeys {
  final _keys = <String, GlobalKey>{};

  GlobalKey keyFor(String anchor) => _keys.putIfAbsent(anchor, GlobalKey.new);

  /// Scrolls to [anchor] if its section is currently mounted. A hidden or
  /// disabled section has no context, and the call quietly does nothing.
  void scrollTo(String anchor) {
    final ctx = _keys[anchor]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: 0.02,
    );
  }
}
