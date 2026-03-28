enum TransactionCategory {
  // Expense categories
  food,
  travel,
  essentials,
  work,
  misc,
  shop,
  home,
  health,
  // Income categories
  salary,
  cashback,
  gifts,
  otherIncome,
  // Borrowed money
  borrowed,
}

enum TransactionType { expense, income, borrowed }

class Transaction {
  final String id;
  final String title;
  final double amount;
  final TransactionCategory category;
  final TransactionType type;
  final DateTime date;
  final String? note;

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category.index,
      'type': type.index,
      'date': date.millisecondsSinceEpoch,
      'note': note,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num).toDouble(),
      category: TransactionCategory.values[map['category'] as int],
      type: TransactionType.values[map['type'] as int],
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      note: map['note'] as String?,
    );
  }

  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionCategory? category,
    TransactionType? type,
    DateTime? date,
    String? note,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      type: type ?? this.type,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}