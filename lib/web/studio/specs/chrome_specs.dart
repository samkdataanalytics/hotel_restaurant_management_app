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
