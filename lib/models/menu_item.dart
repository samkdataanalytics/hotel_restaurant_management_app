class MenuItemIngredient {
  final String ingredientId;
  final double quantity;

  MenuItemIngredient({required this.ingredientId, required this.quantity});

  MenuItemIngredient copyWith({String? ingredientId, double? quantity}) {
    return MenuItemIngredient(
      ingredientId: ingredientId ?? this.ingredientId,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() => {'ingredientId': ingredientId, 'quantity': quantity};

  factory MenuItemIngredient.fromMap(Map<String, dynamic> map) {
    return MenuItemIngredient(
      ingredientId: map['ingredientId'],
      quantity: (map['quantity'] as num).toDouble(),
    );
  }
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;
  final bool isAvailable;
  final List<MenuItemIngredient> ingredients;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl = '',
    this.isAvailable = true,
    this.ingredients = const [],
  });

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    bool? isAvailable,
    List<MenuItemIngredient>? ingredients,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'ingredients': ingredients.map((e) => e.toMap()).toList(),
    };
  }

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Uncategorized',
      imageUrl: map['imageUrl'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      ingredients: (map['ingredients'] as List<dynamic>?)
              ?.map((e) => MenuItemIngredient.fromMap(e))
              .toList() ??
          [],
    );
  }
}
