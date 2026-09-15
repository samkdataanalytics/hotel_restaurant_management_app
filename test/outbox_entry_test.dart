import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/domain/entities/menu_item.dart';
import 'package:hotel_checkin/domain/entities/restaurant_order.dart';
import 'package:hotel_checkin/staff_mobile/data/local_store.dart';

MenuItem _item({String id = 'm1', String name = 'Lager', double price = 5}) =>
    MenuItem(
      id: id,
      name: name,
      description: '',
      price: price,
      category: 'Drinks',
    );

OutboxEntry _entry({
  OutboxKind kind = OutboxKind.createOrder,
  Map<String, dynamic>? payload,
  int attempts = 0,
  DateTime? queuedAt,
}) =>
    OutboxEntry(
      id: 'e1',
      kind: kind,
      propertyId: 'p1',
      queuedAt: queuedAt ?? DateTime(2026, 9, 15, 19, 4),
      payload: payload ?? const {'orderId': 'o1'},
      attempts: attempts,
    );

void main() {
  group('OutboxEntry round trip', () {
    test('survives encode and decode unchanged', () {
      final original = _entry(
        payload: {'orderId': 'o1', 'tableId': 't1'},
        attempts: 2,
      );
      final restored = OutboxEntry.decode(original.id, original.encode());

      expect(restored.id, original.id);
      expect(restored.kind, original.kind);
      expect(restored.propertyId, original.propertyId);
      expect(restored.queuedAt, original.queuedAt);
      expect(restored.payload, original.payload);
      expect(restored.attempts, 2);
    });

    test('carries a whole order through storage intact', () {
      // The queued payload is what eventually reaches the kitchen, so a lossy
      // round trip would silently change someone's order.
      final order = RestaurantOrder(
        id: 'o1',
        orderNumber: '123456',
        tableId: 't1',
        type: OrderType.dineIn,
        createdAt: DateTime(2026, 9, 15, 19, 4),
        items: [
          OrderItem(
            id: 'li1',
            menuItem: _item(),
            quantity: 3,
            notes: 'no ice',
            selectedModifiers: const {'Size': ['Large']},
          ),
        ],
      );

      final entry = _entry(payload: {'orderId': order.id, 'order': order.toMap()});
      final restored = OutboxEntry.decode(entry.id, entry.encode());
      final back = RestaurantOrder.fromMap(
        Map<String, dynamic>.from(restored.payload['order'] as Map),
      );

      expect(back.id, 'o1');
      expect(back.orderNumber, '123456');
      expect(back.tableId, 't1');
      // createdAt is fixed at the moment the order was taken, not when synced.
      expect(back.createdAt, DateTime(2026, 9, 15, 19, 4));
      expect(back.items.single.quantity, 3);
      expect(back.items.single.notes, 'no ice');
      expect(back.items.single.selectedModifiers['Size'], ['Large']);
    });

    test('an append queues only the added items, never the whole array', () {
      // This is the conflict rule. Storing a final array would clobber items
      // another device added while this one was offline.
      final added = [
        OrderItem(id: 'li9', menuItem: _item(name: 'Brownie'), quantity: 1),
      ];
      final entry = _entry(
        kind: OutboxKind.addItems,
        payload: {
          'orderId': 'o1',
          'items': added.map((i) => i.toMap()).toList(),
        },
      );

      final restored = OutboxEntry.decode(entry.id, entry.encode());
      expect(restored.payload.containsKey('order'), isFalse,
          reason: 'an append must not carry a full order snapshot');
      expect((restored.payload['items'] as List), hasLength(1));
    });
  });

  group('OutboxEntry retry policy', () {
    test('is not blocked before the attempt limit', () {
      expect(_entry(attempts: OutboxEntry.maxAttempts - 1).isBlocked, isFalse);
    });

    test('blocks once attempts reach the limit', () {
      expect(_entry(attempts: OutboxEntry.maxAttempts).isBlocked, isTrue);
    });

    test('copyWith bumps attempts without disturbing the payload', () {
      final entry = _entry(payload: {'orderId': 'o1'});
      final bumped = entry.copyWith(attempts: 3, lastError: 'network down');

      expect(bumped.attempts, 3);
      expect(bumped.lastError, 'network down');
      expect(bumped.id, entry.id);
      expect(bumped.queuedAt, entry.queuedAt);
      expect(bumped.payload, entry.payload);
    });

    test('an unknown kind decodes to createOrder rather than throwing', () {
      // Forward compatibility: a queue written by a newer build must not brick
      // an older one on downgrade.
      const raw = '{"kind":"somethingNew","propertyId":"p1",'
          '"queuedAt":"2026-09-15T19:04:00.000","payload":{},"attempts":0}';
      expect(OutboxEntry.decode('e1', raw).kind, OutboxKind.createOrder);
    });
  });
}
