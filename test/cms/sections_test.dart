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
import 'package:hotel_checkin/web/cms/sections/hero_section.dart';
import 'package:hotel_checkin/web/cms/sections/pricing_section.dart';
import 'package:hotel_checkin/web/cms/sections/steps_section.dart';
import 'package:hotel_checkin/services/plan_service.dart';
import 'package:hotel_checkin/web/cms/sections/testimonials_section.dart';

import 'support/brand_fonts.dart';

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
  'pricing': pricingDefinition,
  'hero': heroDefinition,
};

PlanModel _plan(String slug, String name, double price,
        {bool custom = false, bool highlighted = false, int properties = 1}) =>
    PlanModel(
      id: slug,
      name: name,
      slug: slug,
      priceMonthly: price,
      isCustomPrice: custom,
      maxProperties: properties,
      maxUsers: 5,
      maxRooms: 20,
      maxTables: 10,
      isHighlighted: highlighted,
      isActive: true,
      sortOrder: 0,
    );

final _plans = [
  _plan('starter', 'Starter', 3450),
  _plan('growth', 'Growth', 8000, highlighted: true, properties: 3),
  _plan('enterprise', 'Enterprise', 0, custom: true, properties: -1),
];

SectionNode _node(String type, Object? content) => SectionNode.fromJson(J.of({
      'id': type,
      'type': type,
      'content': content,
    }));

Future<void> _pump(WidgetTester t, double width, Widget child,
    {Object? starterPrice = 3450, Object? plans}) async {
  t.view.physicalSize = Size(width, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      // No network in tests: the price is whatever the test says it is.
      starterMonthlyPriceProvider.overrideWith((ref) async => starterPrice as int?),
      activePlansProvider.overrideWith((ref) async {
        final p = plans ?? _plans;
        if (p is List<PlanModel>) return p;
        throw p;
      }),
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
  setUpAll(loadBrandFonts);

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

  group('hero', () {
    Widget build(SectionNode n) => Builder(builder: (c) => heroDefinition.builder(c, n));

    testWidgets('shows the headline, ticks and mock figures from content', (t) async {
      await _pump(t, 1280, build(byType['hero']!));
      expect(find.text('Stop running your property on'), findsOneWidget);
      expect(find.text('45-day free trial'), findsOneWidget);
      expect(find.text('87%'), findsOneWidget);
      expect(find.text('Good morning, Alex'), findsOneWidget);
    });

    testWidgets('an empty rotating-word list does not crash the cycler', (t) async {
      final node = _node('hero', {'headline': 'Hello', 'rotating': []});
      await _pump(t, 1280, build(node));
      expect(t.takeException(), isNull);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('without a mock the window is gone and the page still lays out', (t) async {
      final node = _node('hero', {'headline': 'Hello', 'body': 'b'});
      await _pump(t, 1280, build(node));
      expect(t.takeException(), isNull);
      expect(find.text('Good morning, Alex'), findsNothing);
    });

    testWidgets('floating callouts are desktop-only', (t) async {
      await _pump(t, 1280, build(byType['hero']!));
      expect(find.text('Guest checked in'), findsOneWidget);
      await _pump(t, 520, build(byType['hero']!));
      expect(find.text('Guest checked in'), findsNothing);
    });

    testWidgets('out-of-range chart and room values are clamped', (t) async {
      final node = _node('hero', {
        'headline': 'h',
        'mock': {
          'bars': [40, -3, 'x'],
          'days': ['M'],
          'rooms': [9, -1],
        },
      });
      await _pump(t, 1280, build(node));
      expect(t.takeException(), isNull);
    });
  });

  group('pricing', () {
    Widget build([SectionNode? n]) =>
        Builder(builder: (c) => pricingDefinition.builder(c, n ?? byType['pricing']!));

    testWidgets('shows a card per plan and features exactly one', (t) async {
      await _pump(t, 1280, build());
      expect(find.text('Starter'), findsOneWidget);
      expect(find.text('Growth'), findsOneWidget);
      expect(find.text('LKR 3450'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Most popular'), findsOneWidget);
    });

    testWidgets('two highlighted plans still feature only the first', (t) async {
      final two = [
        _plan('a', 'A', 1000, highlighted: true),
        _plan('b', 'B', 2000, highlighted: true),
      ];
      await _pump(t, 1280, build(), plans: two);
      expect(find.text('Most popular'), findsOneWidget);
    });

    testWidgets('annual toggle applies the shared discount to the displayed price', (t) async {
      await _pump(t, 1280, build());
      expect(find.text('Save 20%'), findsOneWidget);
      await t.tap(find.text('Annual'));
      // The price cross-fades; settle so the outgoing figure is gone.
      await t.pumpAndSettle();
      expect(find.text('LKR 2760'), findsOneWidget); // 3450 less 20%
      expect(find.text('LKR 3450'), findsNothing);
      expect(find.text('/mo, billed annually'), findsWidgets);
    });

    testWidgets('trial length in the copy comes from BillingFacts', (t) async {
      await _pump(t, 1280, build());
      expect(find.text('45-day free trial on every plan'), findsOneWidget);
      expect(find.textContaining('{trialDays}'), findsNothing);
    });

    testWidgets('enterprise card carries the enterprise extras only', (t) async {
      await _pump(t, 1280, build());
      expect(find.text('Dedicated account manager'), findsOneWidget);
      expect(find.text('SLA & uptime guarantee'), findsOneWidget);
    });

    testWidgets('unlimited limits read "Unlimited"', (t) async {
      await _pump(t, 1280, build());
      expect(find.text('Unlimited properties'), findsOneWidget);
    });

    testWidgets('no plans shows the holding message, not a blank', (t) async {
      await _pump(t, 1280, build(), plans: <PlanModel>[]);
      expect(find.textContaining('Pricing is being updated'), findsOneWidget);
    });

    testWidgets('a failed plans fetch shows the holding message', (t) async {
      await _pump(t, 1280, build(), plans: Exception('offline'));
      expect(find.textContaining('Pricing is being updated'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('survives empty content with sensible labels', (t) async {
      await _pump(t, 1280, build(_node('pricing', {})));
      expect(find.text('Start free trial'), findsWidgets);
      expect(find.text('Monthly'), findsOneWidget);
    });
  });

  testWidgets('placeholders in FAQ answers and the CTA band become the real numbers', (t) async {
    await _pump(t, 1280, Builder(builder: (c) => faqDefinition.builder(c, byType['faq']!)));
    expect(find.text('Do you offer a free trial?'), findsOneWidget);
    expect(find.textContaining('{trialDays}'), findsNothing);
    await _pump(t, 1280, Builder(builder: (c) => ctaBandDefinition.builder(c, byType['ctaBand']!)));
    expect(find.textContaining('45-day free trial'), findsOneWidget);
    expect(find.textContaining('{'), findsNothing);
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
