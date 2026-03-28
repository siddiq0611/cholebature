
// Extracted budget providers for clean architecture.
// Import this file wherever budget state is needed instead of importing
// the entire transaction_provider.dart.
//
// NOTE: Re-exports the providers that live in transaction_provider.dart
// so that screens only need to import ONE file.
//
// If you prefer a fully standalone file, the full implementations
// are duplicated below — pick one approach and remove the other.

// ── Option A: Re-export from transaction_provider (recommended) ──────────────
// Just import this file in your budget screens instead of transaction_provider.

export 'transaction_provider.dart'
    show
        budgetListProvider,
        BudgetNotifier,
        budgetResultsProvider;

// ── Option B: Standalone (use this if you split the providers file) ──────────
// Uncomment everything below and delete the export line above.
// You'll also need to remove budgetListProvider / budgetResultsProvider
// from transaction_provider.dart to avoid duplicate definitions.

/*
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart'; // weekStart helper

final budgetListProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<List<Budget>>>(
  (ref) => BudgetNotifier(),
);

class BudgetNotifier extends StateNotifier<AsyncValue<List<Budget>>> {
  final DatabaseService _db = DatabaseService();

  BudgetNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final budgets = await _db.getAllBudgets();
      if (mounted) state = AsyncValue.data(budgets);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> upsert(Budget budget) async {
    await _db.upsertBudget(budget);
    await load();
  }

  Future<void> delete(String id) async {
    await _db.deleteBudget(id);
    await load();
  }
}

DateTime _weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

final budgetResultsProvider = FutureProvider<List<BudgetResult>>((ref) async {
  final budgetsAsync = ref.watch(budgetListProvider);
  final db = DatabaseService();

  return budgetsAsync.when(
    data: (budgets) async {
      final now = DateTime.now();
      final results = <BudgetResult>[];

      for (final budget in budgets) {
        double spent = 0;
        double prevSpent = 0;

        switch (budget.period) {
          case BudgetPeriod.dailyWeekday:
          case BudgetPeriod.dailyWeekend:
            final todayTxs = await db.getTransactionsByDateRange(
              DateTime(now.year, now.month, now.day),
              DateTime(now.year, now.month, now.day + 1),
            );
            spent = todayTxs
                .where((t) => t.type == TransactionType.expense)
                .fold(0, (s, t) => s + t.amount);

            final yesterday = now.subtract(const Duration(days: 1));
            final yTxs = await db.getTransactionsByDateRange(
              DateTime(yesterday.year, yesterday.month, yesterday.day),
              DateTime(yesterday.year, yesterday.month, yesterday.day + 1),
            );
            prevSpent = yTxs
                .where((t) => t.type == TransactionType.expense)
                .fold(0, (s, t) => s + t.amount);
            break;

          case BudgetPeriod.weekly:
            final wStart = _weekStart(now);
            final weekTxs = await db.getTransactionsByWeek(wStart);
            spent = weekTxs
                .where((t) => t.type == TransactionType.expense)
                .fold(0, (s, t) => s + t.amount);

            final prevWeekStart = wStart.subtract(const Duration(days: 7));
            final prevWeekTxs = await db.getTransactionsByWeek(prevWeekStart);
            prevSpent = prevWeekTxs
                .where((t) => t.type == TransactionType.expense)
                .fold(0, (s, t) => s + t.amount);
            break;

          case BudgetPeriod.monthly:
            final monthTxs =
                await db.getTransactionsByMonth(now.year, now.month);
            spent = monthTxs
                .where((t) => t.type == TransactionType.expense)
                .fold(0, (s, t) => s + t.amount);

            final prevMonth = now.month == 1 ? 12 : now.month - 1;
            final prevYear = now.month == 1 ? now.year - 1 : now.year;
            final prevMonthTxs =
                await db.getTransactionsByMonth(prevYear, prevMonth);
            prevSpent = prevMonthTxs
                .where((t) => t.type == TransactionType.expense)
                .fold(0, (s, t) => s + t.amount);
            break;
        }

        results.add(BudgetResult(
          budget: budget,
          spent: spent,
          previousSpent: prevSpent,
        ));
      }
      return results;
    },
    loading: () async => [],
    error: (_, __) async => [],
  );
});
*/