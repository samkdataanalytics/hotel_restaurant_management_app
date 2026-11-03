import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/model/color_ref.dart';
import 'package:hotel_checkin/web/cms/model/json_reader.dart';
import 'package:hotel_checkin/web/cms/model/responsive.dart';
import 'package:hotel_checkin/web/cms/model/site_document.dart';
import 'package:hotel_checkin/web/cms/model/site_theme.dart';
import 'package:hotel_checkin/web/cms/registry/section_registry.dart';
import 'package:hotel_checkin/web/cms/render/site_renderer.dart';
import 'package:hotel_checkin/web/cms/render/type_scope.dart';
import 'package:hotel_checkin/web/brand_kit.dart';
import 'package:hotel_checkin/web/cms/sections/faq_section.dart';
import 'package:hotel_checkin/web/cms/sections/cta_band_section.dart';

import 'support/brand_fonts.dart';

SiteDocument _doc({Map<String, Object?> page = const {}, Map<String, Object?> section = const {}}) =>
    SiteDocument.fromJson({
      'schema': 1,
      ...page,
      'sections': [
        {
          'id': 'faq',
          'type': 'faq',
          'content': {
            'eyebrow': 'FAQ',
            'title': 'Heading under test',
            'items': [
              {'q': 'Q', 'a': 'A'}
            ],
          },
          ...section,
        },
      ],
    });

Future<void> _show(WidgetTester t, double width, SiteDocument doc, {SiteTheme theme = SiteTheme.none}) async {
  t.view.physicalSize = Size(width, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final renderer = SiteRenderer(registry: SectionRegistry.of([faqDefinition]), theme: theme);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Builder(builder: (c) => Column(children: renderer.build(c, doc))),
      ),
    ),
  ));
  await t.pump(const Duration(seconds: 1));
}

TextStyle _heading(WidgetTester t) => t.widget<Text>(find.text('Heading under test')).style!;

void main() {
  setUpAll(loadBrandFonts);

  group('Responsive', () {
    test('mobile falls back to tablet, then desktop', () {
      const r = Responsive<double>(64, tablet: 48);
      expect(r.resolve(Device.desktop), 64);
      expect(r.resolve(Device.tablet), 48);
      expect(r.resolve(Device.mobile), 48);
      expect(const Responsive<double>(64).resolve(Device.mobile), 64);
    });

    test('reports which devices set their own value', () {
      const r = Responsive<double>(64, mobile: 30);
      expect(r.hasOwn(Device.tablet), isFalse);
      expect(r.hasOwn(Device.mobile), isTrue);
    });

    test('number() clamps and ignores junk', () {
      final r = Responsive.number(const J({'desktop': 6000, 'mobile': -4, 'tablet': 'x'}),
          min: 10, max: 120)!;
      expect(r.desktop, 120);
      expect(r.mobile, 10);
      expect(r.tablet, isNull);
      expect(Responsive.number(const J({}), min: 1, max: 2), isNull);
      expect(Responsive.number(const J({'desktop': double.nan}), min: 1, max: 2), isNull);
    });

    test('a value for only mobile still gives desktop something', () {
      final r = Responsive.number(const J({'mobile': 20}), min: 10, max: 120)!;
      expect(r.resolve(Device.desktop), 20);
    });
  });

  group('colours', () {
    test('parses #RGB and #RRGGBB, rejects the rest', () {
      expect(parseHexColor('#fff'), const Color(0xFFFFFFFF));
      expect(parseHexColor('#0A7D77'), const Color(0xFF0A7D77));
      expect(parseHexColor('0A7D77'), isNull);
      expect(parseHexColor('#12345'), isNull);
      expect(parseHexColor('#GGGGGG'), isNull);
      expect(parseHexColor('red'), isNull);
      expect(parseHexColor(null), isNull);
    });

    test('hex round trip', () {
      expect(colorToHex(const Color(0xFF0A7D77)), '#0A7D77');
    });

    test('contrast matches the WCAG reference points', () {
      expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
      expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)), closeTo(1, 0.001));
      // The brand navy on white is 13.98:1 (documented in brand_kit.dart).
      expect(contrastRatio(const Color(0xFF012C58), const Color(0xFFFFFFFF)), closeTo(13.98, 0.05));
    });
  });

  group('TypeOverrides', () {
    test('unknown fonts and bad colours are dropped', () {
      final o = TypeOverrides.fromJson(
          const J({'headingFont': 'Comic Sans', 'headingColor': 'nope', 'bodyFont': 'Inter'}));
      expect(o.headingFont, isNull);
      expect(o.headingColor, isNull);
      expect(o.bodyFont, 'Inter');
    });

    test('narrow level wins field by field', () {
      final wide = TypeOverrides.fromJson(const J({
        'heading': {'desktop': 50},
        'headingFont': 'Inter',
      }));
      final narrow = TypeOverrides.fromJson(const J({
        'heading': {'desktop': 64},
      }));
      final m = wide.merge(narrow);
      expect(m.sizes[TypeSlot.heading]!.desktop, 64);
      expect(m.headingFont, 'Inter'); // not overridden, so inherited
    });

    test('an empty override changes nothing', () {
      expect(TypeOverrides.none.isEmpty, isTrue);
      expect(TypeOverrides.fromJson(const J({})).isEmpty, isTrue);
    });
  });

  group('rendering the cascade', () {
    testWidgets('with no overrides the heading keeps its built-in size', (t) async {
      await _show(t, 1280, _doc());
      expect(_heading(t).fontSize, 42);
      await _show(t, 520, _doc());
      expect(_heading(t).fontSize, 28);
    });

    testWidgets('64 / 48 / 32 changes the heading at each width', (t) async {
      final doc = _doc(section: {
        'typography': {
          'heading': {'desktop': 64, 'tablet': 48, 'mobile': 32},
        },
      });
      await _show(t, 1280, doc);
      expect(_heading(t).fontSize, 64);
      await _show(t, 900, doc);
      expect(_heading(t).fontSize, 48);
      await _show(t, 520, doc);
      expect(_heading(t).fontSize, 32);
    });

    testWidgets('section beats page beats global theme', (t) async {
      final theme = SiteTheme.fromJson(const J({'heading': {'desktop': 50}}), const J({}));
      await _show(t, 1280, _doc(), theme: theme);
      expect(_heading(t).fontSize, 50);

      final page = _doc(page: {'typography': {'heading': {'desktop': 55}}});
      await _show(t, 1280, page, theme: theme);
      expect(_heading(t).fontSize, 55);

      final both = _doc(
        page: {'typography': {'heading': {'desktop': 55}}},
        section: {'typography': {'heading': {'desktop': 70}}},
      );
      await _show(t, 1280, both, theme: theme);
      expect(_heading(t).fontSize, 70);
    });

    testWidgets('removing the override restores the inherited value (reset)', (t) async {
      final theme = SiteTheme.fromJson(const J({'heading': {'desktop': 50}}), const J({}));
      await _show(t, 1280, _doc(section: {'typography': {'heading': {'desktop': 70}}}), theme: theme);
      expect(_heading(t).fontSize, 70);
      await _show(t, 1280, _doc(), theme: theme);
      expect(_heading(t).fontSize, 50);
    });

    testWidgets('heading font and colour apply', (t) async {
      await _show(
        t,
        1280,
        _doc(section: {
          'typography': {'headingFont': 'DMSerifDisplay', 'headingColor': '#FF0000'},
        }),
      );
      final s = _heading(t);
      expect(s.fontFamily, 'DMSerifDisplay');
      expect(s.fontWeight, FontWeight.w400, reason: 'the font has a single weight');
      expect(s.color, const Color(0xFFFF0000));
    });

    testWidgets('background colour fills the section', (t) async {
      await _show(t, 1280, _doc(section: {'style': {'background': '#112233'}}));
      final box = t.widget<ColoredBox>(find.ancestor(
        of: find.text('Heading under test'),
        matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == const Color(0xFF112233)),
      ));
      expect(box.color, const Color(0xFF112233));
    });

    testWidgets('an invalid background is ignored', (t) async {
      await _show(t, 1280, _doc(section: {'style': {'background': 'not-a-colour'}}));
      expect(find.byType(ColoredBox).evaluate().where((e) => (e.widget as ColoredBox).color == const Color(0xFF112233)), isEmpty);
      expect(t.takeException(), isNull);
    });

    testWidgets('extra padding is per device', (t) async {
      final doc = _doc(section: {
        'layout': {
          'paddingTop': {'desktop': 100, 'mobile': 10},
        },
      });
      await _show(t, 1280, doc);
      final desktop = t.getTopLeft(find.text('Heading under test')).dy;
      await _show(t, 520, doc);
      final mobile = t.getTopLeft(find.text('Heading under test')).dy;
      expect(desktop - mobile, greaterThan(60));
    });

    testWidgets('content width follows layout.maxWidth', (t) async {
      // The CTA band fills the Shell's width, so its width is the content width.
      SiteDocument stats(Map<String, Object?> layout) => SiteDocument.fromJson({
            'sections': [
              {
                'id': 's',
                'type': 'ctaBand',
                'layout': layout,
                'content': {'title': 'Band'},
              },
            ],
          });
      Future<double> width(SiteDocument d) async {
        t.view.physicalSize = const Size(1500, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final r = SiteRenderer(registry: SectionRegistry.of([ctaBandDefinition]));
        await t.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Builder(builder: (c) => Column(children: r.build(c, d))),
            ),
          ),
        ));
        await t.pump(const Duration(seconds: 2));
        return t.getSize(find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == LK.navy)).width;
      }

      expect(await width(stats({})), 1180);
      expect(await width(stats({'maxWidth': 700})), 700);
      expect(await width(stats({'maxWidth': 99999})), 1372,
          reason: 'clamped to 1600, then limited by the 1500px window less gutters');
    });

    testWidgets('section gap can be overridden by the theme', (t) async {
      SiteDocument two() => SiteDocument.fromJson({
            'sections': [
              {'id': 'a', 'type': 'faq', 'content': {'title': 'First', 'items': []}},
              {'id': 'b', 'type': 'faq', 'content': {'title': 'Second', 'items': []}},
            ],
          });
      await _show(t, 1280, two());
      final base = t.getTopLeft(find.text('Second')).dy - t.getTopLeft(find.text('First')).dy;
      await _show(t, 1280, two(),
          theme: SiteTheme.fromJson(const J({}), const J({'sectionGap': {'desktop': 0}})));
      final tight = t.getTopLeft(find.text('Second')).dy - t.getTopLeft(find.text('First')).dy;
      expect(base - tight, closeTo(128, 1));
    });
  });
}
