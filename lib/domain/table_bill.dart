import 'entities/restaurant_order.dart';

/// A fully computed table bill.
///
/// Every figure a receipt or settle screen needs, derived once so a screen can
/// never show a total that differs from the one actually charged.
class TableBill {
  /// Sum of item prices across every open order, before any discount.
  final double itemsTotal;

  /// Currency value of the discount, however it was expressed.
  final double discountValue;

  /// itemsTotal minus the discount, floored at zero.
  final double subtotal;

  final double tax;
  final double serviceCharge;

  /// What the guest pays.
  final double total;

  /// True when the table mixes dine-in with takeaway or delivery, so the
  /// service charge covers only part of the bill and the UI should say so.
  final bool hasMixedOrderTypes;

  /// Portion of the bill the service charge applied to, 0.0–1.0.
  final double serviceChargeFraction;

  const TableBill({
    required this.itemsTotal,
    required this.discountValue,
    required this.subtotal,
    required this.tax,
    required this.serviceCharge,
    required this.total,
    required this.hasMixedOrderTypes,
    required this.serviceChargeFraction,
  });
}

/// How a discount was expressed.
///
/// Matches the strings stored in `restaurant_orders.discount_type`.
abstract final class DiscountType {
  static const percentage = 'percentage';
  static const flat = 'flat';
}

/// Computes what a table owes.
///
/// This is deliberately one function. The same arithmetic currently appears
/// three times by hand in `lib/web/table_floor_screen.dart` (around lines 232,
/// 1131 and 1579), and the third differs from the other two — it bases the
/// subtotal on `totalAmount` rather than `itemsTotal`, so an order carrying a
/// stored discount produces a different figure there than in the settle dialog.
/// Money logic duplicated by hand is exactly what drifts, so the mobile app
/// calls this instead of growing a fourth copy. Consolidating the web's three
/// onto it is worth doing, but as its own change with its own testing rather
/// than as a side effect of mobile work.
///
/// Semantics follow the web's **settle** path, because that is what actually
/// charges the guest:
///   * The base is `itemsTotal` (pre-discount), not `totalAmount`.
///   * Tax applies to the discounted subtotal.
///   * Service charge applies only to the dine-in and room-service share of
///     the bill — a takeaway collected at the counter is not table service, so
///     charging service on it would be wrong.
TableBill computeTableBill({
  required List<RestaurantOrder> orders,
  required double taxRate,
  required double serviceChargeRate,
  String? discountType,
  double discountAmount = 0.0,
}) {
  final itemsTotal = orders.fold<double>(0.0, (sum, o) => sum + o.itemsTotal);

  final discountValue = discountAmount <= 0
      ? 0.0
      : discountType == DiscountType.percentage
          // A percentage over 100 would make the discount exceed the bill and
          // flip the subtotal negative, so it is capped.
          ? itemsTotal * (discountAmount.clamp(0.0, 100.0) / 100)
          : discountAmount;

  final subtotal = (itemsTotal - discountValue).clamp(0.0, double.infinity);
  final tax = subtotal * taxRate;

  bool isServiceable(RestaurantOrder o) =>
      o.type != OrderType.takeaway && o.type != OrderType.delivery;

  final serviceableTotal = orders
      .where(isServiceable)
      .fold<double>(0.0, (sum, o) => sum + o.itemsTotal);

  // An empty table defaults to a full service charge rather than none, so a
  // zero bill does not silently imply "service charge does not apply here".
  final fraction = itemsTotal > 0 ? serviceableTotal / itemsTotal : 1.0;
  final serviceCharge = fraction * subtotal * serviceChargeRate;

  final hasMixed =
      orders.any(isServiceable) && orders.any((o) => !isServiceable(o));

  return TableBill(
    itemsTotal: itemsTotal,
    // Report what was actually deducted, not what was asked for: a flat
    // discount larger than the bill cannot take more than the bill.
    discountValue: (itemsTotal - subtotal).clamp(0.0, itemsTotal),
    subtotal: subtotal,
    tax: tax,
    serviceCharge: serviceCharge,
    total: subtotal + tax + serviceCharge,
    hasMixedOrderTypes: hasMixed,
    serviceChargeFraction: fraction,
  );
}
