import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/restaurant_order.dart';
import '../../providers/service_providers.dart';
import '../../services/restaurant_service.dart';
import 'connectivity.dart';
import 'local_store.dart';

const _uuid = Uuid();

/// Snapshot of the queue for the UI.
class OutboxState {
  final List<OutboxEntry> entries;
  final bool draining;

  const OutboxState({this.entries = const [], this.draining = false});

  List<OutboxEntry> get pending =>
      entries.where((e) => !e.isBlocked).toList();
  List<OutboxEntry> get blocked =>
      entries.where((e) => e.isBlocked).toList();

  int get pendingCount => pending.length;
  int get blockedCount => blocked.length;
  bool get isEmpty => entries.isEmpty;

  /// Order ids waiting to reach the server, so the floor board can show a
  /// table as occupied before its order has synced.
  Set<String> get pendingOrderIds => {
        for (final e in entries)
          if (e.payload['orderId'] is String) e.payload['orderId'] as String,
      };
}

/// Queues order writes made while offline and replays them on reconnect.
///
/// ## The conflict rule
///
/// `addItemsToOrder` is a read-modify-write: it reads the order, appends to its
/// `items` array, and writes the whole array back. Replaying a *stale* version
/// of that write would silently delete anything another device added in the
/// meantime — a waiter's entire second round vanishing with no error.
///
/// So an append is never replayed as a recorded final array. Only the items the
/// waiter actually added are queued, and on replay they are appended to
/// whatever the order looks like *then*, by calling the same service method
/// again. Two devices appending concurrently both keep their items.
///
/// A new order is queued as a complete [RestaurantOrder] with its id and
/// `createdAt` fixed at the moment it was taken. Replaying goes through
/// `saveOrder`, which upserts and deducts inventory only when the row is new —
/// so a repeated replay cannot create a twin or double-deduct stock. Fixing
/// `createdAt` at queue time also means an order taken at 19:04 and synced at
/// 19:40 still reads as 19:04, which is what the kitchen queue needs.
///
/// ## What is deliberately not queued
///
/// Payments, refunds, cancellations and status changes are online-only. Each
/// depends on server state that cannot be reconciled blind — settling a bill
/// against a stale total, or refunding an order someone else already voided,
/// produces money errors rather than a merge conflict. They fail with a clear
/// message instead.
class Outbox extends Notifier<OutboxState> {
  bool _draining = false;

  @override
  OutboxState build() {
    // Drain when the device comes back online, not on every connectivity tick.
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      final wasOffline = previous?.valueOrNull == false;
      final isOnline = next.valueOrNull == true;
      if (wasOffline && isOnline) unawaited(drain());
    });

    return OutboxState(entries: _read());
  }

  List<OutboxEntry> _read() => ref.read(localStoreProvider).readOutbox();

  void _refresh() => state = OutboxState(entries: _read(), draining: _draining);

  /// Queues a complete new order. Returns it so the caller can show it
  /// immediately without waiting for the server.
  Future<RestaurantOrder> queueCreateOrder({
    required String propertyId,
    required String tableId,
    required List<OrderItem> items,
    OrderType type = OrderType.dineIn,
  }) async {
    final ts = DateTime.now();
    final order = RestaurantOrder(
      // Same shape createTableOrder would have produced, built here so the id
      // is stable across retries.
      id: _uuid.v4(),
      orderNumber: ts.millisecondsSinceEpoch.toString().substring(7),
      tableId: tableId,
      type: type,
      status: OrderStatus.pending,
      paymentStatus: PaymentStatus.unpaid,
      createdAt: ts,
      items: items,
    );

    await ref.read(localStoreProvider).enqueue(
          OutboxEntry(
            id: _uuid.v4(),
            kind: OutboxKind.createOrder,
            propertyId: propertyId,
            queuedAt: ts,
            payload: {
              'orderId': order.id,
              'tableNumber': '',
              'order': order.toMap(),
            },
          ),
        );
    _refresh();
    return order;
  }

  /// Queues extra items for an order that already exists.
  Future<void> queueAddItems({
    required String propertyId,
    required String orderId,
    required List<OrderItem> items,
  }) async {
    await ref.read(localStoreProvider).enqueue(
          OutboxEntry(
            id: _uuid.v4(),
            kind: OutboxKind.addItems,
            propertyId: propertyId,
            queuedAt: DateTime.now(),
            payload: {
              'orderId': orderId,
              // Only the added items — see the conflict rule above.
              'items': items.map((i) => i.toMap()).toList(),
            },
          ),
        );
    _refresh();
  }

  /// Replays queued writes oldest first, stopping at the first failure.
  ///
  /// Stopping rather than skipping is deliberate: entries can depend on each
  /// other — a second round appended to an order created in the same offline
  /// stretch — so pushing past a failure would apply them out of order.
  Future<void> drain() async {
    if (_draining) return;
    final store = ref.read(localStoreProvider);
    final queued = store.readOutbox().where((e) => !e.isBlocked).toList();
    if (queued.isEmpty) return;

    _draining = true;
    _refresh();

    final service = ref.read(restaurantServiceProvider);

    for (final entry in queued) {
      try {
        await _apply(service, entry);
        await store.remove(entry.id);
      } catch (e) {
        debugPrint('Outbox: ${entry.kind.name} failed: $e');
        await store.update(
          entry.copyWith(attempts: entry.attempts + 1, lastError: '$e'),
        );
        break; // preserve ordering
      }
    }

    _draining = false;
    _refresh();
  }

  /// Retries entries that exhausted their attempts, at a person's request.
  Future<void> retryBlocked() async {
    final store = ref.read(localStoreProvider);
    for (final entry in store.readOutbox().where((e) => e.isBlocked)) {
      await store.update(entry.copyWith(attempts: 0, lastError: null));
    }
    _refresh();
    await drain();
  }

  /// Abandons one queued write. Only reachable from an explicit user action on
  /// a blocked entry — a queued order is never discarded silently.
  Future<void> discard(String entryId) async {
    await ref.read(localStoreProvider).remove(entryId);
    _refresh();
  }

  Future<void> _apply(RestaurantService service, OutboxEntry entry) async {
    switch (entry.kind) {
      case OutboxKind.createOrder:
        // saveOrder upserts and deducts inventory only when the row is new, so
        // replaying twice is safe without an existence check of our own.
        await service.saveOrder(
          RestaurantOrder.fromMap(
            Map<String, dynamic>.from(entry.payload['order'] as Map),
          ),
        );

      case OutboxKind.addItems:
        // Re-applies the append against the order's current state rather than
        // writing back a stale array. This is the conflict rule.
        final items = (entry.payload['items'] as List)
            .map((raw) =>
                OrderItem.fromMap(Map<String, dynamic>.from(raw as Map)))
            .toList();
        await service.addItemsToOrder(
          entry.payload['orderId'] as String,
          items,
        );
    }
  }
}

final outboxProvider = NotifierProvider<Outbox, OutboxState>(Outbox.new);
