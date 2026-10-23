import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/services/plan_service.dart';
import 'package:hotel_checkin/web/cms/data/plans_provider.dart';
import 'package:hotel_checkin/web/cms/defaults/site_defaults.dart';
import 'package:hotel_checkin/web/cms/model/json_reader.dart';
import 'package:hotel_checkin/web/cms/registry/public_registry.dart';
import 'package:hotel_checkin/web/cms/render/site_renderer.dart';
import 'package:hotel_checkin/web/cms/render/site_scope.dart';
import 'package:hotel_checkin/web/cms/sections/auth_copy_section.dart';
import 'package:hotel_checkin/web/cms/sections/help_topics_section.dart';
import 'package:hotel_checkin/web/cms/sections/legal_doc_section.dart';
import 'package:hotel_checkin/web/help_screen.dart';
import 'package:hotel_checkin/web/legal_screen.dart';
import 'package:hotel_checkin/web/studio/specs/section_specs.dart';
import 'package:hotel_checkin/web/studio/studio_validation.dart';

import 'support/brand_fonts.dart';

const _pageKeys = ['page:home', 'page:help', 'page:terms', 'page:privacy', 'page:returns', 'page:auth'];

PlanModel _plan() => const PlanModel(
      id: 'a',
      name: 'Starter',
      slug: 'starter',
      priceMonthly: 3450,
      isCustomPrice: false,
      maxProperties: 1,
      maxUsers: 5,
      maxRooms: 20,
      maxTables: 10,
      isHighlighted: false,
      isActive: true,
      sortOrder: 0,
    );

List<Override> _overrides() => [
      activePlansProvider.overrideWith((ref) async => [_plan()]),
      starterMonthlyPriceProvider.overrideWith((ref) async => 3450),
    ];

void main() {
  setUpAll(loadBrandFonts);

  group('every bundled page', () {
    for (final key in kSiteDefaults.keys) {
      test('$key validates with no errors', () {
        final errors = validateSiteDocument(key, siteDefaultJson(key)).where((i) => i.isError);
        expect(errors.map((e) => e.message), isEmpty);
      });
    }

    test('every section type in every page has a spec', () {
      for (final key in _pageKeys) {
        for (final s in siteDefaultDocument(key).sections) {
          expect(kSectionSpecByType.containsKey(s.type), isTrue, reason: '$key / ${s.type}');
          expect(publicRegistry.has(s.type), isTrue, reason: '$key / ${s.type} is not in the registry');
        }
      }
    });

    test('every registered type has a spec, and every spec a registered type', () {
      for (final s in kSectionSpecs) {
        expect(publicRegistry.has(s.type), isTrue, reason: s.type);
      }
      for (final d in publicRegistry.all) {
        expect(kSectionSpecByType.containsKey(d.type), isTrue, reason: d.type);
      }
    });

    for (final key in _pageKeys) {
      for (final w in [520.0, 820.0, 1280.0]) {
        testWidgets('$key renders at ${w.toInt()}px', (t) async {
          t.view.physicalSize = Size(w, 3000);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final doc = siteDefaultDocument(key);
          final renderer = SiteRenderer(registry: publicRegistry, fallback: doc);
          await t.pumpWidget(ProviderScope(
            overrides: _overrides(),
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Inter'),
              home: SiteScope(
                mode: SiteMode.test,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Builder(builder: (c) => Column(children: renderer.build(c, doc))),
                  ),
                ),
              ),
            ),
          ));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          expect(find.byType(Text), findsWidgets);
        });
      }
    }
  });

  group('legal pages', () {
    test('keep their original structure', () {
      int blocks(String k) {
        final c = J.of(siteDefaultDocument(k).sections.single.content.raw);
        return c.list('sections', (s) => s).fold<int>(0, (n, s) => n + s.list('blocks', (b) => b).length);
      }

      expect(siteDefaultDocument('page:terms').sections.single.content.list('sections', (s) => s).length, 9);
      expect(blocks('page:terms'), 23);
      expect(blocks('page:returns'), 16);
      expect(blocks('page:privacy'), 36);
    });

    test('the contact address is a placeholder, not typed into each page', () {
      for (final k in ['page:terms', 'page:returns', 'page:privacy']) {
        final raw = siteDefaultJson(k).toString();
        expect(raw.contains('kasun@ideadeck.biz'), isFalse, reason: k);
        expect(raw.contains('{supportEmail}'), isTrue, reason: k);
      }
    });

    test('content parses blocks and footer links', () {
      final node = siteDefaultDocument('page:terms').sections.single;
      final c = LegalDocContent.fromJson(node.content, vars: {'supportEmail': 'help@example.com'});
      expect(c.title, 'Terms of Service');
      expect(c.sections.length, 9);
      expect(c.sections.last.blocks.single.text, contains('help@example.com'));
      expect(c.footerLinks.map((l) => l.label), ['Terms of Service', 'Return & Refund Policy', 'Privacy Policy']);
      expect(c.sections[1].blocks.where((b) => b.kind == LegalBlockKind.bullet).length, 3);
    });

    test('junk content degrades to nothing, not an exception', () {
      final c = LegalDocContent.fromJson(const J({'sections': 'x', 'footerLinks': 5, 'title': 3}));
      expect(c.sections, isEmpty);
      expect(c.footerLinks, isEmpty);
    });

    testWidgets('the screen shows the page from the document with the support email filled in', (t) async {
      t.view.physicalSize = const Size(1280, 4000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const ProviderScope(
        child: MaterialApp(home: LegalScreen(page: LegalPage.terms)),
      ));
      await t.pump();
      expect(find.text('Terms of Service'), findsWidgets);
      expect(find.text('Last updated: April 8, 2025'), findsOneWidget);
      expect(find.textContaining('kasun@ideadeck.biz'), findsOneWidget);
      expect(find.textContaining('{supportEmail}'), findsNothing);
    });
  });

  group('help', () {
    test('keeps its 18 topics and 91 steps', () {
      final node = siteDefaultDocument('page:help').sections.single;
      final c = HelpContent.fromJson(node.content);
      expect(c.topics.length, 18);
      expect(c.topics.fold<int>(0, (n, t) => n + t.steps.length), 91);
      expect(c.categories.length, 6);
    });

    test('a topic without a title or a repeated id is dropped', () {
      final c = HelpContent.fromJson(const J({
        'topics': [
          {'id': 'a', 'title': 'A'},
          {'id': 'a', 'title': 'Duplicate'},
          {'id': 'b'},
          {'title': 'No id'},
        ],
      }));
      expect(c.topics.map((t) => t.id), ['a']);
    });

    test('a topic takes the colour of its category', () {
      final c = HelpContent.fromJson(const J({
        'categories': [
          {'name': 'Hotel', 'tone': 'blue'},
        ],
        'topics': [
          {'id': 'a', 'title': 'A', 'category': 'Hotel'},
          {'id': 'b', 'title': 'B', 'category': 'Nope'},
        ],
      }));
      expect(c.topics[0].color, kHelpTones['blue']);
      expect(c.topics[1].color, kHelpTones['teal'], reason: 'unknown category falls back');
    });

    testWidgets('the screen shows topics, filters by category and searches', (t) async {
      t.view.physicalSize = const Size(1280, 4000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const ProviderScope(
        child: MaterialApp(home: HelpScreen(standalone: true)),
      ));
      await t.pump();
      expect(find.text('HotRest Guide'), findsOneWidget);
      expect(find.text('18 topics · plain and simple'), findsOneWidget);
      expect(find.text('Checking In a Guest'), findsOneWidget);

      await t.tap(find.text('Finance').first);
      await t.pump();
      expect(find.text('Checking In a Guest'), findsNothing);
      expect(find.text('Viewing Your Revenue'), findsOneWidget);

      await t.tap(find.text('All').first);
      await t.enterText(find.byType(TextField), 'zzzz-nothing');
      await t.pump();
      expect(find.text('No results for "zzzz-nothing"'), findsOneWidget);

      await t.pumpWidget(const SizedBox());
    });
  });

  group('auth copy', () {
    test('login and signup parse with their wording', () {
      final doc = siteDefaultDocument('page:auth');
      final login = LoginCopy.fromJson(doc.byId('login')!.content);
      final signup = SignupCopy.fromJson(doc.byId('signup')!.content);
      expect(login.title, 'Welcome back');
      expect(login.submitLabel, 'Sign in');
      expect(signup.title, 'Create your account');
      expect(signup.trialBanner, startsWith('45-day free trial'), reason: '{trialDays} is filled in');
      expect(signup.passwordHint, 'At least 6 characters.');
    });

    test('missing fields fall back to usable labels', () {
      final login = LoginCopy.fromJson(const J({}));
      expect(login.submitLabel, 'Sign in');
      expect(login.passwordLabel, 'Password');
      expect(SignupCopy.fromJson(const J({})).submitLabel, 'Create account');
    });
  });
}
