import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/domain/entities/menu_item.dart';
import 'package:hotel_checkin/domain/entities/restaurant_order.dart';
import 'package:hotel_checkin/domain/table_bill.dart';

RestaurantOrder _order({
  String id = 'o1',
  OrderType type = OrderType.dineIn,
  required double lineTotal,
  int quantity = 1,
}) =>
    RestaurantOrder(
      id: id,
      orderNumber: '1',
      tableId: 't1',
      type: type,
      createdAt: DateTime(2026, 9, 15),
      items: [
        OrderItem(
          id: 'li_$id',
          menuItem: MenuItem(
            id: 'm1',
            name: 'Item',
            description: '',
            price: lineTotal / quantity,
            category: 'Food',
          ),
          quantity: quantity,
        ),
      ],
    );

void main() {
  group('computeTableBill basics', () {
    test('no tax, no service charge, no discount', () {
      final bill = computeTableBill(
        orders: [_order(lineTotal: 100)],
        taxRate: 0,
        serviceChargeRate: 0,
      );
      expect(bill.itemsTotal, 100);
      expect(bill.subtotal, 100);
      expect(bill.total, 100);
    });

    test('tax applies to the subtotal', () {
      final bill = computeTableBill(
        orders: [_order(lineTotal: 100)],
        taxRate: 0.10,
        serviceChargeRate: 0,
      );
      expect(bill.tax, closeTo(10, 0.001));
      expect(bill.total, closeTo(110, 0.001));
    });

    test('service charge applies to a fully dine-in bill', () {
      final bill = computeTableBill(
        orders: [_order(lineTotal: 100)],
        taxRate: 0,
        serviceChargeRate: 0.10,
      );
      expect(bill.serviceCharge, closeTo(10, 0.001));
      expect(bill.serviceChargeFraction, 1.0);
      expect(bill.hasMixedOrderTypes, isFalse);
    });

    test('an empty table totals zero without dividing by zero', () {
      final bill = computeTableBill(
        orders: const [],
        taxRate: 0.10,
        serviceChargeRate: 0.10,
      );
      expect(bill.total, 0);
      expect(bill.serviceChargeFraction, 1.0);
    });
  });

  group('service charge covers only table service', () {
    test('takeaway alone attracts no service charge', () {
      final bill = computeTableBill(
        orders: [_order(type: OrderType.takeaway, lineTotal: 100)],
        taxRate: 0,
        serviceChargeRate: 0.10,
      );
      expect(bill.serviceCharge, 0);
      expect(bill.serviceChargeFraction, 0);
      expect(bill.hasMixedOrderTypes, isFalse);
    });

    test('delivery alone attracts no service charge', () {
      final bill = computeTableBill(
        orders: [_order(type: OrderType.delivery, lineTotal: 100)],
        taxRate: 0,
        serviceChargeRate: 0.10,
      );
      expect(bill.serviceCharge, 0);
    });

    test('room service counts as table service', () {
      final bill = computeTableBill(
        orders: [_order(type: OrderType.roomService, lineTotal: 100)],
        taxRate: 0,
        serviceChargeRate: 0.10,
      );
      expect(bill.serviceCharge, closeTo(10, 0.001));
    });

    test('a mixed bill charges service only on the dine-in share', () {
      // 75 dine-in + 25 takeaway = service charge on 75% of the subtotal.
      final bill = computeTableBill(
        orders: [
          _order(id: 'a', lineTotal: 75),
          _order(id: 'b', type: OrderType.takeaway, lineTotal: 25),
        ],
        taxRate: 0,
        serviceChargeRate: 0.10,
      );
      expect(bill.serviceChargeFraction, closeTo(0.75, 0.0001));
      expect(bill.serviceCharge, closeTo(7.5, 0.001));
      expect(bill.hasMixedOrderTypes, isTrue);
    });
  });

  group('discounts', () {
    test('a percentage discount comes off the items total', () {
      final bill = computeTableBill(
        orders: [_order(lineTotal: 200)],
        taxRate: 0,
        serviceChargeRate: 0,
        discountType: DiscountType.percentage,
        discountAmount: 10,
      );
      expect(bill.discountValue, closeTo(20, 0.001));
      expect(bill.subtotal, closeTo(180, 0.001));
    });

    test('a flat discount comes off the items total', () {
      final bill = computeTableBill(
        orders: [_order(lineTotal: 200)],
        taxRate: 0,
        serviceChargeRate: 0,
        discountType: DiscountType.flat,
        discountAmount: 35,
      );
      expect(bill.discountValue, closeTo(35, 0.001));
      expect(bill.subtotal, closeTo(165, 0.001));
    });

    test('tax and service charge are computed after the discount', () {
      // The order matters: taxing before discounting overcharges the guest.
      final bill = computeTableBill(
        orders: [_order(lineTotal: 100)],
        taxRate: 0.10,
        serviceChargeRate: 0.10,
        discountType: DiscountType.percentage,
        discountAmount: 50,
      );
      expect(bill.subtotal, closeTo(50, 0.001));
      expect(bill.tax, closeTo(5, 0.001));
      expect(bill.serviceCharge, closeTo(5, 0.001));
      expect(bill.total, closeTo(60, 0.001));
    });

    test('a flat discount larger than the bill cannot go negative', () {
      final bill = computeTableBill(
        orders: [_order(lineTotal: 40)],
        taxRate: 0.10,
        serviceChargeRate: 0.10,
        discountType: DiscountType.flat,
        discountAmount: 100,
      );
      expect(bill.subtotal, 0);
      expect(bill.total, 0);
      // Reports what was actually deducted, not the 100 that was asked for.
      expect(bill.discountValue, closeTo(40, 0.001));
    });

    test('a percentage above 100 is capped rather than inverting the bill', () {
      final bill = computeTableBill(
        orders: [_order(lineTotal: 80)],
        taxRate: 0,
        serviceChargeRate: 0,
        discountType: DiscountType.percentage,
        discountAmount: 150,
      );
      expect(bill.subtotal, 0);
      expect(bill.total, 0);
    });

    test('a zero or negative discount amount is ignored', () {
      for (final amount in [0.0, -25.0]) {
        final bill = computeTableBill(
          orders: [_order(lineTotal: 100)],
          taxRate: 0,
          serviceChargeRate: 0,
          discountType: DiscountType.flat,
          discountAmount: amount,
        );
        expect(bill.discountValue, 0, reason: 'amount $amount');
        expect(bill.total, 100);
      }
    });
  });

  group('matches the web settle dialog', () {
    test('reproduces table_floor_screen.dart line 232-248 exactly', () {
      // Mirrors the web formula so the two surfaces cannot charge different
      // amounts for the same table.
      final orders = [
        _order(id: 'a', lineTotal: 1200),
        _order(id: 'b', type: OrderType.takeaway, lineTotal: 300),
      ];
      const taxRate = 0.08;
      const svcRate = 0.10;
      const discountPct = 10.0;

      final itemsTotal = 1500.0;
      final discountValue = itemsTotal * (discountPct / 100);
      final subtotal = itemsTotal - discountValue;
      final tax = subtotal * taxRate;
      final dineInFraction = 1200.0 / itemsTotal;
      final serviceCharge = dineInFraction * subtotal * svcRate;
      final expected = subtotal + tax + serviceCharge;

      final bill = computeTableBill(
        orders: orders,
        taxRate: taxRate,
        serviceChargeRate: svcRate,
        discountType: DiscountType.percentage,
        discountAmount: discountPct,
      );

      expect(bill.total, closeTo(expected, 0.0001));
    });
  });
}
