class InventoryItem {
  final String ingredientId;
  final double currentStock;
  final double minStockLevel; // alert threshold

  InventoryItem({
    required this.ingredientId,
    required this.currentStock,
    this.minStockLevel = 0,
  });

  bool get isLow => currentStock > 0 && currentStock <= minStockLevel;
  bool get isOut => currentStock <= 0;
  bool get isOk => currentStock > minStockLevel;

  InventoryItem copyWith({double? currentStock, double? minStockLevel}) {
    return InventoryItem(
      ingredientId: ingredientId,
      currentStock: currentStock ?? this.currentStock,
      minStockLevel: minStockLevel ?? this.minStockLevel,
    );
  }

  Map<String, dynamic> toMap() => {
        'ingredientId': ingredientId,
        'currentStock': currentStock,
        'minStockLevel': minStockLevel,
      };

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      ingredientId: map['ingredientId'],
      currentStock: (map['currentStock'] as num).toDouble(),
      minStockLevel: (map['minStockLevel'] as num?)?.toDouble() ?? 0,
    );
  }
}
