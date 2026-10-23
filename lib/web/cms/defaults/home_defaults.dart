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
      'content': {
        'badge': 'Trusted by 500+ properties worldwide',
        'headline': 'Stop running your property on',
        'rotating': ['WhatsApp.', 'spreadsheets.', 'paper tickets.', 'phone calls.'],
        'body': 'Independent hotels and restaurants lose hours every day juggling '
            'check-ins on WhatsApp, menus on paper and finances in Excel. '
            'HotRest replaces all of it — one dashboard for every department.',
        'primary': {
          'label': 'Start free trial',
          'link': {'type': 'internal', 'value': '/signup'},
        },
        'secondary': {
          'label': 'Watch demo',
          'link': {'type': 'action', 'value': 'openDemo'},
        },
        'ticks': ['{trialDays}-day free trial', 'Full access', 'No credit card'],
        // An illustration, not live data: every figure is editable.
        'mock': {
          'url': 'app.hotrest.app/dashboard',
          'greeting': 'Good morning, Alex',
          'property': 'Grand Ocean Hotel',
          'liveLabel': 'Live',
          'kpis': [
            {'label': 'Occupancy', 'value': '87%', 'delta': '+6%'},
            {'label': "Today's revenue", 'value': '4,280', 'delta': '+12%'},
            {'label': 'Active orders', 'value': '12', 'delta': 'Now'},
          ],
          'chartTitle': 'Revenue · last 7 days',
          // Shaped like a real week: a midweek dip and a weekend peak.
          'bars': [0.42, 0.55, 0.38, 0.62, 0.78, 1.0, 0.86],
          'days': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          // 0 free, 1 occupied, 2 cleaning
          'rooms': [1, 1, 0, 2, 1, 0, 0, 1, 2, 0, 1, 1],
          'floats': [
            {
              'icon': 'qr_code_2_rounded',
              'tone': 'teal',
              'title': 'Guest checked in',
              'sub': 'via QR · 24 seconds',
            },
            {
              'icon': 'restaurant_rounded',
              'tone': 'navy',
              'title': 'Table 6 · order fired',
              'sub': 'sent to kitchen display',
            },
          ],
        },
      },
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
    {
      'id': 'features',
      'type': 'featureGrid',
      'anchor': 'features',
      'content': {
        'eyebrow': 'Features',
        'title': 'Everything you need to run a great property',
        'lead': 'Purpose-built for hotels and restaurants — not a bloated ERP. '
            "Every tool you need, none you don't.",
        'items': [
          {
            'icon': 'hotel_rounded',
            'title': 'Hotel management',
            'bullets': [
              'Room setup, types and availability',
              'Reservations and walk-in check-in/out',
              'Folio billing and payment tracking',
              'Housekeeping task management',
              'Occupancy and room status overview',
            ],
          },
          {
            'icon': 'point_of_sale_rounded',
            'title': 'Restaurant POS',
            'bullets': [
              'Table-side and counter ordering',
              'Live kitchen display system (KDS)',
              'Menu and category management',
              'Split bills and multiple payment modes',
              'Real-time sales analytics',
            ],
          },
          {
            'icon': 'qr_code_2_rounded',
            'title': 'Guest portal',
            'bullets': [
              'QR-based self check-in and check-out',
              'Room service ordering via phone',
              'Digital menus — no app download',
              'Booking lookup and stay details',
              'Direct messaging with front desk',
            ],
          },
          {
            'icon': 'palette_rounded',
            'title': 'White-label ready',
            'bullets': [
              'Custom brand colours and logo',
              'Property name on all guest screens',
              'Branded QR codes and menus',
              'No HotRest branding visible to guests',
              'Multi-property brand profiles',
            ],
          },
          {
            'icon': 'groups_rounded',
            'title': 'Staff and shifts',
            'bullets': [
              'Role-based access control',
              'Shift scheduling and clock-in/out',
              'Time tracking and attendance logs',
              'Staff invite via unique code',
              'Per-property permission management',
            ],
          },
          {
            'icon': 'insights_rounded',
            'title': 'Financial reports',
            'bullets': [
              'Daily revenue and expense summaries',
              'Invoice and folio export to PDF',
              'Occupancy rate tracking',
              'Restaurant sales breakdown',
              'Date-range custom reporting',
            ],
          },
        ],
      },
    },
    {
      'id': 'comparison',
      'type': 'comparison',
      'style': {'reveal': false},
      'content': {
        'eyebrow': 'Why HotRest',
        'title': 'How we compare',
        'lead': 'Traditional hotel software is expensive, slow to set up and '
            'missing key features. HotRest was built from the ground up '
            'for independent properties.',
        'columns': [
          {'name': 'HotRest', 'short': 'HotRest'},
          {'name': 'Traditional PMS', 'short': 'PMS'},
          {'name': 'Manual / spreadsheet', 'short': 'Manual'},
        ],
        'rows': [
          {
            'label': 'Starting price',
            // {starterPrice} is filled from the live Starter plan.
            'cells': ['Free / {starterPrice}', 'LKR 20,000+/mo', 'Ongoing hidden costs'],
          },
          {
            'label': 'Setup time',
            'cells': ['< 20 min', 'Days–weeks', 'Never done'],
          },
          {'label': 'Hotel + restaurant in one', 'cells': [true, false, false]},
          {'label': 'QR guest self-check-in', 'cells': [true, false, false]},
          {'label': 'Built-in kitchen display', 'cells': [true, false, false]},
          {'label': 'Digital guest menu', 'cells': [true, false, false]},
          {'label': 'Multi-property support', 'cells': [true, true, false]},
          {'label': 'White-label branding', 'cells': [true, false, false]},
          {'label': 'Free plan available', 'cells': [true, false, true]},
        ],
      },
    },
    {
      'id': 'testimonials',
      'type': 'testimonials',
      'content': {
        'eyebrow': 'Testimonials',
        'title': 'Loved by hospitality professionals',
        'items': [
          {
            'quote': 'HotRest cut our front-desk workload in half. Check-in used to take '
                'five minutes per guest — now guests self-check in via QR. The staff '
                'scheduling alone is worth every cent.',
            'name': 'Sarah Mitchell',
            'role': 'General Manager',
            'place': 'The Riverview Boutique Hotel',
          },
          {
            'quote': 'We run three properties and the multi-property dashboard is a '
                'game-changer. I can see revenue, occupancy and active restaurant '
                'orders for all locations in one screen.',
            'name': 'James Okonkwo',
            'role': 'Director of Operations',
            'place': 'Okonkwo Hospitality Group',
          },
          {
            'quote': 'Switching from our old PMS was painless. Onboarding took less than '
                '20 minutes, and the white-label guest portal means our branding is '
                "front and centre — not some software company's logo.",
            'name': 'Priya Ramaswamy',
            'role': 'Owner',
            'place': 'Serenity Suites & Restaurant',
          },
        ],
      },
    },
    {
      'id': 'pricing',
      'type': 'pricing',
      'anchor': 'pricing',
      'content': {
        'eyebrow': 'Pricing',
        'title': 'Simple, transparent pricing',
        // {trialDays} and {annualDiscountPct} are BillingFacts, not free text.
        'lead': 'Every plan starts with a {trialDays}-day free trial — full access to every '
            'feature, no credit card required. Upgrade anytime.',
        'flags': [
          {
            'icon': 'card_giftcard_rounded',
            'text': '{trialDays}-day free trial on every plan',
            'tone': 'teal',
          },
          {
            'icon': 'lock_clock_rounded',
            'text': 'Early-access rates locked in for life',
            'tone': 'amber',
          },
        ],
        'labels': {
          'monthly': 'Monthly',
          'annual': 'Annual',
          'annualBadge': 'Save {annualDiscountPct}%',
          'monthlyPeriod': '/month',
          'annualPeriod': '/mo, billed annually',
          'featuredBadge': 'Most popular',
          'cta': 'Start free trial',
          'enterpriseCta': 'Contact sales',
          'customPrice': 'Custom',
          'freePrice': 'Free',
          'currency': 'LKR',
          'emptyMessage': 'Pricing is being updated — please check back shortly.',
          'extras': {
            'all': ['Hotel + restaurant modules', 'Guest portal (QR check-in & menu)'],
            'paid': ['White-label branding'],
            'enterprise': ['Dedicated account manager', 'SLA & uptime guarantee'],
          },
        },
      },
    },
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
