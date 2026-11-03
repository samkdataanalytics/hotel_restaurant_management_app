import '../model/json_reader.dart';
import '../model/link_target.dart';
import 'nav_item.dart';

class HeaderCta {
  const HeaderCta({required this.label, required this.mobileLabel, required this.link});

  factory HeaderCta.fromJson(J j) {
    final label = j.str('label');
    return HeaderCta(
      label: label,
      // The phone header has less room; fall back to the full label if no short
      // one is given.
      mobileLabel: j.strOrNull('mobileLabel') ?? label,
      link: LinkTarget.fromJson(j.obj('link')),
    );
  }

  final String label;
  final String mobileLabel;
  final LinkTarget link;

  bool get visible => label.trim().isNotEmpty && !link.isNone;
}

class HeaderContent {
  const HeaderContent({required this.items, required this.signIn, required this.cta});

  factory HeaderContent.fromJson(J j) => HeaderContent(
        items: j.list('items', NavItem.fromJson).where((i) => i.visible).toList(),
        signIn: j.has('signIn') ? NavItem.fromJson(j.obj('signIn')) : null,
        cta: HeaderCta.fromJson(j.obj('cta')),
      );

  final List<NavItem> items;
  final NavItem? signIn;
  final HeaderCta cta;

  /// Whether the phone header needs a menu button.
  bool get hasMenu => items.isNotEmpty || (signIn?.visible ?? false);
}
