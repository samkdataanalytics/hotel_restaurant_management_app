import 'menu_item.dart';

enum OrderType { dineIn, takeaway, roomService }
enum OrderStatus { pending, preparing, ready, served, cancelled }
enum PaymentStatus { unpaid, paid, chargedToRoom }

class OrderItem {
  final String id;
  final MenuItem menuItem;
  int quantity;
  String notes;
  bool isRefunded;       // true = ALL units refunded (full refund)
  int refundedQuantity;  // number of units refunded so far (partial or full)

  OrderItem({
    required this.id,
    required this.menuItem,
    this.quantity = 1,
    this.notes = '',
    this.isRefunded = false,
    this.refundedQuantity = 0,
  });

  /// Units still charged (ordered minus any refunds).
  int get activeQuantity {
    if (isRefunded) return 0;
    return (quantity - refundedQuantity).clamp(0, quantity);
  }

  /// True when no remaining chargeable units exist.
  bool get isFullyRefunded => isRefunded || refundedQuantity >= quantity;

  /// Amount still due (only the un-refunded portion).
  double get subtotal => menuItem.price * activeQuantity;

  OrderItem copyWith({
    String? id,
    MenuItem? menuItem,
    int? quantity,
    String? notes,
    bool? isRefunded,
    int? refundedQuantity,
  }) {
    return OrderItem(
      id: id ?? this.id,
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      isRefunded: isRefunded ?? this.isRefunded,
      refundedQuantity: refundedQuantity ?? this.refundedQuantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuItem': menuItem.toMap(),
      'quantity': quantity,
      'notes': notes,
      'isRefunded': isRefunded,
      'refundedQuantity': refundedQuantity,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final qty = map['quantity']?.toInt() ?? 1;
    final wasFullyRefunded = map['isRefunded'] as bool? ?? false;
    return OrderItem(
      id: map['id'],
      menuItem: MenuItem.fromMap(map['menuItem']),
      quantity: qty,
      notes: map['notes'] ?? '',
      isRefunded: wasFullyRefunded,
      // backwards-compat: if old record had isRefunded=true, treat all units as refunded
      refundedQuantity: wasFullyRefunded
          ? qty
          : (map['refundedQuantity']?.toInt() ?? 0),
    );
  }
}

class RestaurantOrder {
  final String id;
  final String orderNumber;
  final String? tableId;
  final OrderType type;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String? bookingId; // If charged to a hotel guest
  final DateTime createdAt;
  final List<OrderItem> items;
  /// True when a cancelled order had inventory restored (only for pending cancels).
  final bool inventoryRestored;
  /// null = this is a standalone / parent order.
  /// non-null = this is a child add-on order; value is the parent order's id.
  final String? parentOrderId;

  /// Discount applied at checkout. null = no discount.
  /// 'percentage' → discountAmount is 0-100 (e.g. 10 = 10%).
  /// 'flat'        → discountAmount is a currency value (e.g. 5.00).
  final String? discountType;
  final double  discountAmount;

  /// For room service orders: the room number the order was placed from.
  /// Null for dine-in / takeaway orders.
  final String? roomNumber;

  RestaurantOrder({
    required this.id,
    required this.orderNumber,
    this.tableId,
    required this.type,
    this.status = OrderStatus.pending,
    this.paymentStatus = PaymentStatus.unpaid,
    this.bookingId,
    required this.createdAt,
    required this.items,
    this.inventoryRestored = false,
    this.parentOrderId,
    this.discountType,
    this.discountAmount = 0.0,
    this.roomNumber,
  });

  double get itemsTotal => items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Computed discount value in currency units.
  double get discountValue {
    if (discountType == null || discountAmount <= 0) return 0.0;
    if (discountType == 'percentage') return itemsTotal * (discountAmount / 100);
    return discountAmount; // flat
  }

  double get totalAmount => (itemsTotal - discountValue).clamp(0.0, double.infinity);

  /// Fraction of the original item price that was actually paid after the
  /// order-level discount.  Used for computing per-item refund amounts.
  /// e.g.  10 % off  →  0.90;   $5 flat off a $20 order  →  0.75
  double get discountFactor {
    if (discountType == null || discountAmount <= 0 || itemsTotal <= 0) return 1.0;
    if (discountType == 'percentage') {
      return (1.0 - discountAmount / 100).clamp(0.0, 1.0);
    }
    // flat: distribute proportionally across all items
    return (1.0 - discountAmount / itemsTotal).clamp(0.0, 1.0);
  }

  /// Sentinel to distinguish "caller passed null" from "caller did not pass the field".
  static const _unset = Object();

  RestaurantOrder copyWith({
    String? id,
    String? orderNumber,
    String? tableId,
    OrderType? type,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    String? bookingId,
    DateTime? createdAt,
    List<OrderItem>? items,
    bool? inventoryRestored,
    String? parentOrderId,
    Object? discountType = _unset, // use Object? so null can be explicitly passed
    double? discountAmount,
    String? roomNumber,
  }) {
    return RestaurantOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      tableId: tableId ?? this.tableId,
      type: type ?? this.type,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      bookingId: bookingId ?? this.bookingId,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      inventoryRestored: inventoryRestored ?? this.inventoryRestored,
      parentOrderId: parentOrderId ?? this.parentOrderId,
      discountType: identical(discountType, _unset) ? this.discountType : discountType as String?,
      discountAmount: discountAmount ?? this.discountAmount,
      roomNumber: roomNumber ?? this.roomNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'tableId': tableId,
      'type': type.name,
      'status': status.name,
      'paymentStatus': paymentStatus.name,
      'bookingId': bookingId,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((x) => x.toMap()).toList(),
      'inventoryRestored': inventoryRestored,
      'parentOrderId': parentOrderId,
      'discountType': discountType,
      'discountAmount': discountAmount,
      'roomNumber': roomNumber,
    };
  }

  factory RestaurantOrder.fromMap(Map<String, dynamic> map) {
    return RestaurantOrder(
      id: map['id'],
      orderNumber: map['orderNumber'],
      tableId: map['tableId'],
      type: OrderType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => OrderType.dineIn,
      ),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['paymentStatus'],
        orElse: () => PaymentStatus.unpaid,
      ),
      bookingId: map['bookingId'],
      createdAt: DateTime.parse(map['createdAt']),
      items: List<OrderItem>.from(map['items']?.map((x) => OrderItem.fromMap(x)) ?? []),
      inventoryRestored: map['inventoryRestored'] as bool? ?? false,
      parentOrderId: map['parentOrderId'],
      discountType: map['discountType'] as String?,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      roomNumber: map['roomNumber'] as String?,
    );
  }
}
