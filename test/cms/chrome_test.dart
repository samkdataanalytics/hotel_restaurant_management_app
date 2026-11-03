import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/chrome/footer_content.dart';
import 'package:hotel_checkin/web/cms/chrome/header_content.dart';
import 'package:hotel_checkin/web/cms/chrome/nav_item.dart';
import 'package:hotel_checkin/web/cms/chrome/site_footer.dart';
import 'package:hotel_checkin/web/cms/chrome/site_header.dart';
import 'package:hotel_checkin/web/cms/defaults/site_defaults.dart';
import 'package:hotel_checkin/web/cms/model/json_reader.dart';
import 'package:hotel_checkin/web/cms/render/site_scope.dart';

import 'support/brand_fonts.dart';

HeaderContent _header([Map<String, dynamic>? raw]) =>
    HeaderContent.fromJson(J.of(raw ?? siteDefaultJson('global:header')));
FooterContent _footer([Map<String, dynamic>? raw]) =>
    FooterContent.fromJson(J.of(raw ?? siteDefaultJson('global:footer')));

Future<void> _show(WidgetTester t, double w, Widget child, {void Function(String)? onScroll, SiteMode mode = SiteMode.public}) async {
  t.view.physicalSize = Size(w, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: SiteScope(
      mode: mode,
      onScrollTo: onScroll,
      child: Scaffold(
        endDrawer: SiteHeaderDrawer(content: _header()),
        body: SingleChildScrollView(child: child),
      ),
    ),
  ));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(loadBrandFonts);

  group('content', () {
    test('the defaults give the original header', () {
      final h = _header();
      expect(h.items.map((i) => i.label), ['Features', 'Pricing', 'Docs']);
      expect(h.signIn!.label, 'Sign in');
      expect(h.cta.label, 'Start free trial');
      expect(h.cta.mobileLabel, 'Start free');
      expect(h.hasMenu, isTrue);
    });

    test('a disabled item is hidden but its page is untouched', () {
      final raw = siteDefaultJson('global:header');
      ((raw['items'] as List)[2] as Map)['enabled'] = false;
      expect(_header(raw).items.map((i) => i.label), ['Features', 'Pricing']);
    });

    test('an item with no label, or an invalid link, is not shown', () {
      final raw = siteDefaultJson('global:header');
      (raw['items'] as List)
        ..add({'label': '', 'link': {'type': 'internal', 'value': '/help'}})
        ..add({'label': 'Evil', 'link': {'type': 'external', 'value': 'javascript:alert(1)'}})
        ..add({'label': 'Nowhere'});
      expect(_header(raw).items.map((i) => i.label), ['Features', 'Pricing', 'Docs']);
    });

    test('a header with nothing has no menu button', () {
      expect(_header({'cta': {'label': 'Go', 'link': {'type': 'internal', 'value': '/signup'}}}).hasMenu, isFalse);
    });

    test('mobile label falls back to the full label', () {
      final h = _header({'cta': {'label': 'Start now', 'link': {'type': 'internal', 'value': '/signup'}}});
      expect(h.cta.mobileLabel, 'Start now');
    });

    test('a CTA with no link is not visible', () {
      expect(_header({'cta': {'label': 'Go'}}).cta.visible, isFalse);
    });

    test('the footer defaults give the original columns and links', () {
      final f = _footer();
      expect(f.columns.map((c) => c.title), ['Product', 'Company', 'Get started']);
      expect(f.legalLinks.map((l) => l.label), ['Terms', 'Privacy', 'Returns', 'Help']);
    });

    test('{year} in the copyright is today\'s year', () {
      expect(_footer().copyright, '© ${DateTime.now().year} HotRest. All rights reserved.');
    });

    test('a footer column with no visible links is dropped', () {
      final raw = siteDefaultJson('global:footer');
      for (final l in ((raw['columns'] as List)[0] as Map)['links'] as List) {
        (l as Map)['enabled'] = false;
      }
      expect(_footer(raw).columns.map((c) => c.title), ['Company', 'Get started']);
    });

    test('NavItem.visible needs text and a destination', () {
      NavItem item(Map<String, dynamic> m) => NavItem.fromJson(J.of(m));
      expect(item({'label': 'A', 'link': {'type': 'internal', 'value': '/'}}).visible, isTrue);
      expect(item({'label': ' ', 'link': {'type': 'internal', 'value': '/'}}).visible, isFalse);
      expect(item({'label': 'A'}).visible, isFalse);
    });
  });

  group('header widget', () {
    testWidgets('desktop shows the links, sign in and the CTA', (t) async {
      await _show(t, 1280, SiteHeader(content: _header(), scrolled: false));
      for (final s in ['Features', 'Pricing', 'Docs', 'Sign in', 'Start free trial']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.byIcon(Icons.menu_rounded), findsNothing);
    });

    testWidgets('a phone shows the short CTA and a menu button instead of the links', (t) async {
      await _show(t, 520, SiteHeader(content: _header(), scrolled: false));
      expect(find.text('Start free'), findsOneWidget);
      expect(find.text('Features'), findsNothing);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });

    testWidgets('the menu opens a drawer with the same links', (t) async {
      await _show(t, 520, Builder(builder: (c) => SiteHeader(content: _header(), scrolled: false)));
      await t.tap(find.byIcon(Icons.menu_rounded));
      await t.pumpAndSettle();
      expect(find.text('Features'), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('a section link scrolls on the live site', (t) async {
      final scrolled = <String>[];
      await _show(t, 1280, SiteHeader(content: _header(), scrolled: false), onScroll: scrolled.add);
      await t.tap(find.text('Pricing'));
      expect(scrolled, ['pricing']);
    });

    testWidgets('links are inert in preview', (t) async {
      final scrolled = <String>[];
      await _show(t, 1280, SiteHeader(content: _header(), scrolled: false),
          onScroll: scrolled.add, mode: SiteMode.preview);
      await t.tap(find.text('Pricing'));
      expect(scrolled, isEmpty);
    });

    testWidgets('an empty header still lays out', (t) async {
      await _show(t, 1280, SiteHeader(content: _header({}), scrolled: false));
      expect(t.takeException(), isNull);
    });
  });

  group('footer widget', () {
    testWidgets('renders columns, copyright and legal links at three widths', (t) async {
      for (final w in [520.0, 820.0, 1280.0]) {
        await _show(t, w, SiteFooter(content: _footer()));
        expect(t.takeException(), isNull);
        expect(find.text('Product'), findsOneWidget);
        expect(find.text('Terms'), findsOneWidget);
        expect(find.textContaining('All rights reserved'), findsOneWidget);
      }
    });

    testWidgets('an empty footer renders without error', (t) async {
      await _show(t, 1280, SiteFooter(content: _footer({})));
      expect(t.takeException(), isNull);
    });
  });
}
