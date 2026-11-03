import '../model/json_reader.dart';
import '../model/tokens.dart';
import 'nav_item.dart';

class FooterColumn {
  const FooterColumn({required this.title, required this.links});

  factory FooterColumn.fromJson(J j) => FooterColumn(
        title: j.str('title'),
        links: j.list('links', NavItem.fromJson).where((l) => l.visible).toList(),
      );

  final String title;
  final List<NavItem> links;
}

class FooterContent {
  const FooterContent({
    required this.tagline,
    required this.columns,
    required this.copyright,
    required this.legalLinks,
  });

  factory FooterContent.fromJson(J j) => FooterContent(
        tagline: j.str('tagline'),
        // A column with no visible links is dropped: a title over nothing is noise.
        columns: j
            .list('columns', FooterColumn.fromJson)
            .where((c) => c.title.isNotEmpty && c.links.isNotEmpty)
            .toList(),
        // {year} is filled at draw time, so the notice never goes stale.
        copyright: expandTokens(j.str('copyright'), {'year': '${DateTime.now().year}'}),
        legalLinks: j.list('legalLinks', NavItem.fromJson).where((l) => l.visible).toList(),
      );

  final String tagline;
  final List<FooterColumn> columns;
  final String copyright;
  final List<NavItem> legalLinks;
}
