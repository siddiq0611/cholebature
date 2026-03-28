import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/future_transaction_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'transaction_provider.dart';

final futureTransactionProvider = StateNotifierProvider<
    FutureTransactionNotifier, AsyncValue<List<FutureTransaction>>>(
  (ref) => FutureTransactionNotifier(ref),
);

class FutureTransactionNotifier
    extends StateNotifier<AsyncValue<List<FutureTransaction>>> {
  final Ref _ref;
  final DatabaseService _db = DatabaseService();
  static const _uuid = Uuid();

  FutureTransactionNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _db.getAllFutureTransactions();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(FutureTransaction ft) async {
    final withId = ft.id.isEmpty
        ? ft.copyWith(id: _uuid.v4())
        : ft;
    await _db.insertFutureTransaction(withId);
    await NotificationService.scheduleReminders(withId);
    await load();
  }

  Future<void> update(FutureTransaction ft) async {
    await _db.updateFutureTransaction(ft);
    await NotificationService.scheduleReminders(ft);
    await load();
  }

  Future<void> delete(String id) async {
    await _db.deleteFutureTransaction(id);
    await NotificationService.cancelReminders(id);
    await load();
  }

  /// Mark a future transaction as done for the current cycle.
  /// Creates a real Transaction and advances the recurring schedule.
  Future<void> markDone(FutureTransaction ft,
      {DateTime? recordDate}) async {
    // 1. Create a real transaction
    final tx = Transaction(
      id: _uuid.v4(),
      title: ft.title,
      amount: ft.amount,
      category: ft.category,
      type: ft.type,
      date: recordDate ?? DateTime.now(),
      note: ft.note,
    );
    await _ref.read(transactionListProvider.notifier).add(tx);

    // 2. Handle recurrence
    if (ft.recurrence == RecurrenceType.once) {
      // One-time: delete it
      await delete(ft.id);
    } else {
      // Recurring: advance nextDue and reset status
      final next = _computeNextDue(ft);
      final updated = ft.copyWith(
        nextDue: next,
        status: FutureStatus.pending,
      );
      await _db.updateFutureTransaction(updated);
      await NotificationService.scheduleReminders(updated);
      await load();
    }
  }

  /// Skip this cycle without recording a transaction.
  Future<void> skipCycle(FutureTransaction ft) async {
    if (ft.recurrence == RecurrenceType.once) {
      await delete(ft.id);
      return;
    }
    final next = _computeNextDue(ft);
    final updated = ft.copyWith(
      nextDue: next,
      status: FutureStatus.skipped,
    );
    await _db.updateFutureTransaction(updated);
    await NotificationService.scheduleReminders(updated);
    await load();
  }

  Future<void> pause(FutureTransaction ft) async {
    final updated = ft.copyWith(status: FutureStatus.paused);
    await _db.updateFutureTransaction(updated);
    await NotificationService.cancelReminders(ft.id);
    await load();
  }

  Future<void> resume(FutureTransaction ft) async {
    final updated = ft.copyWith(status: FutureStatus.pending);
    await _db.updateFutureTransaction(updated);
    await NotificationService.scheduleReminders(updated);
    await load();
  }

  // ─── Next due date logic ──────────────────────────────────────────────────

  DateTime _computeNextDue(FutureTransaction ft) {
    switch (ft.recurrence) {
      case RecurrenceType.once:
        return ft.nextDue;

      case RecurrenceType.daily:
        return ft.nextDue.add(const Duration(days: 1));

      case RecurrenceType.weekly:
        if (ft.recurrenceDays.isEmpty) {
          return ft.nextDue.add(const Duration(days: 7));
        }
        // Find next matching weekday after current nextDue
        var candidate = ft.nextDue.add(const Duration(days: 1));
        for (var i = 0; i < 8; i++) {
          if (ft.recurrenceDays.contains(candidate.weekday)) {
            return DateTime(
              candidate.year,
              candidate.month,
              candidate.day,
              ft.nextDue.hour,
              ft.nextDue.minute,
            );
          }
          candidate = candidate.add(const Duration(days: 1));
        }
        return ft.nextDue.add(const Duration(days: 7));

      case RecurrenceType.monthly:
        var year = ft.nextDue.year;
        var month = ft.nextDue.month + 1;
        if (month > 12) {
          month = 1;
          year++;
        }
        // Clamp day to valid range for that month
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final day = ft.nextDue.day.clamp(1, daysInMonth);
        return DateTime(year, month, day, ft.nextDue.hour,
            ft.nextDue.minute);
    }
  }
}

// Derived providers for UI
final overdueCountProvider = Provider<int>((ref) {
  final async = ref.watch(futureTransactionProvider);
  return async.when(
    data: (list) => list.where((ft) => ft.isOverdue).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});