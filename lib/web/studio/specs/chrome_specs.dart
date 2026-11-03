import 'field_spec.dart';
import 'section_specs.dart';

const _link = FieldSpec.link('link', 'Where it goes');

/// One header link. Switching "Show" off hides it without deleting it.
const _navItem = [
  FieldSpec.text('label', 'Text', required: true, maxLength: 24),
  _link,
  FieldSpec.toggle('enabled', 'Show', defaultValue: true),
];

const List<FieldSpec> kHeaderFields = [
  FieldSpec.list(
    'items',
    'Menu links',
    _navItem,
    itemTitleKey: 'label',
    itemLabel: 'link',
    maxItems: 8,
    template: {
      'label': 'New link',
      'link': {'type': 'internal', 'value': '/help'},
    },
    help: 'Shown in the top bar on desktop and in the menu on phones.',
  ),
  FieldSpec.group('signIn', 'Sign-in link', _navItem, optional: true),
  FieldSpec.group('cta', 'Main button', [
    FieldSpec.text('label', 'Button text', maxLength: 24, help: 'Leave empty to hide the button.'),
    FieldSpec.text('mobileLabel', 'Short text on phones', maxLength: 16,
        help: 'The phone header has less room. Empty = use the full text.'),
    _link,
  ]),
];

const List<FieldSpec> kFooterFields = [
  FieldSpec.textarea('tagline', 'Tagline under the logo', maxLength: 200),
  FieldSpec.list(
    'columns',
    'Link columns',
    [
      FieldSpec.text('title', 'Column title', required: true, maxLength: 24),
      FieldSpec.list(
        'links',
        'Links',
        _navItem,
        itemTitleKey: 'label',
        itemLabel: 'link',
        maxItems: 10,
        template: {
          'label': 'New link',
          'link': {'type': 'internal', 'value': '/help'},
        },
      ),
    ],
    itemTitleKey: 'title',
    itemLabel: 'column',
    maxItems: 5,
    template: {'title': 'New column', 'links': <Object>[]},
  ),
  FieldSpec.text('copyright', 'Copyright line',
      maxLength: 120, help: '{year} becomes the current year, so it never goes stale.'),
  FieldSpec.list(
    'legalLinks',
    'Bottom links',
    _navItem,
    itemTitleKey: 'label',
    itemLabel: 'link',
    maxItems: 8,
    template: {
      'label': 'New link',
      'link': {'type': 'internal', 'value': '/terms'},
    },
  ),
];

/// Page search-result and tab-title text.
const List<FieldSpec> kSeoFields = [
  FieldSpec.text('title', 'Page title', maxLength: 70,
      help: 'The browser tab title, and the headline in search results. Empty = "HotRest".'),
  FieldSpec.textarea('description', 'Description', maxLength: 170,
      help: 'The grey text under the title in search results. Aim for under 160 characters.'),
];

/// Typography at the page or theme level: the same fields a section offers.
const List<FieldSpec> kThemeTypographyFields = kTypographyFields;

const List<FieldSpec> kThemeLayoutFields = [
  FieldSpec.number('maxWidth', 'Content width', min: 640, max: 1600, step: 10, unit: 'px',
      help: 'The width of the content column on every page. Empty = 1180.'),
  FieldSpec.responsive('sectionGap', 'Gap between sections',
      max: 320, help: 'Replaces the standard gap (128 px on desktop, 72 on phones).'),
];

/// Site-wide settings (`global:site`).
const List<FieldSpec> kSiteFields = [
  FieldSpec.divider('Contact'),
  FieldSpec.text('supportEmail', 'Support email', maxLength: 120,
      help: 'Shown on the legal pages wherever the text says {supportEmail}.'),
  FieldSpec.divider('WhatsApp chat button'),
  FieldSpec.text('whatsappNumber', 'WhatsApp number', maxLength: 15,
      placeholder: '94771234567',
      help: 'International format, digits only: no +, spaces or dashes. Leave empty to hide the '
          'button. It only appears when this is a real number.'),
  FieldSpec.text('whatsappMessage', 'First message', maxLength: 200,
      help: 'Pre-filled in the chat when a visitor taps the button.'),
  FieldSpec.text('whatsappLabel', 'Label on hover', maxLength: 30),
];

/// The "Watch demo" tour and the "Contact sales" form (`global:dialogs`).
const List<FieldSpec> kDialogFields = [
  FieldSpec.group('demo', 'Watch-demo dialog', [
    FieldSpec.text('title', 'Title', required: true, maxLength: 60),
    FieldSpec.text('subtitle', 'Line under the title', maxLength: 100),
    FieldSpec.text('closeLabel', 'Close button hint', maxLength: 20),
    FieldSpec.list(
      'tabs',
      'Tabs',
      [
        FieldSpec.text('name', 'Tab name', required: true, maxLength: 24),
        FieldSpec.list(
          'items',
          'Highlights',
          [
            FieldSpec.icon('icon', 'Icon'),
            FieldSpec.choice('tone', 'Colour', {
              'blue': 'Blue',
              'green': 'Green',
              'teal': 'Teal',
              'purple': 'Purple',
              'red': 'Red',
              'cyan': 'Cyan',
            }),
            FieldSpec.text('title', 'Title', required: true, maxLength: 40),
            FieldSpec.textarea('desc', 'Description', maxLength: 200,
                verify: 'Contains specific performance claims ("under 10 seconds"). Confirm them.'),
          ],
          itemTitleKey: 'title',
          itemLabel: 'highlight',
          maxItems: 8,
          template: {'icon': 'check_circle_rounded', 'tone': 'teal', 'title': 'New highlight', 'desc': ''},
        ),
      ],
      itemTitleKey: 'name',
      itemLabel: 'tab',
      minItems: 1,
      maxItems: 5,
      template: {'name': 'New tab', 'items': <Object>[]},
    ),
    FieldSpec.group('cta', 'Button at the bottom', [
      FieldSpec.text('label', 'Button text', maxLength: 60, protectedTokens: true,
          help: 'Use {trialDays} for the trial length. Leave empty to hide the button.'),
      FieldSpec.link('link', 'Where it goes'),
    ]),
  ]),
  FieldSpec.group('contact', 'Contact-sales form', [
    FieldSpec.text('title', 'Title', required: true, maxLength: 60),
    FieldSpec.text('subtitle', 'Line under the title', maxLength: 100),
    FieldSpec.text('closeLabel', 'Close button hint', maxLength: 20),
    FieldSpec.text('nameLabel', 'Name field', maxLength: 40),
    FieldSpec.text('companyLabel', 'Company field', maxLength: 40),
    FieldSpec.text('emailLabel', 'Email field', maxLength: 40),
    FieldSpec.text('phoneLabel', 'Phone field', maxLength: 40),
    FieldSpec.text('propertiesLabel', 'Properties field', maxLength: 40),
    FieldSpec.text('messageLabel', 'Message field', maxLength: 60),
    FieldSpec.text('submitLabel', 'Send button', maxLength: 30),
    FieldSpec.text('successTitle', 'After sending: heading', maxLength: 60),
    FieldSpec.textarea('successBody', 'After sending: text', maxLength: 300),
    FieldSpec.text('successClose', 'After sending: button', maxLength: 30),
  ]),
];
