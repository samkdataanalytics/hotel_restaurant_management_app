import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/menu_item.dart';
import '../domain/entities/restaurant_table.dart';
import 'notification_service.dart';

class GuestMenuService {
  final _db = Supabase.instance.client;

  // ─── Menu items ────────────────────────────────────────────────────────────

  Future<List<MenuItem>> getAvailableMenuItems(String propertyId) async {
    final rows = await _db
        .from('menu_items')
        .select()
        .eq('hotel_id', propertyId)
        .eq('is_available', true)
        .order('category')
        .order('name');
    return rows.map<MenuItem>((r) => MenuItem.fromMap({
          'id': r['id'],
          'name': r['name'],
          'description': r['description'] ?? '',
          'price': r['price'],
          'category': r['category'] ?? 'Uncategorized',
          'imageUrl': r['image_url'] ?? '',
          'isAvailable': r['is_available'] ?? true,
          'ingredients': r['ingredients'] ?? [],
          'modifiers': r['modifiers'] ?? [],
        })).toList();
  }

  // ─── Table info ────────────────────────────────────────────────────────────

  Future<RestaurantTable?> getTable(
      String propertyId, String tableId) async {
    final rows = await _db
        .from('restaurant_tables')
        .select()
        .eq('hotel_id', propertyId)
        .eq('id', tableId)
        .limit(1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return RestaurantTable.fromMap({
      'id': r['id'],
      'tableNumber': r['table_number'],
      'capacity': r['capacity'] ?? 2,
      'status': r['status'] ?? 'available',
    });
  }

  // ─── Property name ─────────────────────────────────────────────────────────

  Future<String> getPropertyName(String propertyId) async {
    try {
      final rows = await _db
          .from('hotels')
          .select('name')
          .eq('id', propertyId)
          .limit(1);
      return rows.isNotEmpty ? (rows.first['name'] as String? ?? 'Restaurant') : 'Restaurant';
    } catch (_) {
      return 'Restaurant';
    }
  }

  // ─── Settings (tax / service charge) ──────────────────────────────────────

  Future<({double taxRate, double serviceChargeRate, String primaryColorHex, String logoUrl, String currencySymbol})>
      getSettings(String propertyId) async {
    try {
      final rows = await _db
          .from('hotel_settings')
          .select('tax_rate, service_charge_rate, primary_color, logo_url, currency_symbol')
          .eq('hotel_id', propertyId)
          .limit(1);
      if (rows.isEmpty) {
        return (taxRate: 0.0, serviceChargeRate: 0.0, primaryColorHex: '#D4A853', logoUrl: '', currencySymbol: '\$');
      }
      final r = rows.first;
      return (
        taxRate: (r['tax_rate'] as num?)?.toDouble() ?? 0.0,
        serviceChargeRate:
            (r['service_charge_rate'] as num?)?.toDouble() ?? 0.0,
        primaryColorHex: r['primary_color'] as String? ?? '#D4A853',
        logoUrl: r['logo_url'] as String? ?? '',
        currencySymbol: r['currency_symbol'] as String? ?? '\$',
      );
    } catch (_) {
      return (taxRate: 0.0, serviceChargeRate: 0.0, primaryColorHex: '#D4A853', logoUrl: '', currencySymbol: '\$');
    }
  }

  // ─── Place order ───────────────────────────────────────────────────────────

  /// Places a new dine-in order from the guest portal.
  /// Pass [parentOrderId] to link this as an add-on to an existing order.
  /// Returns the created order ID.
  Future<String> placeOrder({
    required String propertyId,
    required String tableId,
    required List<({MenuItem item, int qty, String notes, Map<String, List<String>>? modifiers})> cartItems,
    String? parentOrderId,
    String type = 'dineIn',
  }) async {
    final orderId = const Uuid().v4();
    final prefix = type == 'roomService' ? 'RS' : 'QR';
    final orderNumber =
        '$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final itemsJson = cartItems.map((e) => {
          'id': const Uuid().v4(),
          'menuItem': e.item.toMap(),
          'quantity': e.qty,
          'notes': e.notes,
          'selectedModifiers': e.modifiers ?? {},
          'isRefunded': false,
          'refundedQuantity': 0,
        }).toList();

    await _db.from('restaurant_orders').insert({
      'id': orderId,
      'order_number': orderNumber,
      // room service orders pass room number as tableId — store in room_number
      // column (TEXT) instead of table_id (UUID) to avoid type mismatch.
      if (type == 'roomService') 'room_number': tableId
      else 'table_id': tableId,
      'hotel_id': propertyId,
      'type': type,
      'status': 'pending',
      'payment_status': 'unpaid',
      'items': itemsJson,
      'created_at': DateTime.now().toIso8601String(),
      'inventory_restored': false,
      'discount_amount': 0,
      if (parentOrderId != null) 'parent_order_id': parentOrderId,
    });

    // Fire room service notification for staff (non-blocking)
    if (type == 'roomService') {
      final itemCount = cartItems.fold(0, (sum, e) => sum + e.qty);
      final total = cartItems.fold(
          0.0, (sum, e) {
            double base = e.item.price;
            e.modifiers?.forEach((cat, list) {
               final mod = e.item.modifiers.where((m) => m.name == cat).firstOrNull;
               if (mod != null) {
                 for (final optName in list) {
                   final opt = mod.options.where((o) => o.name == optName).firstOrNull;
                   if (opt != null) base += opt.priceAdjustment;
                 }
               }
            });
            return sum + base * e.qty;
          });
      NotificationService(propertyId).notifyRoomServiceOrder(
        orderNumber: orderNumber,
        roomNumber: tableId,
        itemCount: itemCount,
        total: total,
      );
    }

    return orderId;
  }

  // ─── Fetch order status (direct REST query — no Realtime required) ───────
  /// Returns null if not found.
  Future<({String status, String paymentStatus})?> fetchOrderStatus(String orderId) async {
    final rows = await _db
        .from('restaurant_orders')
        .select('status, payment_status')
        .eq('id', orderId)
        .limit(1);
    if (rows.isEmpty) return null;
    return (
      status: rows.first['status'] as String? ?? 'pending',
      paymentStatus: rows.first['payment_status'] as String? ?? 'unpaid',
    );
  }

  // ─── Watch order (status + payment_status) ────────────────────────────────

  Stream<String?> watchOrderStatus(String orderId) {
    return _db
        .from('restaurant_orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) => rows.isNotEmpty ? rows.first['status'] as String? : null);
  }

  /// Streams both [status] and [paymentStatus] for a given order.
  Stream<({String status, String paymentStatus})> watchOrder(String orderId) {
    return _db
        .from('restaurant_orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) {
          if (rows.isEmpty) {
            return (status: 'pending', paymentStatus: 'unpaid');
          }
          final r = rows.first;
          return (
            status: r['status'] as String? ?? 'pending',
            paymentStatus: r['payment_status'] as String? ?? 'unpaid',
          );
        });
  }

  // ─── Cancel order (via SECURITY DEFINER RPC — works from anon client) ──────

  /// Calls the `cancel_guest_order` Postgres function.
  /// Returns one of: 'cancelled' | 'not_cancellable' | 'already_cancelled' | 'not_found'
  Future<String> cancelOrder(String orderId) async {
    try {
      final result = await _db.rpc(
        'cancel_guest_order',
        params: {'p_order_id': orderId},
      );
      return result as String? ?? 'not_found';
    } catch (e) {
      debugPrint('cancelOrder error: $e');
      return 'error';
    }
  }

  // ─── Submit guest feedback ─────────────────────────────────────────────────

  Future<void> submitFeedback({
    required String propertyId,
    required String tableId,
    required String orderId,
    required int rating,        // 1–5
    String? comment,
  }) async {
    await _db.from('guest_feedback').insert({
      'property_id': propertyId,
      'table_id': tableId,
      'order_id': orderId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
