import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/staff_mobile/features/orders/order_filter_bar.dart';
import 'package:hotel_checkin/staff_mobile/theme/staff_theme.dart';

/// Pumps the bar at a fixed logical width under the real staff theme — the
/// theme matters, because its chip padding is most of why the row did not fit.
///
/// Note on magnitudes: `flutter test` renders with Ahem, whose every glyph is a
/// square of the font size, so label widths here run roughly double what Inter
/// produces on a device. That makes these tests *stricter* than reality, which
/// is the safe direction for a layout guard — but do not quote the overflow
/// pixel counts from a failure as the on-device figure.
Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: StaffTheme.light,
      home: Scaffold(
        body: OrderFilterBar(
          filter: OrderFilter.active,
          onChanged: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('OrderFilterBar', () {
    // The widths that matter: the narrowest phone still in service, a common
    // modern handset, and the largest. The bar overflowed on all three before
    // it was made scrollable.
    for (final (width, device) in const [
      (320.0, 'iPhone SE 1st gen'),
      (375.0, 'iPhone 13 mini'),
      (390.0, 'iPhone 14'),
      (440.0, 'iPhone 17 Pro Max'),
    ]) {
      testWidgets('lays out without overflow at ${width.toInt()}pt ($device)',
          (tester) async {
        await _pumpAt(tester, width);

        // A RenderFlex overflow is reported as a FlutterError, not a throw, so
        // asserting on exceptions is the only way to catch it.
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('scrolls rather than clipping the later filters',
        (tester) async {
      await _pumpAt(tester, 320);

      // "All" is the last chip and sits well beyond 320pt, so it must be
      // reachable by scrolling rather than simply absent.
      expect(find.text('All'), findsOneWidget);

      final scrollable = find.byType(Scrollable);
      expect(scrollable, findsOneWidget);

      await tester.drag(scrollable, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('all four filters are present', (tester) async {
      await _pumpAt(tester, 390);
      for (final label in const [
        'In the kitchen',
        'Room service',
        'Today',
        'All',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'missing "$label"');
      }
    });

    testWidgets('reports the tapped filter', (tester) async {
      OrderFilter? picked;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: StaffTheme.light,
          home: Scaffold(
            body: OrderFilterBar(
              filter: OrderFilter.active,
              onChanged: (f) => picked = f,
            ),
          ),
        ),
      );

      // "Today" is the third chip and starts off-screen on a 390pt phone, so
      // it has to be scrolled to before it can be tapped — which is the whole
      // point of the bar scrolling.
      await tester.ensureVisible(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      expect(picked, OrderFilter.today);
    });
  });
}
