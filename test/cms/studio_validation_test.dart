import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/defaults/site_defaults.dart';
import 'package:hotel_checkin/web/studio/specs/section_specs.dart';
import 'package:hotel_checkin/web/studio/studio_state.dart';
import 'package:hotel_checkin/web/studio/studio_validation.dart';

Map<String, dynamic> _page(List<Map<String, dynamic>> sections) => {'schema': 1, 'sections': sections};

Map<String, dynamic> _faq(String title, {String id = 'faq', Map<String, dynamic> extra = const {}}) => {
      'id': id,
      'type': 'faq',
      'content': {
        'title': title,
        'items': [
          {'q': 'Q', 'a': 'A'}
        ],
      },
      ...extra,
    };

List<String> _errors(Map<String, dynamic> doc) =>
    validateSiteDocument('page:home', doc).where((i) => i.isError).map((i) => i.message).toList();

List<String> _warnings(Map<String, dynamic> doc) =>
    validateSiteDocument('page:home', doc).where((i) => !i.isError).map((i) => i.message).toList();

void main() {
  group('the shipped page', () {
    test('the bundled home page has no errors, so it can be published as it is', () {
      expect(_errors(siteDefaultJson('page:home')), isEmpty);
    });

    test('every section type has a spec and a valid template', () {
      for (final spec in kSectionSpecs) {
        final doc = _page([
          {'id': spec.type, 'type': spec.type, 'content': spec.template},
        ]);
        expect(_errors(doc), isEmpty, reason: spec.type);
      }
    });

    test('every default section has a spec', () {
      for (final s in siteDefaultDocument('page:home').sections) {
        expect(kSectionSpecByType.containsKey(s.type), isTrue, reason: s.type);
      }
    });
  });

  group('structure', () {
    test('duplicate ids', () {
      final e = _errors(_page([_faq('A'), _faq('B')]));
      expect(e.any((m) => m.contains('share the id')), isTrue);
    });

    test('an unknown type is a warning, not a publish blocker', () {
      final doc = _page([
        {'id': 'x', 'type': 'carousel3d', 'content': {}},
      ]);
      expect(_errors(doc), isEmpty);
      expect(_warnings(doc).single, contains('unknown type'));
    });

    test('anchors must be well-formed and unique', () {
      expect(_errors(_page([_faq('A', extra: {'anchor': 'Bad Anchor!'})])).single, contains('anchor'));
      final dup = _errors(_page([
        _faq('A', id: 'a', extra: {'anchor': 'x'}),
        _faq('B', id: 'b', extra: {'anchor': 'x'}),
      ]));
      expect(dup.single, contains('used by another section'));
    });

    test('an empty page is a warning', () {
      expect(_warnings(_page([])).single, contains('no sections'));
    });

    test('oversized documents are refused before the database would', () {
      final big = _page([
        {
          'id': 'r',
          'type': 'richText',
          'content': {'body': 'x' * 250000},
        },
      ]);
      expect(_errors(big).any((m) => m.contains('too large')), isTrue);
    });

    test('non-page documents only get the size check', () {
      expect(validateSiteDocument('global:theme', {'typography': {}}), isEmpty);
    });
  });

  group('fields', () {
    test('required text', () {
      expect(_errors(_page([_faq('')])).single, contains('required'));
      expect(_errors(_page([_faq('   ')])).single, contains('required'));
    });

    test('length limits', () {
      expect(_errors(_page([_faq('x' * 141)])).single, contains('limit is 140'));
    });

    test('wrong types are reported rather than thrown', () {
      final doc = _page([
        {
          'id': 'f',
          'type': 'faq',
          'content': {'title': 5, 'items': 'nope'},
        },
      ]);
      final e = _errors(doc);
      expect(e.any((m) => m.contains('must be text')), isTrue);
      expect(e.any((m) => m.contains('must be a list')), isTrue);
    });

    test('unknown icons and choices', () {
      final doc = _page([
        {
          'id': 's',
          'type': 'steps',
          'content': {
            'title': 'T',
            'items': [
              {'icon': 'rocket_ship', 'title': 'x', 'desc': ''}
            ],
          },
        },
      ]);
      expect(_errors(doc).single, contains('icon "rocket_ship" does not exist'));

      final c = _page([
        _faq('A', extra: {'typography': {'headingFont': 'Comic Sans'}}),
      ]);
      expect(_errors(c).single, contains('not one of the choices'));
    });

    test('colours must be hex', () {
      final e = _errors(_page([
        _faq('A', extra: {'style': {'background': 'blue'}}),
      ]));
      expect(e.single, contains('not a colour'));
      expect(_errors(_page([_faq('A', extra: {'style': {'background': '#fff'}})])), isEmpty);
    });

    test('numbers and per-device sizes are range-checked', () {
      final e = _errors(_page([
        _faq('A', extra: {'typography': {'heading': {'desktop': 9000, 'mobile': 2}}}),
      ]));
      expect(e.length, 2);
    });

    test('list item counts', () {
      final e = _errors(_page([
        {
          'id': 'h',
          'type': 'hero',
          'content': {
            'headline': 'H',
            'body': 'b',
            'mock': {
              'floats': [
                {'title': 'a'},
                {'title': 'b'},
                {'title': 'c'}
              ],
            },
          },
        },
      ]));
      expect(e.any((m) => m.contains('limit is 2')), isTrue);
    });

    test('comparison needs at least one column', () {
      final e = _errors(_page([
        {
          'id': 'c',
          'type': 'comparison',
          'content': {'title': 'T', 'columns': <Object>[], 'rows': <Object>[]},
        },
      ]));
      expect(e.any((m) => m.contains('at least 1')), isTrue);
    });
  });

  group('links', () {
    Map<String, dynamic> cta(Map<String, dynamic> link, {String label = 'Go'}) => _page([
          {
            'id': 'c',
            'type': 'ctaBand',
            'content': {
              'title': 'T',
              'primary': {'label': label, 'link': link},
            },
          },
        ]);

    test('valid links pass', () {
      for (final l in [
        {'type': 'internal', 'value': '/signup'},
        {'type': 'external', 'value': 'https://example.com'},
        {'type': 'external', 'value': 'mailto:a@b.co'},
        {'type': 'anchor', 'value': 'pricing'},
        {'type': 'action', 'value': 'openDemo'},
      ]) {
        expect(_errors(cta(l)), isEmpty, reason: '$l');
      }
    });

    test('script and unknown targets are errors', () {
      for (final l in [
        {'type': 'external', 'value': 'javascript:alert(1)'},
        {'type': 'external', 'value': 'http://plain.example.com'},
        {'type': 'internal', 'value': '/admin'},
        {'type': 'internal', 'value': '//evil.example.com'},
        {'type': 'action', 'value': 'deleteEverything'},
        {'type': 'teleport', 'value': 'x'},
      ]) {
        expect(_errors(cta(l)), isNotEmpty, reason: '$l');
      }
    });

    test('a button with text but no destination is a warning', () {
      final doc = cta({}, label: 'Click me');
      expect(_errors(doc), isEmpty);
      expect(_warnings(doc).single, contains('no destination'));
    });

    test('no label and no link is fine (button hidden)', () {
      expect(_warnings(cta({}, label: '')), isEmpty);
    });
  });

  group('copy', () {
    test('unknown placeholders are errors', () {
      expect(_errors(_page([_faq('Hello {nope}')])).single, contains('{nope}'));
      expect(_errors(_page([_faq('{trialDays}-day trial')])), isEmpty);
    });

    test('literal trial length and discount get a warning pointing at the token', () {
      expect(_warnings(_page([_faq('Try it for 45 days')])).single, contains('{trialDays}'));
      expect(_warnings(_page([_faq('Save 20% yearly')])).single, contains('{annualDiscountPct}'));
    });

    test('unprotected fields do not warn about numbers', () {
      final doc = _page([
        {
          'id': 's',
          'type': 'steps',
          'content': {
            'title': 'T',
            'items': [
              {'icon': 'check_rounded', 'title': 'Takes 45 days', 'desc': ''}
            ],
          },
        },
      ]);
      expect(_warnings(doc), isEmpty);
    });

    test('Sinhala and Tamil are flagged as outside the bundled fonts', () {
      expect(_warnings(_page([_faq('ආයුබෝවන්')])).single, contains('fallback font'));
      expect(_warnings(_page([_faq('வணக்கம்')])).single, contains('fallback font'));
    });

    test('symbols the font lacks are flagged', () {
      expect(_warnings(_page([_faq('Rated ★★★★★')])).single, contains('symbol'));
    });
  });

  group('images', () {
    Map<String, dynamic> img(String url, String alt) => _page([
          {
            'id': 'i',
            'type': 'imageText',
            'content': {'title': 'T', 'image': {'url': url, 'alt': alt}},
          },
        ]);

    test('only library images', () {
      expect(_errors(img('https://evil.example.com/x.png', 'x')).single, contains('media library'));
    });

    test('a library image without alt text is a warning', () {
      const ok = 'https://x.supabase.co/storage/v1/object/public/site-media/a.png';
      expect(_errors(img(ok, '')), isEmpty);
      expect(_warnings(img(ok, '')).single, contains('alt text'));
      expect(_warnings(img(ok, 'A hotel lobby')), isEmpty);
    });

    test('no image at all is fine', () {
      expect(_errors(img('', '')), isEmpty);
    });
  });

  group('contrast', () {
    test('a dark heading on a dark background is flagged', () {
      final w = _warnings(_page([
        _faq('A', extra: {'style': {'background': '#0A1424'}}),
      ]));
      expect(w.single, contains('hard to read'));
    });

    test('a light heading on a dark background is fine', () {
      final w = _warnings(_page([
        _faq('A', extra: {
          'style': {'background': '#0A1424'},
          'typography': {'headingColor': '#FFFFFF'},
        }),
      ]));
      expect(w, isEmpty);
    });

    test('no background, no check', () {
      expect(_warnings(_page([_faq('A')])), isEmpty);
    });
  });

  group('unverified claims', () {
    test('the shipped copy lists its unconfirmed claims', () {
      final claims = collectUnverifiedClaims(siteDefaultJson('page:home'));
      final fields = claims.map((c) => '${c.sectionId}/${c.field}').toSet();
      expect(fields, containsAll(['hero/Badge above the headline', 'stats/Figures', 'testimonials/Quotes']));
      expect(claims.every((c) => c.message.isNotEmpty), isTrue);
    });

    test('a disabled section makes no claims', () {
      final doc = siteDefaultJson('page:home');
      for (final s in doc['sections'] as List) {
        (s as Map)['enabled'] = false;
      }
      expect(collectUnverifiedClaims(doc), isEmpty);
    });

    test('an emptied field is not a claim', () {
      final doc = _page([
        {
          'id': 'h',
          'type': 'hero',
          'content': {'headline': 'H', 'body': 'b', 'badge': ''},
        },
      ]);
      expect(collectUnverifiedClaims(doc), isEmpty);
    });
  });
}
