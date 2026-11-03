import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/model/json_reader.dart';
import 'package:hotel_checkin/web/cms/model/link_target.dart';

LinkTarget parse(String type, String value, {bool newTab = false}) =>
    LinkTarget.fromJson(J({'type': type, 'value': value, 'newTab': newTab}));

void main() {
  group('internal links', () {
    test('accepts the routes the public site serves', () {
      for (final r in ['/', '/signup', '/login', '/help', '/terms', '/privacy', '/returns']) {
        expect(parse('internal', r).kind, LinkKind.internal, reason: r);
      }
    });

    test('accepts a plan query on signup', () {
      expect(parse('internal', '/signup?plan=growth').kind, LinkKind.internal);
    });

    test('rejects routes the site does not serve (they would 404)', () {
      expect(parse('internal', '/pricing').isNone, isTrue);
      expect(parse('internal', '/app/dashboard').isNone, isTrue);
      expect(parse('internal', '/superadmin').isNone, isTrue);
    });

    test('rejects protocol-relative and scheme-bearing values', () {
      expect(parse('internal', '//evil.example/').isNone, isTrue);
      expect(parse('internal', 'https://evil.example/').isNone, isTrue);
      expect(parse('internal', 'javascript:alert(1)').isNone, isTrue);
      expect(parse('internal', r'/\evil.example').isNone, isTrue);
    });

    test('rejects whitespace and hostile query strings', () {
      expect(parse('internal', '/signup?plan=a b').isNone, isTrue);
      expect(parse('internal', '/signup?x=<script>').isNone, isTrue);
    });
  });

  group('external links', () {
    test('accepts https, mailto and tel', () {
      expect(parse('external', 'https://example.com/page').kind, LinkKind.external);
      expect(parse('external', 'mailto:hello@example.com').kind, LinkKind.external);
      expect(parse('external', 'tel:+94 11 234 5678').kind, LinkKind.external);
    });

    test('rejects http, javascript, data and file schemes', () {
      expect(parse('external', 'http://example.com').isNone, isTrue);
      expect(parse('external', 'javascript:alert(1)').isNone, isTrue);
      expect(parse('external', 'data:text/html,<script>alert(1)</script>').isNone, isTrue);
      expect(parse('external', 'file:///etc/passwd').isNone, isTrue);
      expect(parse('external', 'vbscript:msgbox(1)').isNone, isTrue);
    });

    test('rejects a host with no dot, and values with whitespace', () {
      expect(parse('external', 'https://localhost/').isNone, isTrue);
      expect(parse('external', 'https://exa mple.com').isNone, isTrue);
    });

    test('rejects malformed mailto and tel', () {
      expect(parse('external', 'mailto:not-an-email').isNone, isTrue);
      expect(parse('external', 'mailto:a@b.co?cc=x@y.z').isNone, isTrue);
      expect(parse('external', 'tel:abc').isNone, isTrue);
    });

    test('keeps the newTab flag', () {
      expect(parse('external', 'https://example.com', newTab: true).newTab, isTrue);
    });
  });

  group('anchors and actions', () {
    test('accepts a lowercase slug anchor', () {
      expect(parse('anchor', 'features').kind, LinkKind.anchor);
      expect(parse('anchor', 'how-it-works').kind, LinkKind.anchor);
    });

    test('rejects anchors that are not slugs', () {
      expect(parse('anchor', '').isNone, isTrue);
      expect(parse('anchor', 'Has Space').isNone, isTrue);
      expect(parse('anchor', '#features').isNone, isTrue);
      expect(parse('anchor', 'a' * 41).isNone, isTrue);
    });

    test('accepts only the actions that exist in code', () {
      for (final a in ['signup', 'login', 'openDemo', 'openContactSales']) {
        expect(parse('action', a).kind, LinkKind.action, reason: a);
      }
      expect(parse('action', 'deleteEverything').isNone, isTrue);
    });
  });

  group('shape', () {
    test('an unknown or missing type is inert', () {
      expect(parse('mystery', '/signup').isNone, isTrue);
      expect(LinkTarget.fromJson(const J({})).isNone, isTrue);
    });

    test('equal targets compare equal', () {
      expect(parse('internal', '/login'), parse('internal', '/login'));
      expect(parse('internal', '/login') == parse('internal', '/signup'), isFalse);
    });
  });
}
