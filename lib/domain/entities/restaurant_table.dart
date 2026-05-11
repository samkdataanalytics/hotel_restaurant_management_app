enum TableStatus { available, occupied }

class RestaurantTable {
  final String id;
  final String tableNumber;
  final int capacity;
  final TableStatus status;

  RestaurantTable({
    required this.id,
    required this.tableNumber,
    required this.capacity,
    this.status = TableStatus.available,
  });

  RestaurantTable copyWith({
    String? id,
    String? tableNumber,
    int? capacity,
    TableStatus? status,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tableNumber': tableNumber,
      'capacity': capacity,
      'status': status.name,
    };
  }

  factory RestaurantTable.fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      id: map['id'],
      tableNumber: map['tableNumber'],
      capacity: map['capacity']?.toInt() ?? 2,
      status: TableStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TableStatus.available,
      ),
    );
  }
}
