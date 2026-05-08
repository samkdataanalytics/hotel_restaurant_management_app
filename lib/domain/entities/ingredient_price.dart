class IngredientPrice {
  final String id;
  final String ingredientId;
  final double pricePerUnit;
  final DateTime date;
  final String? note;

  IngredientPrice({
    required this.id,
    required this.ingredientId,
    required this.pricePerUnit,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ingredientId': ingredientId,
        'pricePerUnit': pricePerUnit,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory IngredientPrice.fromMap(Map<String, dynamic> map) {
    return IngredientPrice(
      id: map['id'],
      ingredientId: map['ingredientId'],
      pricePerUnit: (map['pricePerUnit'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'],
    );
  }
}
