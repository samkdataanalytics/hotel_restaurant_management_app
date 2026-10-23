/// The header and footer exactly as they shipped. The footer's "Features" and
/// "Pricing" links used to go to "/", which did nothing from the home page; they
/// are section links now, so they scroll.
const Map<String, Object?> kHeaderDefaults = {
  'schema': 1,
  'items': [
    {
      'label': 'Features',
      'link': {'type': 'anchor', 'value': 'features'},
    },
    {
      'label': 'Pricing',
      'link': {'type': 'anchor', 'value': 'pricing'},
    },
    {
      'label': 'Docs',
      'link': {'type': 'internal', 'value': '/help'},
    },
  ],
  'signIn': {
    'label': 'Sign in',
    'link': {'type': 'internal', 'value': '/login'},
  },
  'cta': {
    'label': 'Start free trial',
    'mobileLabel': 'Start free',
    'link': {'type': 'internal', 'value': '/signup'},
  },
};

const Map<String, Object?> kFooterDefaults = {
  'schema': 1,
  'tagline': 'The all-in-one hotel and restaurant management platform for modern '
      'hospitality teams.',
  'columns': [
    {
      'title': 'Product',
      'links': [
        {
          'label': 'Features',
          'link': {'type': 'anchor', 'value': 'features'},
        },
        {
          'label': 'Pricing',
          'link': {'type': 'anchor', 'value': 'pricing'},
        },
        {
          'label': 'Guest portal',
          'link': {'type': 'internal', 'value': '/help'},
        },
      ],
    },
    {
      'title': 'Company',
      'links': [
        {
          'label': 'Help centre',
          'link': {'type': 'internal', 'value': '/help'},
        },
        {
          'label': 'Terms of service',
          'link': {'type': 'internal', 'value': '/terms'},
        },
        {
          'label': 'Privacy policy',
          'link': {'type': 'internal', 'value': '/privacy'},
        },
      ],
    },
    {
      'title': 'Get started',
      'links': [
        {
          'label': 'Create account',
          'link': {'type': 'internal', 'value': '/signup'},
        },
        {
          'label': 'Sign in',
          'link': {'type': 'internal', 'value': '/login'},
        },
      ],
    },
  ],
  // {year} is today's year, filled when the page draws.
  'copyright': '© {year} HotRest. All rights reserved.',
  'legalLinks': [
    {
      'label': 'Terms',
      'link': {'type': 'internal', 'value': '/terms'},
    },
    {
      'label': 'Privacy',
      'link': {'type': 'internal', 'value': '/privacy'},
    },
    {
      'label': 'Returns',
      'link': {'type': 'internal', 'value': '/returns'},
    },
    {
      'label': 'Help',
      'link': {'type': 'internal', 'value': '/help'},
    },
  ],
};

/// Global theme: nothing overridden, so the site keeps its built-in type scale.
const Map<String, Object?> kThemeDefaults = {
  'schema': 1,
  'typography': {},
  'layout': {},
};

/// Site-wide settings: the contact address the legal text refers to, and the
/// optional WhatsApp chat button. The WhatsApp number is empty because the
/// button must only appear with a real number (a placeholder number once made it
/// open a dead link).
const Map<String, Object?> kSiteSettingsDefaults = {
  'schema': 1,
  'supportEmail': 'kasun@ideadeck.biz',
  'whatsappNumber': '',
  'whatsappMessage': "Hi! I'm interested in HotRest for my property.",
  'whatsappLabel': 'Chat with us',
};

/// The "Watch demo" tour and the "Contact sales" form, as they shipped.
const Map<String, Object?> kDialogsDefaults = {
  'schema': 1,
  'demo': {
    'title': 'See HotRest in action',
    'subtitle': 'What you get — out of the box, day one.',
    'closeLabel': 'Close',
    'cta': {
      'label': 'Start {trialDays}-day free trial — no credit card',
      'link': {'type': 'internal', 'value': '/signup'},
    },
    'tabs': [
      {
        'name': 'Hotel',
        'items': [
          {
            'icon': 'how_to_reg_rounded',
            'tone': 'blue',
            'title': 'One-click check-in',
            'desc': 'Front desk checks in a guest in under 10 seconds — folio auto-generated, room assigned, key ready.',
          },
          {
            'icon': 'king_bed_rounded',
            'tone': 'green',
            'title': 'Live room availability',
            'desc': 'Colour-coded room grid shows occupied, available and maintenance rooms in real time.',
          },
          {
            'icon': 'receipt_long_rounded',
            'tone': 'teal',
            'title': 'Instant folio billing',
            'desc': 'Auto-calculates room charges, extras and taxes — export to PDF with one click.',
          },
          {
            'icon': 'people_alt_rounded',
            'tone': 'purple',
            'title': 'Staff shift management',
            'desc': 'Assign and track shifts, clock-ins and attendance — no third-party HR tool needed.',
          },
        ],
      },
      {
        'name': 'Restaurant',
        'items': [
          {
            'icon': 'point_of_sale_rounded',
            'tone': 'teal',
            'title': 'Table-side ordering',
            'desc': 'Waiters take orders on any device — sent instantly to the kitchen display, no paper tickets.',
          },
          {
            'icon': 'kitchen_rounded',
            'tone': 'red',
            'title': 'Kitchen display system',
            'desc': 'KDS shows orders in real time, with timers and priority flags so chefs never miss a ticket.',
          },
          {
            'icon': 'splitscreen_rounded',
            'tone': 'green',
            'title': 'Split bills & payments',
            'desc': 'Split any bill by item or equally across guests — supports cash, card and mixed payments.',
          },
          {
            'icon': 'analytics_rounded',
            'tone': 'cyan',
            'title': 'Sales analytics',
            'desc': 'See your top-selling dishes, peak hours and daily revenue at a glance.',
          },
        ],
      },
      {
        'name': 'Guest Portal',
        'items': [
          {
            'icon': 'qr_code_2_rounded',
            'tone': 'green',
            'title': 'QR self check-in',
            'desc': 'Guests scan a QR at reception, fill in details on their phone and check in — no queue, no paperwork.',
          },
          {
            'icon': 'room_service_rounded',
            'tone': 'teal',
            'title': 'Room service on phone',
            'desc': 'Guests order food from their room by scanning a QR — the order goes straight to the kitchen.',
          },
          {
            'icon': 'restaurant_menu_rounded',
            'tone': 'blue',
            'title': 'Digital table menu',
            'desc': 'Diners scan a table QR, browse the menu and order — no app download required.',
          },
          {
            'icon': 'no_accounts_rounded',
            'tone': 'purple',
            'title': 'No app needed',
            'desc': 'Everything runs in the mobile browser. Guests do not install anything.',
          },
        ],
      },
    ],
  },
  'contact': {
    'title': 'Contact sales',
    'subtitle': "We'll get back to you within 24 hours.",
    'closeLabel': 'Close',
    'nameLabel': 'Full name',
    'companyLabel': 'Company / hotel group',
    'emailLabel': 'Work email',
    'phoneLabel': 'Phone number',
    'propertiesLabel': 'Number of properties',
    'messageLabel': 'Tell us about your needs',
    'submitLabel': 'Send request',
    'successTitle': 'Request received',
    'successBody': 'Thank you for reaching out. Our team will contact you within 1–2 '
        'business days to discuss your requirements.',
    'successClose': 'Close',
  },
};
