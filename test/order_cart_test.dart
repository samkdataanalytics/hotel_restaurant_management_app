import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/domain/entities/menu_item.dart';
import 'package:hotel_checkin/staff_mobile/features/orders/order_cart.dart';

MenuItem _item({
  String id = 'i1',
  String name = 'Lager',
  double price = 5.0,
  List<MenuModifier> modifiers = const [],
}) =>
    MenuItem(
      id: id,
      name: name,
      description: '',
      price: price,
      category: 'Drinks',
      modifiers: modifiers,
    );

void main() {
  group('OrderCart line merging', () {
    test('merges repeats of the same plain item into one line', () {
      final cart = const OrderCart().add(_item()).add(_item()).add(_item());

      expect(cart.items, hasLength(1));
      expect(cart.items.single.quantity, 3);
      expect(cart.totalQuantity, 3);
    });

    test('keeps items with different kitchen notes on separate lines', () {
      // The kitchen needs these apart — merging would lose the instruction.
      final cart = const OrderCart()
          .add(_item())
          .add(_item(), notes: 'no ice');

      expect(cart.items, hasLength(2));
    });

    test('keeps different modifier selections on separate lines', () {
      final cart = const OrderCart()
          .add(_item(), modifiers: {'Size': ['Large']})
          .add(_item(), modifiers: {'Size': ['Small']});

      expect(cart.items, hasLength(2));
    });

    test('merges identical modifier selections regardless of option order', () {
      final cart = const OrderCart()
          .add(_item(), modifiers: {'Extras': ['Lime', 'Salt']})
          .add(_item(), modifiers: {'Extras': ['Salt', 'Lime']});

      expect(cart.items, hasLength(1));
      expect(cart.items.single.quantity, 2);
    });

    test('different menu items never merge', () {
      final cart = const OrderCart()
          .add(_item(id: 'i1', name: 'Lager'))
          .add(_item(id: 'i2', name: 'Stout'));

      expect(cart.items, hasLength(2));
    });
  });

  group('OrderCart quantity edits', () {
    test('setQuantity to zero removes the line', () {
      final cart = const OrderCart().add(_item());
      final after = cart.setQuantity(cart.items.single.id, 0);

      expect(after.isEmpty, isTrue);
    });

    test('a negative quantity also removes rather than going negative', () {
      final cart = const OrderCart().add(_item());
      final after = cart.setQuantity(cart.items.single.id, -2);

      expect(after.isEmpty, isTrue);
    });

    test('editing an unknown line id is a no-op, not a crash', () {
      final cart = const OrderCart().add(_item());

      expect(cart.setQuantity('nope', 5).items, hasLength(1));
      expect(cart.remove('nope').items, hasLength(1));
      expect(cart.setNotes('nope', 'x').items.single.notes, '');
    });

    test('the original cart is unchanged by an edit', () {
      final cart = const OrderCart().add(_item());
      cart.setQuantity(cart.items.single.id, 9);

      expect(cart.items.single.quantity, 1);
    });
  });

  group('OrderCart totals', () {
    test('subtotal multiplies unit price by quantity', () {
      final cart = const OrderCart().add(_item(price: 4.5), quantity: 3);

      expect(cart.subtotal, closeTo(13.5, 0.001));
    });

    test('a modifier price adjustment is included in the subtotal', () {
      final item = _item(
        price: 10.0,
        modifiers: [
          MenuModifier(
            name: 'Size',
            options: [MenuModifierOption(name: 'Large', priceAdjustment: 2.0)],
          ),
        ],
      );
      final cart = const OrderCart().add(
        item,
        quantity: 2,
        modifiers: {'Size': ['Large']},
      );

      expect(cart.subtotal, closeTo(24.0, 0.001));
    });

    test('an empty cart totals zero', () {
      expect(const OrderCart().subtotal, 0.0);
      expect(const OrderCart().totalQuantity, 0);
    });
  });
}
