class MenuModifierOption {
  final String name;
  final double priceAdjustment;
  final double costAdjustment;

  MenuModifierOption({required this.name, this.priceAdjustment = 0.0, this.costAdjustment = 0.0});

  MenuModifierOption copyWith({String? name, double? priceAdjustment, double? costAdjustment}) {
    return MenuModifierOption(
      name: name ?? this.name,
      priceAdjustment: priceAdjustment ?? this.priceAdjustment,
      costAdjustment: costAdjustment ?? this.costAdjustment,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'priceAdjustment': priceAdjustment,
    'costAdjustment': costAdjustment,
  };

  factory MenuModifierOption.fromMap(Map<String, dynamic> map) => MenuModifierOption(
        name: map['name'] ?? '',
        priceAdjustment: (map['priceAdjustment'] as num?)?.toDouble() ?? 0.0,
        costAdjustment: (map['costAdjustment'] as num?)?.toDouble() ?? 0.0,
      );
}

class MenuModifier {
  final String name; 
  final bool isRequired;
  final bool allowMultiple;
  final List<MenuModifierOption> options;

  MenuModifier({
    required this.name,
    this.isRequired = false,
    this.allowMultiple = false,
    required this.options,
  });

  MenuModifier copyWith({
    String? name,
    bool? isRequired,
    bool? allowMultiple,
    List<MenuModifierOption>? options,
  }) {
    return MenuModifier(
      name: name ?? this.name,
      isRequired: isRequired ?? this.isRequired,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'isRequired': isRequired,
        'allowMultiple': allowMultiple,
        'options': options.map((e) => e.toMap()).toList(),
      };

  factory MenuModifier.fromMap(Map<String, dynamic> map) => MenuModifier(
        name: map['name'] ?? '',
        isRequired: map['isRequired'] ?? false,
        allowMultiple: map['allowMultiple'] ?? false,
        options: (map['options'] as List<dynamic>?)
                ?.map((e) => MenuModifierOption.fromMap(e))
                .toList() ??
            [],
      );
}

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
  final List<MenuModifier> modifiers;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl = '',
    this.isAvailable = true,
    this.ingredients = const [],
    this.modifiers = const [],
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
    List<MenuModifier>? modifiers,
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
      modifiers: modifiers ?? this.modifiers,
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
      'modifiers': modifiers.map((e) => e.toMap()).toList(),
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
      modifiers: (map['modifiers'] as List<dynamic>?)
              ?.map((e) => MenuModifier.fromMap(e))
              .toList() ??
          [],
    );
  }
}
