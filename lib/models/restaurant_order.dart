import 'menu_item.dart';

enum OrderType { dineIn, takeaway }
enum OrderStatus { pending, preparing, ready, served, cancelled }
enum PaymentStatus { unpaid, paid, chargedToRoom }

class OrderItem {
  final String id;
  final MenuItem menuItem;
  int quantity;
  String notes;
  bool isRefunded;

  OrderItem({
    required this.id,
    required this.menuItem,
    this.quantity = 1,
    this.notes = '',
    this.isRefunded = false,
  });

  double get subtotal => isRefunded ? 0.0 : (menuItem.price * quantity);

  OrderItem copyWith({
    String? id,
    MenuItem? menuItem,
    int? quantity,
    String? notes,
    bool? isRefunded,
  }) {
    return OrderItem(
      id: id ?? this.id,
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      isRefunded: isRefunded ?? this.isRefunded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuItem': menuItem.toMap(),
      'quantity': quantity,
      'notes': notes,
      'isRefunded': isRefunded,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      menuItem: MenuItem.fromMap(map['menuItem']),
      quantity: map['quantity']?.toInt() ?? 1,
      notes: map['notes'] ?? '',
      isRefunded: map['isRefunded'] ?? false,
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
  });

  double get totalAmount => items.fold(0.0, (sum, item) => sum + item.subtotal);

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
    );
  }
}
