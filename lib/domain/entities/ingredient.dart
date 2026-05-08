class Ingredient {
  final String id;
  final String name;
  final String unit; // e.g. kg, litre, piece, gram, ml

  Ingredient({
    required this.id,
    required this.name,
    required this.unit,
  });

  Ingredient copyWith({String? id, String? name, String? unit}) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'unit': unit};

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'],
      name: map['name'],
      unit: map['unit'] ?? 'kg',
    );
  }
}
