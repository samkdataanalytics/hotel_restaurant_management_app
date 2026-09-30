import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/domain/entities/menu_item.dart';
import 'package:hotel_checkin/domain/entities/restaurant_order.dart';
import 'package:hotel_checkin/staff_mobile/data/sales_summary.dart';

final _from = DateTime(2026, 9, 29, 0, 0);
final _to = DateTime(2026, 9, 29, 23, 59);

OrderItem _item({
  String name = 'Burger',
  double price = 100,
  int quantity = 1,
  int refunded = 0,
  bool fullyRefunded = false,
}) =>
    OrderItem(
      id: 'li_${name}_$quantity',
      menuItem: MenuItem(
        id: 'm_$name',
        name: name,
        description: '',
        price: price,
        category: 'Mains',
      ),
      quantity: quantity,
      refundedQuantity: refunded,
      isRefunded: fullyRefunded,
    );

RestaurantOrder _order({
  String id = 'o1',
  int hour = 13,
  OrderStatus status = OrderStatus.served,
  PaymentStatus payment = PaymentStatus.paid,
  List<OrderItem>? items,
}) =>
    RestaurantOrder(
      id: id,
      orderNumber: id,
      type: OrderType.dineIn,
      status: status,
      paymentStatus: payment,
      createdAt: DateTime(2026, 9, 29, hour),
      items: items ?? [_item()],
    );

void main() {
  group('what counts as revenue', () {
    test('a paid order counts', () {
      final s = summariseSales([_order()], from: _from, to: _to);
      expect(s.orderCount, 1);
      expect(s.revenue, 100);
    });

    test('an order charged to a room counts', () {
      final s = summariseSales(
        [_order(payment: PaymentStatus.chargedToRoom)],
        from: _from,
        to: _to,
      );
      expect(s.orderCount, 1);
    });

    test('an unpaid order does not', () {
      // An open table is not revenue. Counting it would make the figure drift
      // as tables come and go, and overstate a shift not yet paid for.
      final s = summariseSales(
        [_order(payment: PaymentStatus.unpaid)],
        from: _from,
        to: _to,
      );
      expect(s.orderCount, 0);
      expect(s.revenue, 0);
    });

    test('a cancelled order does not, even if it was paid', () {
      final s = summariseSales(
        [_order(status: OrderStatus.cancelled)],
        from: _from,
        to: _to,
      );
      expect(s.orderCount, 0);
    });

    test('orders outside the window do not', () {
      final outside = RestaurantOrder(
        id: 'old',
        orderNumber: 'old',
        type: OrderType.dineIn,
        paymentStatus: PaymentStatus.paid,
        createdAt: DateTime(2026, 9, 20, 13),
        items: [_item()],
      );
      final s = summariseSales([outside], from: _from, to: _to);
      expect(s.orderCount, 0);
    });

    test('no orders at all gives a zeroed summary, not a crash', () {
      final s = summariseSales([], from: _from, to: _to);
      expect(s.revenue, 0);
      expect(s.averageOrder, 0);
      expect(s.topItems, isEmpty);
    });
  });

  group('refunds', () {
    test('a refunded unit is excluded from the item count', () {
      final s = summariseSales(
        [_order(items: [_item(quantity: 3, refunded: 1)])],
        from: _from,
        to: _to,
      );
      expect(s.itemCount, 2);
    });

    test('a fully refunded line contributes nothing', () {
      final s = summariseSales(
        [_order(items: [_item(quantity: 2, fullyRefunded: true)])],
        from: _from,
        to: _to,
      );
      expect(s.itemCount, 0);
      expect(s.topItems, isEmpty);
    });
  });

  group('best sellers', () {
    test('groups the same dish across orders', () {
      final s = summariseSales(
        [
          _order(id: 'a', items: [_item(name: 'Burger', quantity: 2)]),
          _order(id: 'b', items: [_item(name: 'Burger', quantity: 3)]),
        ],
        from: _from,
        to: _to,
      );
      expect(s.topItems, hasLength(1));
      expect(s.topItems.single.quantity, 5);
    });

    test('ranks by quantity, breaking ties on revenue', () {
      // A steak and a side that both sold 2 should not be ordered arbitrarily.
      final s = summariseSales(
        [
          _order(id: 'a', items: [_item(name: 'Side', price: 2, quantity: 2)]),
          _order(id: 'b', items: [_item(name: 'Steak', price: 40, quantity: 2)]),
        ],
        from: _from,
        to: _to,
      );
      expect(s.topItems.first.name, 'Steak');
    });

    test('caps the list at the requested length', () {
      final orders = [
        for (var i = 0; i < 9; i++)
          _order(id: 'o$i', items: [_item(name: 'Dish$i', quantity: 9 - i)]),
      ];
      final s = summariseSales(orders, from: _from, to: _to, topCount: 3);
      expect(s.topItems, hasLength(3));
      expect(s.topItems.first.name, 'Dish0');
    });
  });

  group('dayparts', () {
    test('buckets by hour', () {
      expect(DaypartX.forHour(8), Daypart.breakfast);
      expect(DaypartX.forHour(12), Daypart.lunch);
      expect(DaypartX.forHour(19), Daypart.dinner);
      expect(DaypartX.forHour(23), Daypart.late);
    });

    test('boundaries land in the later period', () {
      expect(DaypartX.forHour(11), Daypart.lunch);
      expect(DaypartX.forHour(16), Daypart.dinner);
      expect(DaypartX.forHour(22), Daypart.late);
    });

    test('counts orders per period', () {
      final s = summariseSales(
        [
          _order(id: 'a', hour: 9),
          _order(id: 'b', hour: 13),
          _order(id: 'c', hour: 14),
        ],
        from: _from,
        to: _to,
      );
      expect(s.ordersByDaypart[Daypart.breakfast], 1);
      expect(s.ordersByDaypart[Daypart.lunch], 2);
      expect(s.ordersByDaypart[Daypart.dinner], isNull);
    });
  });

  test('average order divides revenue by settled orders only', () {
    final s = summariseSales(
      [
        _order(id: 'a', items: [_item(price: 100)]),
        _order(id: 'b', items: [_item(price: 300)]),
        _order(id: 'c', payment: PaymentStatus.unpaid),
      ],
      from: _from,
      to: _to,
    );
    expect(s.orderCount, 2);
    expect(s.averageOrder, closeTo(200, 0.001));
  });
}
