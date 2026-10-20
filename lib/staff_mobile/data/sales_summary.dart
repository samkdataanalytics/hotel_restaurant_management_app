import '../../domain/entities/restaurant_order.dart';

/// Service periods, for reading covers by time of day.
enum Daypart { breakfast, lunch, dinner, late }

extension DaypartX on Daypart {
  String get label => switch (this) {
        Daypart.breakfast => 'Breakfast',
        Daypart.lunch => 'Lunch',
        Daypart.dinner => 'Dinner',
        Daypart.late => 'Late',
      };

  /// Boundaries chosen to match how a kitchen actually runs rather than even
  /// six-hour blocks: lunch and dinner are the two that matter, so they get
  /// their own windows and everything else falls either side.
  static Daypart forHour(int hour) {
    if (hour < 11) return Daypart.breakfast;
    if (hour < 16) return Daypart.lunch;
    if (hour < 22) return Daypart.dinner;
    return Daypart.late;
  }
}

/// One menu item's contribution.
class ItemSales {
  final String name;
  final int quantity;
  final double revenue;

  const ItemSales({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}

/// What sold, over some window.
class SalesSummary {
  final double revenue;
  final int orderCount;
  final int itemCount;
  final List<ItemSales> topItems;
  final Map<Daypart, int> ordersByDaypart;

  const SalesSummary({
    this.revenue = 0,
    this.orderCount = 0,
    this.itemCount = 0,
    this.topItems = const [],
    this.ordersByDaypart = const {},
  });

  double get averageOrder => orderCount == 0 ? 0 : revenue / orderCount;
}

/// Summarises orders for a period.
///
/// Counts only settled orders. An order still open on a table is not revenue —
/// including it would make the figure drift up and down as tables come and go,
/// and overstate a shift that has not been paid for yet. Cancelled orders are
/// excluded outright, and refunded lines fall out naturally because
/// `activeQuantity` and `subtotal` already discount them.
SalesSummary summariseSales(
  List<RestaurantOrder> orders, {
  required DateTime from,
  required DateTime to,
  int topCount = 5,
}) {
  final settled = orders.where((o) {
    if (o.status == OrderStatus.cancelled) return false;
    if (o.paymentStatus == PaymentStatus.unpaid) return false;
    return !o.createdAt.isBefore(from) && !o.createdAt.isAfter(to);
  }).toList();

  if (settled.isEmpty) return const SalesSummary();

  var revenue = 0.0;
  var itemCount = 0;
  final byItem = <String, ItemSales>{};
  final byDaypart = <Daypart, int>{};

  for (final order in settled) {
    revenue += order.totalAmount;

    final part = DaypartX.forHour(order.createdAt.hour);
    byDaypart[part] = (byDaypart[part] ?? 0) + 1;

    for (final item in order.items) {
      final qty = item.activeQuantity;
      if (qty <= 0) continue;
      itemCount += qty;

      // Grouped by name, not id: the same dish re-created in the menu editor
      // gets a new id, and splitting it across two rows would hide a
      // best-seller from the very list meant to reveal it.
      final name = item.menuItem.name;
      final existing = byItem[name];
      byItem[name] = ItemSales(
        name: name,
        quantity: (existing?.quantity ?? 0) + qty,
        revenue: (existing?.revenue ?? 0) + item.subtotal,
      );
    }
  }

  final top = byItem.values.toList()
    ..sort((a, b) {
      final byQuantity = b.quantity.compareTo(a.quantity);
      // Ties broken by revenue, so a £40 steak outranks a £2 side that sold
      // the same number.
      return byQuantity != 0 ? byQuantity : b.revenue.compareTo(a.revenue);
    });

  return SalesSummary(
    revenue: revenue,
    orderCount: settled.length,
    itemCount: itemCount,
    topItems: top.take(topCount).toList(),
    ordersByDaypart: byDaypart,
  );
}
