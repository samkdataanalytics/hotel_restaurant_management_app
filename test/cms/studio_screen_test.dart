import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/services/plan_service.dart';
import 'package:hotel_checkin/web/cms/data/memory_site_repository.dart';
import 'package:hotel_checkin/web/cms/data/plans_provider.dart';
import 'package:hotel_checkin/web/cms/data/site_providers.dart';
import 'package:hotel_checkin/web/studio/json_path.dart';
import 'package:hotel_checkin/web/studio/studio_providers.dart';
import 'package:hotel_checkin/web/studio/studio_screen.dart';
import 'package:hotel_checkin/web/studio/studio_state.dart';

import 'support/brand_fonts.dart';

/// Screenshots are for looking at the editor by hand, so they are written only
/// when STUDIO_SHOTS_DIR names a folder: `STUDIO_SHOTS_DIR=/tmp/shots flutter test ...`.
/// Without it (CI, a plain `flutter test`) they are skipped and nothing is written.
final String? _shots = Platform.environment['STUDIO_SHOTS_DIR'];

PlanModel _plan(String slug, String name, double price, {bool hi = false}) => PlanModel(
      id: slug,
      name: name,
      slug: slug,
      priceMonthly: price,
      isCustomPrice: false,
      maxProperties: 1,
      maxUsers: 5,
      maxRooms: 20,
      maxTables: 10,
      isHighlighted: hi,
      isActive: true,
      sortOrder: 0,
    );

class _Harness {
  _Harness(this.repo, this.container);

  final MemorySiteRepository repo;
  final ProviderContainer container;

  StudioState get state => container.read(studioControllerProvider);
}

Future<_Harness> _pump(WidgetTester t, {double width = 1500, double height = 900, MemorySiteRepository? repo}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final r = repo ?? MemorySiteRepository();
  final container = ProviderContainer(overrides: [
    siteRepositoryProvider.overrideWithValue(r),
    activePlansProvider.overrideWith((ref) async => [_plan('starter', 'Starter', 3450), _plan('growth', 'Growth', 8000, hi: true)]),
    starterMonthlyPriceProvider.overrideWith((ref) async => 3450),
  ]);
  addTearDown(container.dispose);

  final key = GlobalKey();
  await t.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'Inter'),
        home: const Scaffold(body: StudioScreen()),
      ),
    ),
  ));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  _lastKey = key;
  return _Harness(r, container);
}

GlobalKey? _lastKey;

Future<void> _shot(WidgetTester t, String name) async {
  final dir = _shots;
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_lastKey!));
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadBrandFonts);

  testWidgets('opens on the home page with its sections listed and a live preview', (t) async {
    final h = await _pump(t);
    expect(h.state.loading, isFalse);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Add section'), findsOneWidget);
    expect(find.text('Hero'), findsWidgets);
    expect(find.text('Stats strip'), findsOneWidget);
    expect(find.text('Frequently asked questions'), findsWidgets);
    expect(h.state.doc['sections'], hasLength(10));
    expect(t.takeException(), isNull);
    await _shot(t, 'studio_home');
  });

  testWidgets('the headline field edits the document, and the preview follows', (t) async {
    final h = await _pump(t);
    expect(find.text('Stop running your property on'), findsWidgets);

    await t.enterText(find.widgetWithText(TextField, 'Stop running your property on'), 'Run your property on HotRest');
    await t.pump(const Duration(milliseconds: 100));

    expect(getAt(h.state.doc, ['sections', 0, 'content', 'headline']), 'Run your property on HotRest');
    expect(find.text('Run your property on HotRest'), findsWidgets);
    expect(h.state.status, SaveStatus.dirty);
    expect(h.state.canUndo, isTrue);
    await _shot(t, 'studio_edited');
  });

  testWidgets('undo puts the headline back', (t) async {
    final h = await _pump(t);
    await t.enterText(find.widgetWithText(TextField, 'Stop running your property on'), 'Changed');
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.byIcon(Icons.undo_rounded));
    await t.pump(const Duration(milliseconds: 50));
    expect(getAt(h.state.doc, ['sections', 0, 'content', 'headline']), 'Stop running your property on');
    expect(find.widgetWithText(TextField, 'Stop running your property on'), findsOneWidget);
  });

  testWidgets('clicking a section in the preview selects it', (t) async {
    final h = await _pump(t);
    h.container.read(studioControllerProvider.notifier).select('faq');
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Frequently asked questions'), findsWidgets);
    expect(h.state.selectedId, 'faq');
    await _shot(t, 'studio_faq_selected');
  });

  testWidgets('hiding a section from the list removes it from the page but keeps it', (t) async {
    final h = await _pump(t);
    await t.tap(find.byIcon(Icons.visibility_outlined).at(1)); // stats
    await t.pump(const Duration(milliseconds: 100));
    expect(getAt(h.state.doc, ['sections', 1, 'enabled']), false);
    expect(h.state.doc['sections'], hasLength(10));
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('Add section offers every type and inserts starter content', (t) async {
    final h = await _pump(t);
    await t.tap(find.text('Add section'));
    await t.pumpAndSettle();
    expect(find.text('Add a section'), findsOneWidget);
    expect(find.text('Text block'), findsOneWidget);
    expect(find.text('Image and text'), findsOneWidget);
    expect(find.text('Spacer', skipOffstage: false), findsOneWidget);

    await t.tap(find.text('Text block'));
    await t.pumpAndSettle();

    final sections = h.state.doc['sections'] as List;
    expect(sections, hasLength(11));
    // Inserted after the selected section (the hero, selected on open).
    expect((sections[1] as Map)['type'], 'richText');
    expect(h.state.selectedId, 'richText');
  });

  testWidgets('a required field cleared shows an error and blocks publishing', (t) async {
    final h = await _pump(t);
    await t.enterText(find.widgetWithText(TextField, 'Stop running your property on'), '');
    await t.pump(const Duration(milliseconds: 100));
    expect(h.state.errors, isNotEmpty);
    expect(find.textContaining('to fix'), findsWidgets);

    await t.tap(find.text('Publish'));
    await t.pumpAndSettle();
    expect(find.text('Fix these first'), findsOneWidget);
    expect(await h.repo.fetchPublished(), isEmpty);
  });

  testWidgets('publishing lists unconfirmed claims, needs acknowledgement, then goes live', (t) async {
    final h = await _pump(t);
    await t.enterText(find.widgetWithText(TextField, 'Stop running your property on'), 'A new headline');
    await t.pump(const Duration(milliseconds: 100));

    await t.tap(find.text('Publish'));
    await t.pumpAndSettle();

    expect(find.text('Publish Home'), findsOneWidget);
    expect(find.text('Claims to confirm before publishing'), findsOneWidget);
    // Publish is disabled until the claims are acknowledged.
    FilledButton publish() => t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish').last);
    expect(publish().onPressed, isNull);

    await t.ensureVisible(find.byType(Checkbox));
    await t.tap(find.byType(Checkbox));
    await t.pump();
    expect(publish().onPressed, isNotNull);
    await _shot(t, 'studio_publish_dialog');

    await t.tap(find.widgetWithText(FilledButton, 'Publish').last);
    await t.pumpAndSettle();

    final live = await h.repo.fetchPublished();
    expect(live.single.key, 'page:home');
    expect((live.single.content['sections'] as List).first['content']['headline'], 'A new headline');
    expect(h.state.publishedVersion, 1);
  });

  testWidgets('narrow windows move the panels into slide-overs', (t) async {
    final h = await _pump(t, width: 1000, height: 800);
    expect(find.text('Sections'), findsOneWidget); // the floating toggle
    expect(find.text('Properties'), findsWidgets);
    expect(find.text('Add section'), findsNothing);

    await t.tap(find.text('Sections'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Add section'), findsOneWidget);
    expect(t.takeException(), isNull);
    expect(h.state.doc['sections'], hasLength(10));
    await _shot(t, 'studio_narrow');
  });

  testWidgets('a backend failure still opens the editor with a clear banner', (t) async {
    final repo = MemorySiteRepository()..failWith = Exception('relation "site_drafts" does not exist');
    final h = await _pump(t, repo: repo);
    expect(h.state.error, contains('migration'));
    expect(find.textContaining('not set up'), findsOneWidget);
    expect(find.text('Add section'), findsOneWidget);
    await _shot(t, 'studio_no_backend');
  });

  testWidgets('Header & footer workspace edits the header document', (t) async {
    final h = await _pump(t);
    await t.tap(find.text('Header & footer'));
    await t.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(h.state.key, 'global:header');
    expect(find.text('Menu links'), findsOneWidget);
    await _shot(t, 'studio_header');
  });

  testWidgets('Theme workspace edits the global theme', (t) async {
    final h = await _pump(t);
    await t.tap(find.text('Theme'));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(h.state.key, 'global:theme');
    expect(find.text('Site theme'), findsOneWidget);
  });
}
