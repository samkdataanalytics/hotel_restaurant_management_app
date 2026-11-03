import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/model/json_reader.dart';
import 'package:hotel_checkin/web/cms/model/site_document.dart';

/// The public page parses admin-edited JSON, so the contract is: bad data
/// degrades, it never throws. These tests pin that contract.
void main() {
  group('J (tolerant reader)', () {
    test('returns the fallback for a missing key', () {
      const j = J({});
      expect(j.str('a', 'x'), 'x');
      expect(j.flag('a', true), isTrue);
      expect(j.dbl('a', 2.5), 2.5);
      expect(j.integer('a', 7), 7);
    });

    test('returns the fallback when the value has the wrong type', () {
      const j = J({'s': 5, 'b': 'yes', 'n': 'ten', 'o': 'not a map', 'l': 'nope'});
      expect(j.str('s', 'fb'), 'fb');
      expect(j.flag('b', false), isFalse);
      expect(j.dbl('n', 1), 1);
      expect(j.obj('o').raw, isEmpty);
      expect(j.list('l', (x) => x), isEmpty);
    });

    test('accepts ints where a double is wanted, and the reverse', () {
      const j = J({'a': 3, 'b': 4.9});
      expect(j.dbl('a'), 3.0);
      expect(j.integer('b'), 4);
    });

    test('J.of tolerates non-map input', () {
      expect(J.of(null).raw, isEmpty);
      expect(J.of(42).raw, isEmpty);
      expect(J.of(<dynamic>[1]).raw, isEmpty);
      expect(J.of({'a': 1}).raw, {'a': 1});
    });

    test('strOrNull treats an empty string as absent', () {
      const j = J({'a': '', 'b': 'x'});
      expect(j.strOrNull('a'), isNull);
      expect(j.strOrNull('b'), 'x');
    });

    test('list skips non-map elements and elements whose parser throws', () {
      const j = J({
        'items': [
          {'n': 1},
          'junk',
          null,
          {'n': 'boom'},
          {'n': 3},
        ],
      });
      final out = j.list('items', (e) {
        final n = e.raw['n'];
        if (n is! int) throw const FormatException('bad item');
        return n;
      });
      expect(out, [1, 3], reason: 'one bad item must not hide its siblings');
    });

    test('strings keeps only strings', () {
      const j = J({'w': ['a', 2, 'b', null, true]});
      expect(j.strings('w'), ['a', 'b']);
    });
  });

  group('SiteDocument', () {
    test('parses sections in order', () {
      final d = SiteDocument.fromJson({
        'schema': 1,
        'sections': [
          {'id': 'a', 'type': 'hero'},
          {'id': 'b', 'type': 'faq'},
        ],
      });
      expect(d.sections.map((s) => s.id), ['a', 'b']);
    });

    test('drops a section with no id or type but keeps the rest', () {
      final d = SiteDocument.fromJson({
        'sections': [
          {'id': 'a', 'type': 'hero'},
          {'type': 'faq'},
          {'id': 'c'},
          {'id': 'd', 'type': 'faq'},
        ],
      });
      expect(d.sections.map((s) => s.id), ['a', 'd']);
    });

    test('garbage input yields an empty document, not an exception', () {
      expect(SiteDocument.fromJson(null).sections, isEmpty);
      expect(SiteDocument.fromJson('text').sections, isEmpty);
      expect(SiteDocument.fromJson({'sections': 'nope'}).sections, isEmpty);
    });

    test('a section defaults to enabled, visible everywhere, spaced, revealed', () {
      final s = SectionNode.fromJson(const J({'id': 'a', 'type': 'faq'}));
      expect(s.enabled, isTrue);
      expect(s.visibility.visibleOn(Device.mobile), isTrue);
      expect(s.visibility.visibleOn(Device.tablet), isTrue);
      expect(s.visibility.visibleOn(Device.desktop), isTrue);
      expect(s.spaceBefore, isTrue);
      expect(s.reveal, isTrue);
    });

    test('per-device visibility is read independently', () {
      final s = SectionNode.fromJson(const J({
        'id': 'a',
        'type': 'faq',
        'visibility': {'mobile': false},
      }));
      expect(s.visibility.visibleOn(Device.mobile), isFalse);
      expect(s.visibility.visibleOn(Device.tablet), isTrue);
      expect(s.visibility.visibleOn(Device.desktop), isTrue);
    });

    test('layout.spaceBefore "none" removes the gap; anything else keeps it', () {
      bool gap(Object? v) => SectionNode.fromJson(J({
            'id': 'a',
            'type': 'x',
            'layout': {'spaceBefore': v},
          })).spaceBefore;
      expect(gap('none'), isFalse);
      expect(gap('section'), isTrue);
      expect(gap(null), isTrue);
      expect(gap(12), isTrue, reason: 'a wrong type falls back to the default');
    });

    test('byId finds a section or returns null', () {
      final d = SiteDocument.fromJson({
        'sections': [
          {'id': 'a', 'type': 'hero'},
        ],
      });
      expect(d.byId('a')?.type, 'hero');
      expect(d.byId('zzz'), isNull);
    });
  });
}
