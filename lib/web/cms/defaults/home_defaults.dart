import '../model/site_document.dart';

/// The home page exactly as it shipped before the CMS: the document the site
/// renders when nothing has been published, and the starting point for the
/// editor's "initialise from live site".
///
/// Kept in Dart rather than an asset file so it is available on the first
/// frame. An asset needs an async load, which would put a flash of nothing in
/// front of a page that already cold-starts slowly, and would force every widget
/// test to set up an asset bundle.
///
/// Order, spacing and fade-in are data here as well as content: hero and the
/// stats strip sit flush (`spaceBefore: none`) and neither fades; the comparison
/// table does not fade either. Those are the page's existing behaviour, written
/// down so the renderer reproduces it rather than hardcoding it.
const Map<String, Object?> kHomeDefaults = {
  'schema': 1,
  'sections': [
    {
      'id': 'hero',
      'type': 'hero',
      'layout': {'spaceBefore': 'none'},
      'style': {'reveal': false},
      'content': {},
    },
    {
      'id': 'stats',
      'type': 'stats',
      'layout': {'spaceBefore': 'none'},
      'style': {'reveal': false},
      'content': {},
    },
    {'id': 'before-after', 'type': 'beforeAfter', 'content': {}},
    {'id': 'how-it-works', 'type': 'steps', 'content': {}},
    {'id': 'features', 'type': 'featureGrid', 'anchor': 'features', 'content': {}},
    {
      'id': 'comparison',
      'type': 'comparison',
      'style': {'reveal': false},
      'content': {},
    },
    {'id': 'testimonials', 'type': 'testimonials', 'content': {}},
    {'id': 'pricing', 'type': 'pricing', 'anchor': 'pricing', 'content': {}},
    {
      'id': 'faq',
      'type': 'faq',
      'content': {
        'eyebrow': 'FAQ',
        'title': 'Frequently asked questions',
        'items': [
          {
            'q': 'Do you offer a free trial?',
            'a': 'Yes. Every new account starts with a 45-day free trial with full access '
                'to every feature — properties, rooms, restaurant tables, staff accounts '
                'and the guest portal. No credit card required to start.',
          },
          {
            'q': 'Can I manage multiple properties?',
            'a': 'Absolutely. Our Pro plan supports up to three properties, and the '
                'Enterprise plan offers unlimited properties with a dedicated account '
                'manager.',
          },
          {
            'q': 'Do guests need to download an app?',
            'a': 'No. The guest portal works entirely via QR code in any mobile browser. '
                'Guests can check in, browse the restaurant menu, order room service and '
                'check out — all from their phone.',
          },
          {
            'q': 'How secure is guest and payment data?',
            'a': 'HotRest is built on enterprise-grade infrastructure with row-level '
                'security, encrypted data at rest and in transit, and GDPR-ready data '
                'handling.',
          },
          {
            'q': 'Can I white-label the guest portal?',
            'a': 'Yes, on Pro and Enterprise plans. You can set your own logo, brand '
                'colours and property name. Guests see your brand — not ours.',
          },
          {
            'q': 'Can I cancel or downgrade anytime?',
            'a': 'Of course. There are no long-term contracts. You can upgrade, downgrade '
                'or cancel your plan at any time from account settings.',
          },
        ],
      },
    },
    {'id': 'final-cta', 'type': 'ctaBand', 'content': {}},
  ],
};

/// Parsed once; documents are immutable.
final SiteDocument homeDefaults = SiteDocument.fromJson(kHomeDefaults);
