import '../model/json_reader.dart';
import '../model/tokens.dart';

/// The eyebrow / title / lead block that opens most sections.
///
/// Shared so every section reads it the same way, and so the editor can offer
/// one "heading" field group instead of a variation per section.
class HeadContent {
  const HeadContent({this.eyebrow = '', this.title = '', this.lead});

  factory HeadContent.fromJson(J j) => HeadContent(
        eyebrow: expandTokens(j.str('eyebrow')),
        title: expandTokens(j.str('title')),
        lead: j.strOrNull('lead') == null ? null : expandTokens(j.str('lead')),
      );

  final String eyebrow;
  final String title;

  /// Null when the section has no lead paragraph, so the layout matches a
  /// section that never had one rather than reserving an empty gap.
  final String? lead;
}
