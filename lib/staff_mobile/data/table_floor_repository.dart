import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/menu_item.dart';
import '../../domain/entities/restaurant_order.dart';
import '../../domain/entities/restaurant_table.dart';
import '../../providers/service_providers.dart';

/// How a table reads on the floor board.
///
/// Derived from order state rather than `RestaurantTable.status`, because the
/// stored status only distinguishes available/occupied and goes stale — the
/// live truth is whether an unsettled order exists and how far along it is.
enum FloorState {
  /// No open order.
  free,

  /// Order exists and is still being prepared.
  inKitchen,

  /// Everything is ready or served — the table is eating.
  seated,

  /// Served and unpaid: the likely next interaction is the bill.
  billDue,
}

/// A table plus its live order context, as one row for the UI.
class TableFloorEntry {
  final RestaurantTable table;

  /// The order a new round would be appended to. Null when the table is free.
  final RestaurantOrder? activeOrder;

  /// Every unsettled order on this table (a table can carry more than one).
  final List<RestaurantOrder> openOrders;

  const TableFloorEntry({
    required this.table,
    this.activeOrder,
    this.openOrders = const [],
  });

  double get openTotal =>
      openOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

  int get openItemCount =>
      openOrders.fold(0, (sum, o) => sum + o.items.length);

  /// Age of the oldest open order — what tells a waiter a table is waiting.
  Duration? get waitingFor {
    if (openOrders.isEmpty) return null;
    final oldest = openOrders
        .map((o) => o.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime.now().difference(oldest);
  }

  FloorState get state {
    if (openOrders.isEmpty) return FloorState.free;

    final anyUnserved = openOrders.any((o) =>
        o.status == OrderStatus.pending || o.status == OrderStatus.preparing);
    if (anyUnserved) return FloorState.inKitchen;

    final allServed =
        openOrders.every((o) => o.status == OrderStatus.served);
    if (allServed) return FloorState.billDue;

    return FloorState.seated;
  }
}

/// Reads for the floor board and order entry.
///
/// **This is the offline seam.** Every table/menu read the mobile app performs
/// goes through here rather than calling `RestaurantService` from a widget, so
/// a read-through cache and a write outbox can be added later by changing this
/// one class — no screen has to know. Keep it that way: if a screen starts
/// calling `restaurantServiceProvider` directly, that property is lost.
class TableFloorRepository {
  final Ref _ref;
  TableFloorRepository(this._ref);

  /// The floor board in one call.
  ///
  /// Tables are fetched once, then each table's open orders are fetched
  /// concurrently. A sequential loop here is the difference between a snappy
  /// board and a visible stall on a 30-table floor.
  Future<List<TableFloorEntry>> loadFloor() async {
    final service = _ref.read(restaurantServiceProvider);
    final tables = await service.getTables();

    final entries = await Future.wait(
      tables.map((t) async {
        final open = await service.getOpenOrdersForTable(t.id);
        return TableFloorEntry(
          table: t,
          // The most recent open order is the one a new round appends to.
          activeOrder: open.isEmpty ? null : open.last,
          openOrders: open,
        );
      }),
    );

    entries.sort(_byTableNumber);
    return entries;
  }

  /// Sorts numerically where table numbers are numeric ("2" before "10"),
  /// falling back to a case-insensitive string compare for names like "Patio".
  static int _byTableNumber(TableFloorEntry a, TableFloorEntry b) {
    final an = int.tryParse(a.table.tableNumber.trim());
    final bn = int.tryParse(b.table.tableNumber.trim());
    if (an != null && bn != null) return an.compareTo(bn);
    if (an != null) return -1;
    if (bn != null) return 1;
    return a.table.tableNumber
        .toLowerCase()
        .compareTo(b.table.tableNumber.toLowerCase());
  }

  Future<TableFloorEntry> loadTable(String tableId) async {
    final service = _ref.read(restaurantServiceProvider);
    final tables = await service.getTables();
    final table = tables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => throw StateError('Table $tableId is not on this property'),
    );
    final open = await service.getOpenOrdersForTable(tableId);
    return TableFloorEntry(
      table: table,
      activeOrder: open.isEmpty ? null : open.last,
      openOrders: open,
    );
  }

  /// Menu for order entry — available items only, grouped by category.
  ///
  /// An 86'd item is filtered out here rather than in the UI so it cannot be
  /// added to a cart from any screen.
  Future<Map<String, List<MenuItem>>> loadMenuByCategory() async {
    final items = await _ref.read(restaurantServiceProvider).getMenuItems();
    final grouped = <String, List<MenuItem>>{};
    for (final item in items.where((i) => i.isAvailable)) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  Future<({double taxRate, double serviceChargeRate})> loadChargeSettings() =>
      _ref.read(restaurantServiceProvider).getChargeSettings();
}

final tableFloorRepositoryProvider = Provider<TableFloorRepository>(
  TableFloorRepository.new,
);
