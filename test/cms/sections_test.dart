import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/data/plans_provider.dart';
import 'package:hotel_checkin/web/cms/defaults/home_defaults.dart';
import 'package:hotel_checkin/web/cms/model/json_reader.dart';
import 'package:hotel_checkin/web/cms/model/site_document.dart';
import 'package:hotel_checkin/web/cms/registry/section_registry.dart';
import 'package:hotel_checkin/web/cms/render/site_renderer.dart';
import 'package:hotel_checkin/web/cms/render/site_scope.dart';
import 'package:hotel_checkin/web/cms/sections/before_after_section.dart';
import 'package:hotel_checkin/web/cms/sections/comparison_section.dart';
import 'package:hotel_checkin/web/cms/sections/cta_band_section.dart';
import 'package:hotel_checkin/web/cms/sections/faq_section.dart';
import 'package:hotel_checkin/web/cms/sections/feature_grid_section.dart';
import 'package:hotel_checkin/web/cms/sections/stats_section.dart';
import 'package:hotel_checkin/web/cms/sections/steps_section.dart';
import 'package:hotel_checkin/web/cms/sections/testimonials_section.dart';

/// Sections that read their content from the document. They must render from
/// the bundled defaults at every width, and survive content that is missing or
/// the wrong shape, because that content is typed by a person.
final _defs = {
  'stats': statsDefinition,
  'beforeAfter': beforeAfterDefinition,
  'steps': stepsDefinition,
  'faq': faqDefinition,
  'ctaBand': ctaBandDefinition,
  'featureGrid': featureGridDefinition,
  'testimonials': testimonialsDefinition,
  'comparison': comparisonDefinition,
};

SectionNode _node(String type, Object? content) => SectionNode.fromJson(J.of({
      'id': type,
      'type': type,
      'content': content,
    }));

Future<void> _pump(WidgetTester t, double width, Widget child,
    {Object? starterPrice = 3450}) async {
  t.view.physicalSize = Size(width, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      // No network in tests: the price is whatever the test says it is.
      starterMonthlyPriceProvider.overrideWith((ref) async => starterPrice as int?),
    ],
    child: MaterialApp(
      home: SiteScope(
        mode: SiteMode.test,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  ));
  await t.pump(const Duration(seconds: 2));
}

void main() {
  final byType = {for (final n in homeDefaults.sections) n.type: n};

  for (final entry in _defs.entries) {
    final type = entry.key;

    for (final width in [520.0, 820.0, 1280.0]) {
      testWidgets('$type renders its defaults at ${width.toInt()}px', (t) async {
        await _pump(t, width, Builder(builder: (c) => entry.value.builder(c, byType[type]!)));
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('$type survives empty content', (t) async {
      await _pump(t, 1280, Builder(builder: (c) => entry.value.builder(c, _node(type, {}))));
      expect(t.takeException(), isNull);
    });

    testWidgets('$type survives content of the wrong shape', (t) async {
      const junk = {
        'title': 5,
        'items': 'not a list',
        'before': [],
        'after': 7,
        'primary': 'x',
        'ticks': {'a': 1},
      };
      await _pump(t, 1280, Builder(builder: (c) => entry.value.builder(c, _node(type, junk))));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('stats shows the numbers in the document, not hardcoded ones', (t) async {
    final node = _node('stats', {
      'items': [
        {'value': 12, 'suffix': ' days', 'decimals': 0, 'label': 'Trial'},
      ],
    });
    await _pump(t, 1280, Builder(builder: (c) => statsDefinition.builder(c, node)));
    expect(find.text('12 days'), findsOneWidget);
    expect(find.text('Trial'), findsOneWidget);
    expect(find.text('Properties'), findsNothing);
  });

  testWidgets('testimonial initials come from the name unless given', (t) async {
    final node = _node('testimonials', {
      'items': [
        {'quote': 'q1', 'name': 'ada lovelace byron'},
        {'quote': 'q2', 'name': 'Plato'},
        {'quote': 'q3', 'name': 'X Y', 'initials': 'ZZ'},
      ],
    });
    await _pump(t, 1280, Builder(builder: (c) => testimonialsDefinition.builder(c, node)));
    expect(find.text('AB'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
    expect(find.text('ZZ'), findsOneWidget);
  });

  group('comparison', () {
    Widget build(SectionNode n) => Builder(builder: (c) => comparisonDefinition.builder(c, n));

    testWidgets('fills {starterPrice} from the live plan', (t) async {
      await _pump(t, 1280, build(byType['comparison']!));
      expect(find.text('Free / LKR 3,450'), findsOneWidget);
    });

    testWidgets('uses the fallback price when the plan cannot be had', (t) async {
      await _pump(t, 1280, build(byType['comparison']!), starterPrice: null);
      expect(find.text('Free / $kStarterPriceFallback'), findsOneWidget);
    });

    testWidgets('a row with too few cells is padded, not a crash', (t) async {
      final node = _node('comparison', {
        'columns': [
          {'name': 'A'},
          {'name': 'B'},
        ],
        'rows': [
          {'label': 'Short row', 'cells': [true]},
          {'label': 'Junk cells', 'cells': [5, null]},
        ],
      });
      await _pump(t, 1280, build(node));
      expect(t.takeException(), isNull);
      expect(find.text('Short row'), findsOneWidget);
    });

    testWidgets('phone layout labels columns with the short name', (t) async {
      await _pump(t, 520, build(byType['comparison']!));
      expect(find.text('PMS'), findsWidgets);
      expect(find.text('Traditional PMS'), findsNothing);
    });
  });

  testWidgets('steps are numbered by position', (t) async {
    final node = _node('steps', {
      'items': [
        {'title': 'First', 'desc': 'a'},
        {'title': 'Second', 'desc': 'b'},
      ],
    });
    await _pump(t, 1280, Builder(builder: (c) => stepsDefinition.builder(c, node)));
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('03'), findsNothing);
  });

  testWidgets('cta band buttons are inert in preview mode', (t) async {
    final node = byType['ctaBand']!;
    t.view.physicalSize = const Size(1280, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: SiteScope(
        mode: SiteMode.preview,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Builder(builder: (c) => ctaBandDefinition.builder(c, node)),
          ),
        ),
      ),
    ));
    await t.tap(find.text('Create free account'));
    await t.pump();
    // No router is installed: a live link would have thrown looking for one.
    expect(t.takeException(), isNull);
  });

  group('SiteRenderer', () {
    testWidgets('a section whose builder throws is replaced by its default', (t) async {
      var calls = 0;
      final registry = SectionRegistry.of([
        SectionDefinition(
          type: 'faq',
          label: 'faq',
          builder: (c, node) {
            calls++;
            // First call is the edited node, second the bundled default.
            if (node.content.flag('poison')) throw StateError('bad content');
            return const Text('default faq');
          },
        ),
      ]);
      final doc = SiteDocument.fromJson({
        'schema': 1,
        'sections': [
          {'id': 'faq', 'type': 'faq', 'content': {'poison': true}},
        ],
      });
      final fallback = SiteDocument.fromJson({
        'schema': 1,
        'sections': [
          {'id': 'faq', 'type': 'faq', 'content': {}},
        ],
      });
      await t.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          final r = SiteRenderer(registry: registry, fallback: fallback);
          return Column(children: r.build(c, doc));
        }),
      ));
      // Reveal schedules a zero-delay timer once it is on screen; let it fire.
      await t.pump(const Duration(seconds: 1));
      expect(find.text('default faq'), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('an unknown section type is skipped, not fatal', (t) async {
      final registry = SectionRegistry.of(const []);
      final doc = SiteDocument.fromJson({
        'schema': 1,
        'sections': [
          {'id': 'x', 'type': 'nope', 'content': {}},
        ],
      });
      await t.pumpWidget(MaterialApp(
        home: Builder(builder: (c) =>
            Column(children: SiteRenderer(registry: registry).build(c, doc))),
      ));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    });
  });
}
