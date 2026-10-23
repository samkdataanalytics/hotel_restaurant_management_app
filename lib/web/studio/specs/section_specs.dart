import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;

import '../../cms/render/type_scope.dart';
import 'field_spec.dart';

/// What the studio knows about one section type: its name, how it is added, and
/// the fields that edit its content.
class SectionSpec {
  const SectionSpec({
    required this.type,
    required this.label,
    required this.icon,
    required this.description,
    required this.fields,
    required this.template,
  });

  final String type;
  final String label;
  final IconData icon;

  /// One line shown in the "Add section" picker.
  final String description;
  final List<FieldSpec> fields;

  /// The `content` a new section of this type starts with. Real, usable copy
  /// rather than empty boxes, so a new section looks like something.
  final Map<String, Object?> template;
}

// ── Reusable pieces ─────────────────────────────────────────────────────────

const _head = [
  FieldSpec.text('eyebrow', 'Small label above the heading', maxLength: 60,
      help: 'The pill above the heading, e.g. "Features". Shown in capitals.'),
  FieldSpec.text('title', 'Heading', required: true, maxLength: 140, protectedTokens: true),
  FieldSpec.textarea('lead', 'Intro paragraph', maxLength: 500, protectedTokens: true,
      help: 'Optional line under the heading. Leave empty for none.'),
];

const _buttonFields = [
  FieldSpec.text('label', 'Button text', maxLength: 40, help: 'Leave empty to hide the button.'),
  FieldSpec.link('link', 'Where it goes'),
];

const _tones = {'teal': 'Teal', 'amber': 'Amber'};

// ── Sections ────────────────────────────────────────────────────────────────

const _hero = SectionSpec(
  type: 'hero',
  label: 'Hero',
  icon: Icons.web_asset_rounded,
  description: 'The big opening: headline, buttons and a product window.',
  fields: [
    FieldSpec.text('badge', 'Badge above the headline',
        maxLength: 80,
        help: 'The star-rated pill. Leave empty to hide it.',
        verify: 'Claims a customer count and a rating. Confirm these before publishing.'),
    FieldSpec.text('headline', 'Headline', required: true, maxLength: 80),
    FieldSpec.stringList('rotating', 'Rotating words',
        itemLabel: 'word',
        maxItems: 8,
        maxLength: 24,
        help: 'These cycle after the headline. Leave empty for a static headline.'),
    FieldSpec.textarea('body', 'Body text', required: true, maxLength: 400),
    FieldSpec.group('primary', 'Main button', _buttonFields),
    FieldSpec.group('secondary', 'Second button', _buttonFields),
    FieldSpec.stringList('ticks', 'Checklist under the buttons',
        itemLabel: 'point', maxItems: 5, maxLength: 40, protectedTokens: true),
    FieldSpec.group(
      'mock',
      'Product window',
      [
        FieldSpec.text('url', 'Address bar text', maxLength: 60,
            verify: 'Shows "app.hotrest.app", which is not a real host. Use the real address.'),
        FieldSpec.text('greeting', 'Greeting', maxLength: 40),
        FieldSpec.text('property', 'Property name', maxLength: 40),
        FieldSpec.text('liveLabel', '"Live" badge', maxLength: 12),
        FieldSpec.list('kpis', 'Figures', [
          FieldSpec.text('label', 'Label', maxLength: 24),
          FieldSpec.text('value', 'Value', maxLength: 12),
          FieldSpec.text('delta', 'Change', maxLength: 10),
        ],
            itemTitleKey: 'label',
            itemLabel: 'figure',
            maxItems: 3,
            template: {'label': 'New figure', 'value': '0', 'delta': ''}),
        FieldSpec.text('chartTitle', 'Chart title', maxLength: 40),
        FieldSpec.numberList('bars', 'Chart bars',
            help: 'Heights from 0 to 1, one per day.', maxItems: 14),
        FieldSpec.stringList('days', 'Chart labels', itemLabel: 'label', maxItems: 14, maxLength: 4),
        FieldSpec.numberList('rooms', 'Room strip',
            min: 0,
            max: 2,
            step: 1,
            help: '0 = free, 1 = occupied, 2 = being cleaned.',
            maxItems: 24),
        FieldSpec.list('floats', 'Floating callouts', [
          FieldSpec.icon('icon', 'Icon'),
          FieldSpec.choice('tone', 'Colour', {'teal': 'Teal', 'navy': 'Navy'}),
          FieldSpec.text('title', 'Title', maxLength: 40),
          FieldSpec.text('sub', 'Detail', maxLength: 40),
        ],
            itemTitleKey: 'title',
            itemLabel: 'callout',
            maxItems: 2,
            template: {'icon': 'check_circle_rounded', 'tone': 'teal', 'title': 'Title', 'sub': 'Detail'}),
      ],
      help: 'The illustrated dashboard. Everything in it is made up for illustration.',
      optional: true,
    ),
  ],
  template: {
    'headline': 'Your headline here',
    'rotating': <String>[],
    'body': 'One or two sentences about what you offer.',
    'primary': {
      'label': 'Start free trial',
      'link': {'type': 'internal', 'value': '/signup'},
    },
    'secondary': {'label': '', 'link': {}},
    'ticks': <String>[],
  },
);

const _stats = SectionSpec(
  type: 'stats',
  label: 'Stats strip',
  icon: Icons.bar_chart_rounded,
  description: 'A row of headline numbers.',
  fields: [
    FieldSpec.list(
      'items',
      'Figures',
      [
        FieldSpec.number('value', 'Number', max: 1000000000, step: 0.1),
        FieldSpec.text('suffix', 'After the number', maxLength: 8, help: 'e.g. "+", "K+", "%".'),
        FieldSpec.number('decimals', 'Decimal places', min: 0, max: 3),
        FieldSpec.text('label', 'Label', required: true, maxLength: 40),
      ],
      itemTitleKey: 'label',
      itemLabel: 'figure',
      maxItems: 6,
      template: {'value': 100, 'suffix': '+', 'decimals': 0, 'label': 'New figure'},
      verify: 'These figures are claims (customers, bookings, uptime, rating). '
          'Only publish numbers you can show evidence for.',
    ),
  ],
  template: {
    'items': [
      {'value': 100, 'suffix': '+', 'decimals': 0, 'label': 'Label'},
    ],
  },
);

const _beforeAfter = SectionSpec(
  type: 'beforeAfter',
  label: 'Before / after',
  icon: Icons.compare_rounded,
  description: 'Two panels: life without and with the product.',
  fields: [
    ..._head,
    FieldSpec.group('before', 'Before panel', [
      FieldSpec.text('title', 'Panel title', maxLength: 40),
      FieldSpec.stringList('items', 'Points', itemLabel: 'point', maxItems: 10),
    ]),
    FieldSpec.group('after', 'After panel', [
      FieldSpec.text('title', 'Panel title', maxLength: 40),
      FieldSpec.stringList('items', 'Points',
          itemLabel: 'point',
          maxItems: 10,
          verify: 'Includes specific promises ("4+ hours a day", "under 30 seconds"). '
              'Confirm them.'),
    ]),
  ],
  template: {
    'eyebrow': 'The difference',
    'title': 'Before and after',
    'before': {'title': 'Before', 'items': ['A problem']},
    'after': {'title': 'After', 'items': ['A solution']},
  },
);

const _steps = SectionSpec(
  type: 'steps',
  label: 'Steps',
  icon: Icons.format_list_numbered_rounded,
  description: 'Numbered steps showing how it works.',
  fields: [
    ..._head,
    FieldSpec.list(
      'items',
      'Steps',
      [
        FieldSpec.icon('icon', 'Icon'),
        FieldSpec.text('title', 'Title', required: true, maxLength: 60),
        FieldSpec.textarea('desc', 'Description', maxLength: 300),
      ],
      itemTitleKey: 'title',
      itemLabel: 'step',
      maxItems: 6,
      template: {'icon': 'check_circle_rounded', 'title': 'New step', 'desc': ''},
    ),
  ],
  template: {
    'eyebrow': 'How it works',
    'title': 'Three simple steps',
    'items': [
      {'icon': 'apartment_rounded', 'title': 'Step one', 'desc': 'Describe it.'},
      {'icon': 'dashboard_rounded', 'title': 'Step two', 'desc': 'Describe it.'},
      {'icon': 'trending_up_rounded', 'title': 'Step three', 'desc': 'Describe it.'},
    ],
  },
);

const _featureGrid = SectionSpec(
  type: 'featureGrid',
  label: 'Feature grid',
  icon: Icons.grid_view_rounded,
  description: 'Cards, each with an icon and a bulleted list.',
  fields: [
    ..._head,
    FieldSpec.list(
      'items',
      'Cards',
      [
        FieldSpec.icon('icon', 'Icon'),
        FieldSpec.text('title', 'Title', required: true, maxLength: 50),
        FieldSpec.stringList('bullets', 'Bullet points',
            itemLabel: 'point',
            maxItems: 8,
            verify: 'One bullet promises "Direct messaging with front desk"; no messaging screen '
                'was found in the product. Confirm it exists.'),
      ],
      itemTitleKey: 'title',
      itemLabel: 'card',
      maxItems: 12,
      template: {
        'icon': 'check_circle_rounded',
        'title': 'New card',
        'bullets': ['A benefit'],
      },
    ),
  ],
  template: {
    'eyebrow': 'Features',
    'title': 'What you get',
    'items': [
      {
        'icon': 'hotel_rounded',
        'title': 'A feature',
        'bullets': ['A benefit', 'Another benefit'],
      },
    ],
  },
);

const _comparison = SectionSpec(
  type: 'comparison',
  label: 'Comparison table',
  icon: Icons.table_chart_rounded,
  description: 'You versus the alternatives, row by row.',
  fields: [
    ..._head,
    FieldSpec.list(
      'columns',
      'Columns',
      [
        FieldSpec.text('name', 'Name', required: true, maxLength: 30),
        FieldSpec.text('short', 'Short name (phones)', maxLength: 12),
      ],
      itemTitleKey: 'name',
      itemLabel: 'column',
      maxItems: 4,
      minItems: 1,
      help: 'The first column is yours and is highlighted.',
      template: {'name': 'Alternative', 'short': 'Alt'},
    ),
    FieldSpec.list(
      'rows',
      'Rows',
      [
        FieldSpec.text('label', 'Row label', required: true, maxLength: 60),
        FieldSpec.cells('cells', 'Cells',
            help: 'A tick, a dash or text for each column. '
                '{starterPrice} is replaced by the live Starter plan price.'),
      ],
      itemTitleKey: 'label',
      itemLabel: 'row',
      maxItems: 20,
      template: {'label': 'New row', 'cells': <Object>[]},
      verify: '"LKR 20,000+/mo" for traditional software and "Free plan available" are claims '
          'to check. There is no free plan any more.',
    ),
  ],
  template: {
    'eyebrow': 'Why us',
    'title': 'How we compare',
    'columns': [
      {'name': 'Us', 'short': 'Us'},
      {'name': 'Others', 'short': 'Others'},
    ],
    'rows': [
      {'label': 'A feature', 'cells': [true, false]},
    ],
  },
);

const _testimonials = SectionSpec(
  type: 'testimonials',
  label: 'Testimonials',
  icon: Icons.format_quote_rounded,
  description: 'Customer quotes.',
  fields: [
    ..._head,
    FieldSpec.list(
      'items',
      'Quotes',
      [
        FieldSpec.textarea('quote', 'Quote', required: true, maxLength: 500),
        FieldSpec.text('name', 'Name', maxLength: 60),
        FieldSpec.text('role', 'Role', maxLength: 60),
        FieldSpec.text('place', 'Business', maxLength: 80),
        FieldSpec.text('initials', 'Initials', maxLength: 3,
            help: 'Leave empty to use the first and last letter of the name.'),
      ],
      itemTitleKey: 'name',
      itemLabel: 'quote',
      maxItems: 9,
      template: {'quote': 'What a customer said.', 'name': 'Name', 'role': 'Role', 'place': 'Business'},
      verify: 'These quotes and the people named in them have not been confirmed as real '
          'customers. Publish only quotes you have permission to use.',
    ),
  ],
  template: {
    'eyebrow': 'Testimonials',
    'title': 'What customers say',
    'items': [
      {'quote': 'What a customer said.', 'name': 'Name', 'role': 'Role', 'place': 'Business'},
    ],
  },
);

const _pricing = SectionSpec(
  type: 'pricing',
  label: 'Pricing',
  icon: Icons.sell_rounded,
  description: 'Plan cards from the Plans screen.',
  fields: [
    ..._head,
    FieldSpec.list(
      'flags',
      'Badges under the heading',
      [
        FieldSpec.icon('icon', 'Icon'),
        FieldSpec.text('text', 'Text', required: true, maxLength: 60, protectedTokens: true),
        FieldSpec.choice('tone', 'Colour', _tones),
      ],
      itemTitleKey: 'text',
      itemLabel: 'badge',
      maxItems: 4,
      template: {'icon': 'check_circle_rounded', 'text': 'A badge', 'tone': 'teal'},
    ),
    FieldSpec.group('labels', 'Labels', [
      FieldSpec.text('monthly', 'Monthly tab', maxLength: 16),
      FieldSpec.text('annual', 'Annual tab', maxLength: 16),
      FieldSpec.text('annualBadge', 'Annual saving badge', maxLength: 40, protectedTokens: true,
          help: 'Use {annualDiscountPct} for the discount so it always matches the checkout.'),
      FieldSpec.text('monthlyPeriod', 'After a monthly price', maxLength: 16),
      FieldSpec.text('annualPeriod', 'After an annual price', maxLength: 30),
      FieldSpec.text('featuredBadge', '"Most popular" label', maxLength: 20),
      FieldSpec.text('cta', 'Plan button', maxLength: 30),
      FieldSpec.text('enterpriseCta', 'Custom-plan button', maxLength: 30),
      FieldSpec.text('customPrice', 'Custom price word', maxLength: 16),
      FieldSpec.text('freePrice', 'Zero price word', maxLength: 16),
      FieldSpec.text('currency', 'Currency', maxLength: 6),
      FieldSpec.text('emptyMessage', 'Message when no plans load', maxLength: 120),
      FieldSpec.group('extras', 'Extra lines on each card', [
        FieldSpec.stringList('all', 'On every plan', itemLabel: 'line'),
        FieldSpec.stringList('paid', 'On paid plans only', itemLabel: 'line'),
        FieldSpec.stringList('enterprise', 'On custom-price plans only',
            itemLabel: 'line',
            verify: '"Dedicated account manager" and "SLA & uptime guarantee" are commitments. '
                'Confirm you offer them.'),
      ]),
    ]),
  ],
  template: {
    'eyebrow': 'Pricing',
    'title': 'Simple, transparent pricing',
    'lead': 'Every plan starts with a {trialDays}-day free trial.',
    'flags': <Object>[],
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
      'extras': {'all': <String>[], 'paid': <String>[], 'enterprise': <String>[]},
    },
  },
);

const _faq = SectionSpec(
  type: 'faq',
  label: 'FAQ',
  icon: Icons.help_outline_rounded,
  description: 'Questions that open to show the answer.',
  fields: [
    ..._head,
    FieldSpec.list(
      'items',
      'Questions',
      [
        FieldSpec.text('q', 'Question', required: true, maxLength: 160, protectedTokens: true),
        FieldSpec.textarea('a', 'Answer', maxLength: 1500, protectedTokens: true),
      ],
      itemTitleKey: 'q',
      itemLabel: 'question',
      maxItems: 30,
      template: {'q': 'A question?', 'a': 'The answer.'},
      verify: 'Some answers state plan limits ("Pro supports up to three properties") that no '
          'longer match the live plans, and one says "SOC 2 aligned". Check each against the '
          'Plans screen and your actual compliance.',
    ),
  ],
  template: {
    'eyebrow': 'FAQ',
    'title': 'Frequently asked questions',
    'items': [
      {'q': 'A question?', 'a': 'The answer.'},
    ],
  },
);

const _ctaBand = SectionSpec(
  type: 'ctaBand',
  label: 'Call-to-action band',
  icon: Icons.campaign_rounded,
  description: 'A dark band with a heading and two buttons.',
  fields: [
    FieldSpec.text('eyebrow', 'Small label', maxLength: 60),
    FieldSpec.text('title', 'Heading', required: true, maxLength: 100),
    FieldSpec.textarea('body', 'Body text', maxLength: 400, protectedTokens: true,
        verify: 'Says "hundreds of hospitality teams". Confirm.'),
    FieldSpec.group('primary', 'Main button', _buttonFields),
    FieldSpec.group('secondary', 'Second button', _buttonFields),
    FieldSpec.stringList('ticks', 'Trust points',
        itemLabel: 'point',
        maxItems: 5,
        maxLength: 40,
        verify: '"SOC 2 compliant", "GDPR ready" and "24/7 support" are compliance and service '
            'claims. Only keep the ones that are true today.'),
  ],
  template: {
    'eyebrow': 'Get started',
    'title': 'Ready to begin?',
    'body': 'Start your free trial today.',
    'primary': {
      'label': 'Create free account',
      'link': {'type': 'internal', 'value': '/signup'},
    },
    'secondary': {
      'label': 'Sign in',
      'link': {'type': 'internal', 'value': '/login'},
    },
    'ticks': <String>[],
  },
);

const _richText = SectionSpec(
  type: 'richText',
  label: 'Text block',
  icon: Icons.notes_rounded,
  description: 'A heading and paragraphs, with bold, links and bullets.',
  fields: [
    FieldSpec.text('eyebrow', 'Small label', maxLength: 60),
    FieldSpec.text('title', 'Heading', maxLength: 140),
    FieldSpec.textarea('body', 'Text',
        maxLength: 12000,
        protectedTokens: true,
        help: 'Blank line = new paragraph. "## Title" = sub-heading. "- item" = bullet. '
            '**bold**, *italic*, [label](/page or https://…) for links.'),
    FieldSpec.choice('align', 'Alignment', {'left': 'Left', 'center': 'Centred'}, defaultValue: 'left'),
    FieldSpec.choice('width', 'Width', {'narrow': 'Narrow (reading)', 'wide': 'Wide'},
        defaultValue: 'narrow'),
  ],
  template: {
    'title': 'A heading',
    'body': 'Write something here.\n\nA second paragraph.',
    'align': 'left',
    'width': 'narrow',
  },
);

const _imageText = SectionSpec(
  type: 'imageText',
  label: 'Image and text',
  icon: Icons.view_agenda_rounded,
  description: 'A picture beside a heading, text and a button.',
  fields: [
    FieldSpec.text('eyebrow', 'Small label', maxLength: 60),
    FieldSpec.text('title', 'Heading', maxLength: 140),
    FieldSpec.textarea('body', 'Text', maxLength: 4000, protectedTokens: true),
    FieldSpec.image('image', 'Image',
        help: 'Pick from the media library. Alt text is read by screen readers.'),
    FieldSpec.choice('imageSide', 'Image side', {'right': 'Right', 'left': 'Left'}, defaultValue: 'right'),
    FieldSpec.group('cta', 'Button', _buttonFields),
  ],
  template: {
    'title': 'A heading',
    'body': 'Describe what the picture shows.',
    'imageSide': 'right',
    'image': {'url': '', 'alt': ''},
    'cta': {'label': '', 'link': {}},
  },
);

const _spacer = SectionSpec(
  type: 'spacer',
  label: 'Spacer',
  icon: Icons.space_bar_rounded,
  description: 'Empty vertical space.',
  fields: [
    FieldSpec.responsive('height', 'Height', max: 400),
  ],
  template: {
    'height': {'desktop': 48},
  },
);

/// Every section type the studio can edit, in the order "Add section" lists them.
const List<SectionSpec> kSectionSpecs = [
  _hero,
  _stats,
  _beforeAfter,
  _steps,
  _featureGrid,
  _comparison,
  _testimonials,
  _pricing,
  _faq,
  _ctaBand,
  _richText,
  _imageText,
  _spacer,
];

final Map<String, SectionSpec> kSectionSpecByType = {for (final s in kSectionSpecs) s.type: s};

// ── Settings every section shares ────────────────────────────────────────────


/// Layout tab. Paths are relative to the section's `layout` object.
const List<FieldSpec> kLayoutFields = [
  FieldSpec.choice('spaceBefore', 'Space above', {'section': 'Standard gap', 'none': 'None (flush)'},
      defaultValue: 'section', help: 'The gap between this section and the one before it.'),
  FieldSpec.responsive('paddingTop', 'Extra padding above',
      help: 'Added inside the section, on top of the standard gap.'),
  FieldSpec.responsive('paddingBottom', 'Extra padding below'),
  FieldSpec.number('maxWidth', 'Content width', min: 640, max: 1600, step: 10, unit: 'px',
      help: 'Narrows or widens the content column. Empty = the site default (1180).'),
];

/// Style tab. Paths are relative to the section's `style` object.
const List<FieldSpec> kStyleFields = [
  FieldSpec.color('background', 'Background colour',
      help: 'Fills the whole width of the section. Empty = none.'),
  FieldSpec.toggle('reveal', 'Fade in as it scrolls into view', defaultValue: true),
];

/// Typography tab. Paths are relative to the section's `typography` object.
const List<FieldSpec> kTypographyFields = [
  FieldSpec.responsive('display', 'Display size (hero headline)', min: 10, max: 120, unit: 'px'),
  FieldSpec.responsive('heading', 'Heading size', min: 10, max: 120, unit: 'px'),
  FieldSpec.responsive('subheading', 'Card title size', min: 10, max: 120, unit: 'px'),
  FieldSpec.responsive('lead', 'Intro text size', min: 10, max: 120, unit: 'px'),
  FieldSpec.choice('headingFont', 'Heading font', FontCatalog.labels,
      help: 'Only fonts bundled with the site are offered.'),
  FieldSpec.choice('bodyFont', 'Intro text font', FontCatalog.labels),
  FieldSpec.color('headingColor', 'Heading colour'),
  FieldSpec.color('bodyColor', 'Intro text colour'),
];

