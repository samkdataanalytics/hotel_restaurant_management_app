enum ExpenseCategory { cleaning, maintenance, utilities, supplies, other }

class Expense {
  final String id;
  final String description;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final DateTime? endDate;
  final String? roomId;
  final bool isBillable;
  final bool isPaid;
  final String? bookingId;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.endDate,
    this.roomId,
    this.isBillable = false,
    this.isPaid = false,
    this.bookingId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category.name,
      'date': date.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'roomId': roomId,
      'isBillable': isBillable,
      'isPaid': isPaid,
      'bookingId': bookingId,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: ExpenseCategory.values.firstWhere((e) => e.name == map['category']),
      date: DateTime.parse(map['date'] as String),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate'] as String) : null,
      roomId: map['roomId'] as String?,
      isBillable: map['isBillable'] as bool? ?? false,
      isPaid: map['isPaid'] as bool? ?? false,
      bookingId: map['bookingId'] as String?,
    );
  }

  Expense copyWith({
    String? id,
    String? description,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    DateTime? endDate,
    String? roomId,
    bool? isBillable,
    bool? isPaid,
    String? bookingId,
  }) {
    return Expense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      roomId: roomId ?? this.roomId,
      isBillable: isBillable ?? this.isBillable,
      isPaid: isPaid ?? this.isPaid,
      bookingId: bookingId ?? this.bookingId,
    );
  }

  String get categoryLabel {
    switch (category) {
      case ExpenseCategory.cleaning:
        return 'Cleaning';
      case ExpenseCategory.maintenance:
        return 'Maintenance';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.supplies:
        return 'Supplies';
      case ExpenseCategory.other:
        return 'Other';
    }
  }
}
