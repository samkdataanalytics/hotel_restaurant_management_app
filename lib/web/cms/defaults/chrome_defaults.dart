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
