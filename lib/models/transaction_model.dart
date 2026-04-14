// CHANGED: added customCategoryId field to Transaction.
// When this is non-null the transaction belongs to a CustomCategory,
// and the `category` field is set to TransactionCategory.misc as a fallback
// for any legacy code that only reads the enum.

enum TransactionCategory {
  // Expense
  food, travel, essentials, work, misc, shop, home, health,
  // Income
  salary, cashback, gifts, otherIncome,
  // Borrow / Lend
  borrowed, lend,
}

enum TransactionType { expense, income, borrowed, lend }

enum SortOption { dateNewest, dateOldest, amountHigh, amountLow }

class Transaction {
  final String id;
  final String title;
  final double amount;
  final TransactionCategory category;
  final TransactionType type;
  final DateTime date;
  final String? note;

  /// Non-null when this transaction uses a user-defined [CustomCategory].
  /// When present, [category] is set to [TransactionCategory.misc] as a
  /// no-op fallback so old code never breaks.
  final String? customCategoryId;

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    this.note,
    this.customCategoryId,
  });

  bool get isCustomCategory => customCategoryId != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category.index,
        'type': type.index,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'custom_category_id': customCategoryId,
      };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        amount: (map['amount'] as num).toDouble(),
        category: TransactionCategory.values[map['category'] as int],
        type: TransactionType.values[map['type'] as int],
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        note: map['note'] as String?,
        customCategoryId: map['custom_category_id'] as String?,
      );

  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionCategory? category,
    TransactionType? type,
    DateTime? date,
    String? note,
    String? customCategoryId,
    bool clearCustomCategoryId = false,
  }) =>
      Transaction(
        id: id ?? this.id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        type: type ?? this.type,
        date: date ?? this.date,
        note: note ?? this.note,
        customCategoryId: clearCustomCategoryId
            ? null
            : (customCategoryId ?? this.customCategoryId),
      );
}