import 'billing_facts.dart';

/// Replaces `{token}` placeholders in copy with their current values.
///
/// Unknown tokens are left as written rather than blanked, so a typo shows up
/// on the page (and in the editor's preview) instead of silently vanishing.
String expandTokens(String text, [Map<String, String> extra = const {}]) {
  if (!text.contains('{')) return text;
  return text.replaceAllMapped(RegExp(r'\{([A-Za-z][A-Za-z0-9]*)\}'), (m) {
    final key = m[1]!;
    // Protected facts first: a caller-supplied value cannot redefine them.
    return BillingFacts.tokens[key] ?? extra[key] ?? (key == 'year' ? '${DateTime.now().year}' : null) ?? m[0]!;
  });
}
