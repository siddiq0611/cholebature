import 'dart:convert';
import 'transaction_model.dart';

enum RecurrenceType { once, daily, weekly, monthly }

enum FutureStatus { pending, completedCycle, skipped, paused }

class FutureTransaction {
  final String id;
  final String title;
  final double amount;
  final TransactionCategory category;
  final TransactionType type;
  final String? note;

  // Scheduling
  final RecurrenceType recurrence;
  final List<int> recurrenceDays; // weekday indices 1=Mon..7=Sun for weekly
  final DateTime nextDue;

  // State
  final FutureStatus status;

  // Reminders: list of minutes-before-due to trigger (0 = at due time)
  // e.g. [0, 60, 1440] = at due time, 1 hr before, 1 day before
  final List<int> reminderOffsets;

  final DateTime createdAt;

  const FutureTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    this.note,
    required this.recurrence,
    this.recurrenceDays = const [],
    required this.nextDue,
    this.status = FutureStatus.pending,
    this.reminderOffsets = const [0],
    required this.createdAt,
  });

  bool get isOverdue =>
      nextDue.isBefore(DateTime.now()) && status == FutureStatus.pending;

  bool get isDueToday {
    final now = DateTime.now();
    return nextDue.year == now.year &&
        nextDue.month == now.month &&
        nextDue.day == now.day;
  }

  String get recurrenceLabel {
    switch (recurrence) {
      case RecurrenceType.once:
        return 'One-time';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        if (recurrenceDays.isEmpty) return 'Weekly';
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final labels = recurrenceDays.map((d) => days[d - 1]).join(', ');
        return 'Weekly ($labels)';
      case RecurrenceType.monthly:
        return 'Monthly';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category.index,
        'type': type.index,
        'note': note,
        'recurrence_type': recurrence.index,
        'recurrence_days': jsonEncode(recurrenceDays),
        'next_due': nextDue.millisecondsSinceEpoch,
        'status': status.index,
        'reminder_offsets': jsonEncode(reminderOffsets),
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory FutureTransaction.fromMap(Map<String, dynamic> map) {
    List<int> parseDays(dynamic raw) {
      if (raw == null) return [];
      try {
        final list = jsonDecode(raw as String) as List;
        return list.map((e) => e as int).toList();
      } catch (_) {
        return [];
      }
    }

    return FutureTransaction(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num).toDouble(),
      category: TransactionCategory.values[map['category'] as int],
      type: TransactionType.values[map['type'] as int],
      note: map['note'] as String?,
      recurrence: RecurrenceType.values[map['recurrence_type'] as int],
      recurrenceDays: parseDays(map['recurrence_days']),
      nextDue:
          DateTime.fromMillisecondsSinceEpoch(map['next_due'] as int),
      status: FutureStatus.values[map['status'] as int],
      reminderOffsets: parseDays(map['reminder_offsets']),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  FutureTransaction copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionCategory? category,
    TransactionType? type,
    String? note,
    RecurrenceType? recurrence,
    List<int>? recurrenceDays,
    DateTime? nextDue,
    FutureStatus? status,
    List<int>? reminderOffsets,
    DateTime? createdAt,
  }) =>
      FutureTransaction(
        id: id ?? this.id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        type: type ?? this.type,
        note: note ?? this.note,
        recurrence: recurrence ?? this.recurrence,
        recurrenceDays: recurrenceDays ?? this.recurrenceDays,
        nextDue: nextDue ?? this.nextDue,
        status: status ?? this.status,
        reminderOffsets: reminderOffsets ?? this.reminderOffsets,
        createdAt: createdAt ?? this.createdAt,
      );
}