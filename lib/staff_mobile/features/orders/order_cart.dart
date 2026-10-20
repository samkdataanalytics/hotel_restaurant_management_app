import 'package:uuid/uuid.dart';

import '../../../domain/entities/menu_item.dart';
import '../../../domain/entities/restaurant_order.dart';

const _uuid = Uuid();

/// A round being built for one table, before it is fired to the kitchen.
///
/// Immutable so the screen's state transitions stay obvious and undo is a
/// matter of keeping the previous value.
class OrderCart {
  final List<OrderItem> items;

  const OrderCart({this.items = const []});

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  /// Pre-tax, pre-service-charge total for the round being built.
  /// `OrderItem.unitPrice` already folds in modifier price adjustments.
  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);

  /// Adds [item], merging into an existing line when the menu item, modifier
  /// selection and note all match.
  ///
  /// Merging matters on a real floor: three of the same beer should read as
  /// "3 x Lager", not three identical lines a waiter has to count. A different
  /// note or modifier genuinely is a different line — the kitchen needs them
  /// separated.
  OrderCart add(
    MenuItem item, {
    int quantity = 1,
    Map<String, List<String>> modifiers = const {},
    String notes = '',
  }) {
    final index = items.indexWhere((existing) =>
        existing.menuItem.id == item.id &&
        existing.notes == notes &&
        _sameModifiers(existing.selectedModifiers, modifiers));

    if (index == -1) {
      return OrderCart(items: [
        ...items,
        OrderItem(
          id: _uuid.v4(),
          menuItem: item,
          quantity: quantity,
          notes: notes,
          selectedModifiers: modifiers,
        ),
      ]);
    }

    return _replaceAt(
      index,
      items[index].copyWith(quantity: items[index].quantity + quantity),
    );
  }

  /// Sets an absolute quantity, removing the line at zero.
  OrderCart setQuantity(String lineId, int quantity) {
    final index = items.indexWhere((i) => i.id == lineId);
    if (index == -1) return this;
    if (quantity <= 0) {
      return OrderCart(items: [...items]..removeAt(index));
    }
    return _replaceAt(index, items[index].copyWith(quantity: quantity));
  }

  OrderCart setNotes(String lineId, String notes) {
    final index = items.indexWhere((i) => i.id == lineId);
    if (index == -1) return this;
    return _replaceAt(index, items[index].copyWith(notes: notes));
  }

  OrderCart remove(String lineId) =>
      OrderCart(items: items.where((i) => i.id != lineId).toList());

  OrderCart clear() => const OrderCart();

  OrderCart _replaceAt(int index, OrderItem item) {
    final next = [...items];
    next[index] = item;
    return OrderCart(items: next);
  }

  /// Order-insensitive comparison of two modifier selections.
  static bool _sameModifiers(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.length != entry.value.length) return false;
      final sortedA = [...entry.value]..sort();
      final sortedB = [...other]..sort();
      for (var i = 0; i < sortedA.length; i++) {
        if (sortedA[i] != sortedB[i]) return false;
      }
    }
    return true;
  }
}
