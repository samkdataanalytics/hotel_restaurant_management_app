import '../model/json_reader.dart';
import '../model/link_target.dart';

/// One link in the header or footer: a label, where it goes, and whether it shows.
class NavItem {
  const NavItem({required this.label, required this.link, this.enabled = true});

  factory NavItem.fromJson(J j) => NavItem(
        label: j.str('label'),
        link: LinkTarget.fromJson(j.obj('link')),
        enabled: j.flag('enabled', true),
      );

  final String label;
  final LinkTarget link;

  /// Switched off, the item disappears from the page but stays in the document, so
  /// it can come back without being retyped. (Disabling "Docs" does not touch the
  /// /help page itself.)
  final bool enabled;

  /// Shown only when it has text and a destination: a link that goes nowhere is
  /// worse than none.
  bool get visible => enabled && label.trim().isNotEmpty && !link.isNone;
}
