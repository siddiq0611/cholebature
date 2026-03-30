// Key change: markDone now accepts an optional overrideAmount.
// This is used when the FutureTransaction has amount == 0 (variable),
// in which case the user enters the actual amount at completion time.
// If amount > 0 (fixed), overrideAmount can still be passed to allow
// the user to change it at mark-done time.
//
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
    final withId = ft.id.isEmpty ? ft.copyWith(id: _uuid.v4()) : ft;
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
  ///
  /// [overrideAmount]: the actual amount to record. Required when
  /// ft.amount == 0 (variable). Optional when ft.amount > 0 — if
  /// provided it overrides the stored amount (user changed it at
  /// mark-done time).
  ///
  /// [recordDate]: the date to stamp on the real transaction.
  Future<void> markDone(
    FutureTransaction ft, {
    double? overrideAmount,
    DateTime? recordDate,
  }) async {
    // Resolve the final amount:
    // 1. overrideAmount wins if provided
    // 2. ft.amount used if non-zero
    // 3. Fallback to 0 (shouldn't happen — UI enforces amount entry)
    final finalAmount = (overrideAmount != null && overrideAmount > 0)
        ? overrideAmount
        : ft.amount;

    // 1. Create a real transaction
    final tx = Transaction(
      id: _uuid.v4(),
      title: ft.title,
      amount: finalAmount,
      category: ft.category,
      type: ft.type,
      date: recordDate ?? DateTime.now(),
      note: ft.note,
    );
    await _ref.read(transactionListProvider.notifier).add(tx);

    // 2. Handle recurrence
    if (ft.recurrence == RecurrenceType.once) {
      await delete(ft.id);
    } else {
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

  // ── Next due date computation ──────────────────────────────────────────────

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
        var candidate = ft.nextDue.add(const Duration(days: 1));
        for (var i = 0; i < 8; i++) {
          if (ft.recurrenceDays.contains(candidate.weekday)) {
            return DateTime(
              candidate.year, candidate.month, candidate.day,
              ft.nextDue.hour, ft.nextDue.minute,
            );
          }
          candidate = candidate.add(const Duration(days: 1));
        }
        return ft.nextDue.add(const Duration(days: 7));

      case RecurrenceType.monthly:
        var year = ft.nextDue.year;
        var month = ft.nextDue.month + 1;
        if (month > 12) { month = 1; year++; }
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final day = ft.nextDue.day.clamp(1, daysInMonth);
        return DateTime(year, month, day, ft.nextDue.hour, ft.nextDue.minute);
    }
  }
}

// ── Derived providers ──────────────────────────────────────────────────────────

final overdueCountProvider = Provider<int>((ref) {
  return ref.watch(futureTransactionProvider).when(
    data: (list) => list.where((ft) => ft.isOverdue).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});