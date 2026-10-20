import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/domain/entities/menu_item.dart';
import 'package:hotel_checkin/domain/entities/restaurant_order.dart';
import 'package:hotel_checkin/domain/table_bill.dart';
import 'package:hotel_checkin/staff_mobile/data/receipt_builder.dart';

/// The bytes are ESC/POS, so the readable content is asserted by decoding the
/// printable ASCII back out. That is enough to catch the failures that matter:
/// a missing total, a dropped kitchen note, a wrong currency.
String readable(List<int> bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    if (b >= 32 && b < 127) {
      buffer.writeCharCode(b);
    } else if (b == 10) {
      buffer.write('\n');
    }
  }
  return buffer.toString();
}

RestaurantOrder _order({
  String id = 'o1',
  String number = '4821',
  OrderType type = OrderType.dineIn,
  List<OrderItem>? items,
}) =>
    RestaurantOrder(
      id: id,
      orderNumber: number,
      tableId: 't1',
      type: type,
      createdAt: DateTime(2026, 9, 15, 19, 4),
      items: items ??
          [
            OrderItem(
              id: 'li1',
              menuItem: MenuItem(
                id: 'm1',
                name: 'Beef Burger',
                description: '',
                price: 2400,
                category: 'Mains',
              ),
              quantity: 2,
            ),
          ],
    );

void main() {
  late ReceiptBuilder builder;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    builder = ReceiptBuilder(
      paper: ReceiptPaper.mm80,
      profile: await CapabilityProfile.load(),
    );
  });

  TableBill billFor(List<RestaurantOrder> orders,
          {double tax = 0, double svc = 0}) =>
      computeTableBill(
        orders: orders,
        taxRate: tax,
        serviceChargeRate: svc,
      );

  test('prints the venue name, table and order number', () {
    final orders = [_order()];
    final text = readable(builder.build(
      header: const ReceiptHeader(propertyName: 'The Grand'),
      orders: orders,
      bill: billFor(orders),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: false,
    ));

    expect(text, contains('The Grand'));
    expect(text, contains('Table 6'));
    expect(text, contains('#4821'));
  });

  test('prints each line with its quantity and amount', () {
    final orders = [_order()];
    final text = readable(builder.build(
      header: const ReceiptHeader(propertyName: 'The Grand'),
      orders: orders,
      bill: billFor(orders),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: false,
    ));

    expect(text, contains('Beef Burger'));
    expect(text, contains('2'));
    expect(text, contains('4800.00'));
  });

  test('carries modifiers and kitchen notes onto the receipt', () {
    // A guest querying the bill needs to see what they were charged for.
    final orders = [
      _order(items: [
        OrderItem(
          id: 'li1',
          menuItem: MenuItem(
            id: 'm1',
            name: 'Seer Fish',
            description: '',
            price: 3200,
            category: 'Mains',
          ),
          quantity: 1,
          notes: 'no lemon',
          selectedModifiers: const {'Side': ['Truffle Fries']},
        ),
      ]),
    ];
    final text = readable(builder.build(
      header: const ReceiptHeader(propertyName: 'The Grand'),
      orders: orders,
      bill: billFor(orders),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: false,
    ));

    expect(text, contains('Truffle Fries'));
    expect(text, contains('no lemon'));
  });

  test('omits a fully refunded line', () {
    final orders = [
      _order(items: [
        OrderItem(
          id: 'li1',
          menuItem: MenuItem(
              id: 'm1', name: 'Voided Dish', description: '', price: 100,
              category: 'Mains'),
          quantity: 1,
          isRefunded: true,
        ),
      ]),
    ];
    final text = readable(builder.build(
      header: const ReceiptHeader(propertyName: 'The Grand'),
      orders: orders,
      bill: billFor(orders),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: false,
    ));

    expect(text, isNot(contains('Voided Dish')));
  });

  test('shows tax and service charge only when they apply', () {
    final orders = [_order()];

    final without = readable(builder.build(
      header: const ReceiptHeader(propertyName: 'The Grand'),
      orders: orders,
      bill: billFor(orders),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: false,
    ));
    expect(without, isNot(contains('Tax')));
    expect(without, isNot(contains('Service')));

    final with_ = readable(builder.build(
      header: const ReceiptHeader(propertyName: 'The Grand'),
      orders: orders,
      bill: billFor(orders, tax: 0.08, svc: 0.10),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: false,
      taxRate: 0.08,
      serviceChargeRate: 0.10,
    ));
    expect(with_, contains('Tax 8%'));
    expect(with_, contains('Service 10%'));
  });

  test('footnotes the service charge when the table mixes order types', () {
    final orders = [
      _order(id: 'a'),
      _order(id: 'b', number: '4822', type: OrderType.takeaway),
    ];
    final text = readable(builder.build(
      header: const ReceiptHeader(propertyName: 'The Grand'),
      orders: orders,
      bill: billFor(orders, svc: 0.10),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: false,
      serviceChargeRate: 0.10,
    ));

    expect(text, contains('dine-in items only'));
  });

  test('says PAID or CHARGED TO ROOM, never both', () {
    final orders = [_order()];

    final paid = readable(builder.build(
      header: const ReceiptHeader(propertyName: 'The Grand'),
      orders: orders,
      bill: billFor(orders),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: false,
    ));
    expect(paid, contains('PAID'));
    expect(paid, isNot(contains('CHARGED TO ROOM')));

    final room = readable(builder.build(
      header: const ReceiptHeader(propertyName: 'The Grand'),
      orders: orders,
      bill: billFor(orders),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: true,
      roomLabel: '204',
    ));
    expect(room, contains('CHARGED TO ROOM 204'));
  });

  test('prefixes amounts with the property currency symbol', () {
    final orders = [_order()];
    final text = readable(builder.build(
      header: const ReceiptHeader(
          propertyName: 'The Grand', currencySymbol: 'Rs '),
      orders: orders,
      bill: billFor(orders),
      tableLabel: 'Table 6',
      settledAt: DateTime(2026, 9, 15, 19, 42),
      chargedToRoom: false,
    ));

    expect(text, contains('Rs 4800.00'));
  });

  test('the test page renders for both paper widths', () async {
    for (final paper in ReceiptPaper.values) {
      final b = ReceiptBuilder(
          paper: paper, profile: await CapabilityProfile.load());
      final text = readable(b.buildTestPage());
      expect(text, contains('Printer test'));
      expect(text, contains(paper.label));
    }
  });

  group('text sanitising', () {
    // ESC/POS encodes as Latin-1 and throws on anything outside it. Menu
    // names, modifiers and kitchen notes are all typed by staff, so an
    // unencodable character must degrade rather than take the receipt down.
    test('maps typographic characters to ASCII', () {
      expect(ReceiptBuilder.safe('a \u2014 b'), 'a - b');
      expect(ReceiptBuilder.safe('it\u2019s'), "it's");
      expect(ReceiptBuilder.safe('\u201Cquoted\u201D'), '"quoted"');
      expect(ReceiptBuilder.safe('wait\u2026'), 'wait...');
    });

    test('keeps accented characters, which Latin-1 can encode', () {
      expect(ReceiptBuilder.safe('Cr\u00E8me Br\u00FBl\u00E9e'),
          'Cr\u00E8me Br\u00FBl\u00E9e');
    });

    test('replaces anything still unencodable rather than throwing', () {
      expect(ReceiptBuilder.safe('Burger \u{1F354}'), 'Burger ?');
    });

    test('an emoji in a kitchen note does not break the receipt', () {
      final orders = [
        _order(items: [
          OrderItem(
            id: 'li1',
            menuItem: MenuItem(
                id: 'm1', name: 'Burger \u{1F354}', description: '',
                price: 100, category: 'Mains'),
            quantity: 1,
            notes: 'extra hot \u{1F525}',
          ),
        ]),
      ];
      expect(
        () => builder.build(
          header: const ReceiptHeader(propertyName: 'The Grand'),
          orders: orders,
          bill: billFor(orders),
          tableLabel: 'Table 6',
          settledAt: DateTime(2026, 9, 15, 19, 42),
          chargedToRoom: false,
        ),
        returnsNormally,
      );
    });
  });
}
