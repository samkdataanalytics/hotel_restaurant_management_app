class MenuItemCostRecord {
  final String id;
  final String menuItemId;
  final double cost;
  final DateTime date;

  MenuItemCostRecord({
    required this.id,
    required this.menuItemId,
    required this.cost,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'menuItemId': menuItemId,
        'cost': cost,
        'date': date.toIso8601String(),
      };

  factory MenuItemCostRecord.fromMap(Map<String, dynamic> map) {
    return MenuItemCostRecord(
      id: map['id'],
      menuItemId: map['menuItemId'],
      cost: (map['cost'] as num).toDouble(),
      date: DateTime.parse(map['date']),
    );
  }
}
