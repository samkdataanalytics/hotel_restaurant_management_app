import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/menu_item.dart';
import '../../domain/entities/restaurant_order.dart';
import '../../domain/entities/restaurant_table.dart';
import '../../providers/service_providers.dart';
import '../session/staff_session.dart';
import 'local_store.dart';

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

  /// Cache representation. Reuses the entities' own toMap so the stored shape
  /// tracks the domain model rather than drifting from it.
  Map<String, dynamic> toCache() => {
        'table': table.toMap(),
        'openOrders': openOrders.map((o) => o.toMap()).toList(),
      };

  factory TableFloorEntry.fromCache(Map<String, dynamic> m) {
    final orders = (m['openOrders'] as List? ?? [])
        .map((o) => RestaurantOrder.fromMap(Map<String, dynamic>.from(o as Map)))
        .toList();
    return TableFloorEntry(
      table: RestaurantTable.fromMap(Map<String, dynamic>.from(m['table'] as Map)),
      activeOrder: orders.isEmpty ? null : orders.last,
      openOrders: orders,
    );
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
/// A value plus where it came from, so a screen can say "showing data from
/// 12 minutes ago" instead of silently presenting stale numbers as live.
class Cached<T> {
  final T value;

  /// True when the network read failed and this came from the cache.
  final bool isStale;

  /// When the cached copy was stored. Null when [value] is fresh.
  final DateTime? cachedAt;

  const Cached(this.value, {this.isStale = false, this.cachedAt});

  Duration? get age => cachedAt == null ? null : DateTime.now().difference(cachedAt!);
}

class RestaurantRepository {
  final Ref _ref;
  RestaurantRepository(this._ref);

  String? get _propertyId =>
      _ref.read(staffSessionProvider).valueOrNull?.activeProperty?.id;

  /// Read-through cache.
  ///
  /// Tries the network first and refreshes the cache on success. On failure
  /// falls back to the last good copy rather than showing an error — a waiter
  /// on a dead spot needs yesterday's menu far more than a red screen. Throws
  /// only when there is no cached copy either, because then there is genuinely
  /// nothing to show.
  Future<Cached<T>> _readThrough<T>({
    required String key,
    required Future<T> Function() fetch,
    required Object Function(T) encode,
    required T Function(dynamic) decode,
  }) async {
    final store = _ref.read(localStoreProvider);
    final propertyId = _propertyId;

    try {
      final fresh = await fetch();
      if (propertyId != null) {
        await store.writeCache(propertyId, key, encode(fresh));
      }
      return Cached(fresh);
    } catch (e) {
      if (propertyId == null) rethrow;
      final cached = store.readCache(propertyId, key);
      if (cached == null) rethrow;
      return Cached(
        decode(cached.value),
        isStale: true,
        cachedAt: cached.savedAt,
      );
    }
  }

  /// The floor board in one call.
  ///
  /// Tables are fetched once, then each table's open orders are fetched
  /// concurrently. A sequential loop here is the difference between a snappy
  /// board and a visible stall on a 30-table floor.
  Future<Cached<List<TableFloorEntry>>> loadFloor() => _readThrough(
        key: 'floor',
        fetch: _fetchFloor,
        // Tables and their open orders are cached separately from each other's
        // shape so a decode failure degrades to a cold read, not a crash.
        encode: (entries) => entries.map((e) => e.toCache()).toList(),
        decode: (raw) => (raw as List)
            .map((m) => TableFloorEntry.fromCache(
                Map<String, dynamic>.from(m as Map)))
            .toList(),
      );

  Future<List<TableFloorEntry>> _fetchFloor() async {
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
  Future<Cached<Map<String, List<MenuItem>>>> loadMenuByCategory() =>
      _readThrough(
        key: 'menu',
        fetch: _fetchMenu,
        // Stored flat and regrouped on read, so the cached shape does not
        // depend on how the UI happens to group it today.
        encode: (grouped) => [
          for (final items in grouped.values)
            for (final item in items) item.toMap(),
        ],
        decode: (raw) => _group(
          (raw as List).map(
            (m) => MenuItem.fromMap(Map<String, dynamic>.from(m as Map)),
          ),
        ),
      );

  Future<Map<String, List<MenuItem>>> _fetchMenu() async {
    final items = await _ref.read(restaurantServiceProvider).getMenuItems();
    return _group(items.where((i) => i.isAvailable));
  }

  static Map<String, List<MenuItem>> _group(Iterable<MenuItem> items) {
    final grouped = <String, List<MenuItem>>{};
    for (final item in items.where((i) => i.isAvailable)) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  /// Every order for the active property, newest first.
  ///
  /// `getOrders()` is already scoped to the active property's hotel_id by the
  /// repository layer, so this inherits tenancy without a filter here.
  Future<List<RestaurantOrder>> loadOrders() =>
      _ref.read(restaurantServiceProvider).getOrders();

  Future<({double taxRate, double serviceChargeRate})> loadChargeSettings() =>
      _ref.read(restaurantServiceProvider).getChargeSettings();
}

final restaurantRepositoryProvider = Provider<RestaurantRepository>(
  RestaurantRepository.new,
);
