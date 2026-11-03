import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/studio/media/media_rules.dart';
import 'package:hotel_checkin/web/studio/studio_diff.dart';

Map<String, dynamic> _page(List<Map<String, dynamic>> s, {Map<String, dynamic> extra = const {}}) =>
    {'schema': 1, ...extra, 'sections': s};

Map<String, dynamic> _sec(String id, String title, {bool? enabled, String type = 'faq'}) => {
      'id': id,
      'type': type,
      'content': {'title': title},
      if (enabled != null) 'enabled': enabled,
    };

Uint8List _bytes(List<int> head) => Uint8List.fromList([...head, ...List.filled(32, 0)]);

void main() {
  group('summarizeChanges', () {
    test('nothing changed: nothing to say', () {
      final d = _page([_sec('a', 'A')]);
      expect(summarizeChanges(d, d), isEmpty);
    });

    test('added, removed, edited', () {
      final out = summarizeChanges(
        _page([_sec('a', 'A'), _sec('b', 'B')]),
        _page([_sec('a', 'A edited'), _sec('c', 'C')]),
      );
      expect(out.any((l) => l.startsWith('Added:') && l.contains('"C"')), isTrue);
      expect(out.any((l) => l.startsWith('Removed:') && l.contains('"B"')), isTrue);
      expect(out.any((l) => l.startsWith('Edited:') && l.contains('"A edited"')), isTrue);
    });

    test('reordering is reported on its own, not as edits', () {
      final out = summarizeChanges(
        _page([_sec('a', 'A'), _sec('b', 'B')]),
        _page([_sec('b', 'B'), _sec('a', 'A')]),
      );
      expect(out, ['Sections reordered']);
    });

    test('hiding and showing are reported, and are not edits', () {
      final hide = summarizeChanges(_page([_sec('a', 'A')]), _page([_sec('a', 'A', enabled: false)]));
      expect(hide.single, startsWith('Hidden:'));
      final show = summarizeChanges(_page([_sec('a', 'A', enabled: false)]), _page([_sec('a', 'A')]));
      expect(show.single, startsWith('Shown again:'));
    });

    test('page settings changes are reported', () {
      final out = summarizeChanges(
        _page([_sec('a', 'A')]),
        _page([_sec('a', 'A')], extra: {'seo': {'title': 'New'}}),
      );
      expect(out.single, contains('Page settings'));
    });

    test('long titles are clipped', () {
      final out = summarizeChanges(_page([]), _page([_sec('a', 'x' * 100)]));
      expect(out.single.length, lessThan(100));
      expect(out.single, contains('…'));
    });

    test('uses the section label when it has no title', () {
      final out = summarizeChanges(
          _page([]), _page([{'id': 'sp', 'type': 'spacer', 'content': {}}]));
      expect(out.single, 'Added: Spacer');
    });
  });

  group('image checks', () {
    final jpeg = _bytes([0xFF, 0xD8, 0xFF, 0xE0]);
    final png = _bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final gif = _bytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
    final webp = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0, 0]);
    final svg = Uint8List.fromList('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'.codeUnits);
    final exe = _bytes([0x4D, 0x5A, 0x90, 0x00]);

    test('recognises the four allowed types by signature', () {
      expect(sniffImageMime(jpeg), 'image/jpeg');
      expect(sniffImageMime(png), 'image/png');
      expect(sniffImageMime(gif), 'image/gif');
      expect(sniffImageMime(webp), 'image/webp');
    });

    test('SVG and executables are not images here', () {
      expect(sniffImageMime(svg), isNull);
      expect(sniffImageMime(exe), isNull);
      expect(checkImage(svg).ok, isFalse);
      expect(checkImage(svg).problem, contains('SVG'));
    });

    test('tiny or empty input is rejected, not crashed on', () {
      expect(sniffImageMime(Uint8List(0)), isNull);
      expect(sniffImageMime(Uint8List.fromList([0xFF, 0xD8])), isNull);
      expect(checkImage(Uint8List(0)).ok, isFalse);
    });

    test('size limit', () {
      final big = Uint8List(kMaxImageBytes + 1)..setAll(0, [0xFF, 0xD8, 0xFF, 0xE0]);
      final r = checkImage(big);
      expect(r.ok, isFalse);
      expect(r.problem, contains('5 MB'));
      expect(checkImage(jpeg).ok, isTrue);
    });

    test('dimension limit', () {
      expect(checkImage(png, width: 4001, height: 100).ok, isFalse);
      expect(checkImage(png, width: 100, height: 4001).ok, isFalse);
      expect(checkImage(png, width: 4000, height: 4000).ok, isTrue);
      expect(checkImage(png).ok, isTrue, reason: 'unknown size is allowed; the bucket still caps bytes');
    });

    test('a valid file reports its real mime, not the file name', () {
      expect(checkImage(png).mime, 'image/png');
    });
  });

  group('findMediaUsage', () {
    test('finds documents that use a URL, at any depth', () {
      const url = 'https://x/storage/v1/object/public/site-media/a.png';
      final docs = <String, Object?>{
        'page:home': {
          'sections': [
            {
              'content': {
                'image': {'url': url, 'alt': ''},
              },
            },
          ],
        },
        'page:help': {'sections': []},
      };
      expect(findMediaUsage(url, docs), ['page:home']);
      expect(findMediaUsage('https://other', docs), isEmpty);
    });
  });
}
