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
      'content': {
        'items': [
          {'value': 500, 'suffix': '+', 'decimals': 0, 'label': 'Properties'},
          {'value': 50, 'suffix': 'K+', 'decimals': 0, 'label': 'Bookings managed'},
          {'value': 99.9, 'suffix': '%', 'decimals': 1, 'label': 'Uptime SLA'},
          {'value': 4.9, 'suffix': '', 'decimals': 1, 'label': 'Average rating'},
        ],
      },
    },
    {
      'id': 'before-after',
      'type': 'beforeAfter',
      'content': {
        'eyebrow': 'The difference',
        'title': 'Life before and after HotRest',
        'lead': "Sound familiar? You're not alone. Most independent hotels and "
            'restaurants operate the same way — until they find HotRest.',
        'before': {
          'title': 'Before HotRest',
          'items': [
            'WhatsApp and phone calls for every booking',
            'Spreadsheets that break during peak hours',
            'Paper order tickets lost in the kitchen',
            'Staff asking each other what to do next',
            'Hours wasted on manual data entry daily',
            'Guests waiting 10 minutes to check in',
          ],
        },
        'after': {
          'title': 'With HotRest',
          'items': [
            'One dashboard for front desk, kitchen and finance',
            'Real-time sync across all departments',
            'Digital kitchen display — zero lost tickets',
            'Every staff member knows their tasks instantly',
            'Save 4+ hours of admin work every single day',
            'Guests self-check-in in under 30 seconds',
          ],
        },
      },
    },
    {
      'id': 'how-it-works',
      'type': 'steps',
      'content': {
        'eyebrow': 'How it works',
        'title': 'Up and running in under 20 minutes',
        'lead': 'No consultants. No training sessions. Just sign up and go.',
        'items': [
          {
            'icon': 'apartment_rounded',
            'title': 'Set up your property',
            'desc': 'Add your hotel details, configure room types, build your restaurant '
                'menu, and invite staff — all in one onboarding flow.',
          },
          {
            'icon': 'dashboard_rounded',
            'title': 'Manage everything',
            'desc': 'Check guests in, process restaurant orders, track shifts and monitor '
                'occupancy from one unified dashboard.',
          },
          {
            'icon': 'trending_up_rounded',
            'title': 'Grow your business',
            'desc': 'Use built-in analytics to optimise pricing, spot peak periods and '
                'make data-driven decisions that increase revenue.',
          },
        ],
      },
    },
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
    {
      'id': 'final-cta',
      'type': 'ctaBand',
      'content': {
        'eyebrow': 'Get started in under 5 minutes',
        'title': 'Ready to transform your property?',
        'body': 'Join hundreds of hospitality teams already running smarter with '
            'HotRest. Start your 45-day free trial — full access, no credit '
            'card required.',
        'primary': {
          'label': 'Create free account',
          'link': {'type': 'internal', 'value': '/signup'},
        },
        'secondary': {
          'label': 'Sign in',
          'link': {'type': 'internal', 'value': '/login'},
        },
        'ticks': ['SOC 2 compliant', 'GDPR ready', '24/7 support'],
      },
    },
  ],
};

/// Parsed once; documents are immutable.
final SiteDocument homeDefaults = SiteDocument.fromJson(kHomeDefaults);
