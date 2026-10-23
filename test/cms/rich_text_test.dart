import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/model/link_target.dart';
import 'package:hotel_checkin/web/cms/model/rich_text.dart';
import 'package:hotel_checkin/web/cms/model/json_reader.dart';
import 'package:hotel_checkin/web/cms/model/site_document.dart';
import 'package:hotel_checkin/web/cms/render/site_scope.dart';
import 'package:hotel_checkin/web/cms/sections/image_text_section.dart';
import 'package:hotel_checkin/web/cms/sections/rich_text_section.dart';
import 'package:hotel_checkin/web/cms/sections/spacer_section.dart';

import 'support/brand_fonts.dart';

void main() {
  setUpAll(loadBrandFonts);

  group('MiniMarkdown', () {
    test('paragraphs split on blank lines; single newlines join', () {
      final b = MiniMarkdown.parse('one\ntwo\n\nthree');
      expect(b.map((x) => x.plain), ['one two', 'three']);
      expect(b.every((x) => x.kind == RichBlockKind.paragraph), isTrue);
    });

    test('headings and bullets', () {
      final b = MiniMarkdown.parse('## Title\n- a\n- b\ntext');
      expect(b.map((x) => x.kind), [
        RichBlockKind.heading,
        RichBlockKind.bullet,
        RichBlockKind.bullet,
        RichBlockKind.paragraph,
      ]);
      expect(b[0].plain, 'Title');
    });

    test('bold, italic and plain text in one line', () {
      final s = MiniMarkdown.inline('a **b** c *d* e');
      expect(s, [
        const RichSpan('a '),
        const RichSpan('b', bold: true),
        const RichSpan(' c '),
        const RichSpan('d', italic: true),
        const RichSpan(' e'),
      ]);
    });

    test('allowed links become live targets', () {
      final s = MiniMarkdown.inline('[home](/) [site](https://example.com) [mail](mailto:a@b.co) [up](#pricing)');
      expect(s.where((x) => x.link != null).map((x) => x.link!.kind), [
        LinkKind.internal,
        LinkKind.external,
        LinkKind.external,
        LinkKind.anchor,
      ]);
    });

    test('dangerous or unknown links are plain text, not links', () {
      for (final bad in [
        'javascript:alert(1)',
        'data:text/html;base64,AAAA',
        'http://insecure.example.com',
        '/not-a-route',
        'ftp://x.y',
        '//evil.example.com',
      ]) {
        final s = MiniMarkdown.inline('[click]($bad)');
        expect(s.first.text, 'click', reason: bad);
        expect(s.every((x) => x.link == null), isTrue, reason: bad);
      }
    });

    test('HTML is just text: nothing to sanitise', () {
      final b = MiniMarkdown.parse('<script>alert(1)</script> <b>x</b>');
      expect(b.single.plain, '<script>alert(1)</script> <b>x</b>');
    });

    test('unbalanced markers do not throw or swallow text', () {
      expect(MiniMarkdown.parse('**unclosed and [broken(link').single.plain,
          '**unclosed and [broken(link');
      expect(MiniMarkdown.parse(''), isEmpty);
      expect(MiniMarkdown.parse('   \n\n  '), isEmpty);
    });

    test('CRLF line endings are handled', () {
      expect(MiniMarkdown.parse('a\r\n\r\nb').length, 2);
    });
  });

  group('library image check', () {
    test('accepts only https URLs inside the site-media bucket', () {
      const ok = 'https://x.supabase.co/storage/v1/object/public/site-media/abc.png';
      expect(isLibraryImageUrl(ok), isTrue);
      expect(isLibraryImageUrl('http://x.supabase.co/storage/v1/object/public/site-media/abc.png'), isFalse);
      expect(isLibraryImageUrl('https://evil.example.com/pixel.gif'), isFalse);
      expect(isLibraryImageUrl('https://x.supabase.co/storage/v1/object/public/property-logos/a.png'), isFalse);
      expect(isLibraryImageUrl('javascript:alert(1)'), isFalse);
      expect(isLibraryImageUrl(''), isFalse);
    });
  });

  Future<void> show(WidgetTester t, double w, Widget child) async {
    t.view.physicalSize = Size(w, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: SiteScope(
        mode: SiteMode.test,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ));
    await t.pump(const Duration(seconds: 1));
  }

  SectionNode node(String type, Map<String, Object?> content) =>
      SectionNode.fromJson(J.of({'id': type, 'type': type, 'content': content}));

  group('richText section', () {
    testWidgets('renders heading, paragraph, bullet at three widths', (t) async {
      final n = node('richText', {
        'title': 'About',
        'body': '## Sub\nHello **world**\n\n- one\n- two',
      });
      for (final w in [520.0, 820.0, 1280.0]) {
        await show(t, w, Builder(builder: (c) => richTextDefinition.builder(c, n)));
        expect(t.takeException(), isNull);
        expect(find.text('About'), findsOneWidget);
      }
    });

    testWidgets('empty content renders without error', (t) async {
      await show(t, 1280, Builder(builder: (c) => richTextDefinition.builder(c, node('richText', {}))));
      expect(t.takeException(), isNull);
    });

    testWidgets('links in the body are inert in preview', (t) async {
      final n = node('richText', {'body': 'go [home](/signup)'});
      await show(t, 1280, Builder(builder: (c) => richTextDefinition.builder(c, n)));
      expect(t.takeException(), isNull);
    });
  });

  group('imageText section', () {
    testWidgets('an unusable image URL shows the placeholder, not a network call', (t) async {
      final n = node('imageText', {
        'title': 'T',
        'body': 'b',
        'image': {'url': 'https://evil.example.com/x.png', 'alt': 'x'},
      });
      await show(t, 1280, Builder(builder: (c) => imageTextDefinition.builder(c, n)));
      expect(t.takeException(), isNull);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('stacks on a phone and still lays out', (t) async {
      final n = node('imageText', {'title': 'T', 'body': 'b', 'imageSide': 'left'});
      for (final w in [520.0, 820.0, 1280.0]) {
        await show(t, w, Builder(builder: (c) => imageTextDefinition.builder(c, n)));
        expect(t.takeException(), isNull);
      }
    });

    testWidgets('a call-to-action with an invalid link is not shown', (t) async {
      final n = node('imageText', {
        'title': 'T',
        'cta': {'label': 'Go', 'link': {'type': 'external', 'value': 'javascript:alert(1)'}},
      });
      await show(t, 1280, Builder(builder: (c) => imageTextDefinition.builder(c, n)));
      expect(find.text('Go'), findsNothing);
    });
  });

  group('spacer section', () {
    testWidgets('height is per device', (t) async {
      final n = node('spacer', {'height': {'desktop': 120, 'mobile': 30}});
      await show(t, 1280, Builder(builder: (c) => spacerDefinition.builder(c, n)));
      expect(t.getSize(find.byType(SpacerSection)).height, 120);
      await show(t, 520, Builder(builder: (c) => spacerDefinition.builder(c, n)));
      expect(t.getSize(find.byType(SpacerSection)).height, 30);
    });

    testWidgets('height is clamped', (t) async {
      final n = node('spacer', {'height': {'desktop': 99999}});
      await show(t, 1280, Builder(builder: (c) => spacerDefinition.builder(c, n)));
      expect(t.getSize(find.byType(SpacerSection)).height, 400);
    });

    testWidgets('no height gives a sensible default', (t) async {
      await show(t, 1280, Builder(builder: (c) => spacerDefinition.builder(c, node('spacer', {}))));
      expect(t.getSize(find.byType(SpacerSection)).height, 48);
    });
  });
}
