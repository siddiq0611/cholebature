import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../services/database_service.dart';

// ─── Date Filter ───────────────────────────────────────────────────────────────
enum DateFilter { weekly, monthly, yearly, overall }

DateTime _weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

class FilterState {
  final DateFilter filter;
  final int year;
  final int month;
  final DateTime weekStart;

  // Advanced filters
  final Set<TransactionCategory> selectedCategories;
  final DateTime? specificDate;
  final SortOption sortBy;

  FilterState({
    this.filter = DateFilter.monthly,
    required this.year,
    required this.month,
    required this.weekStart,
    this.selectedCategories = const {},
    this.specificDate,
    this.sortBy = SortOption.dateNewest,
  });

  bool get hasActiveFilters =>
      selectedCategories.isNotEmpty || specificDate != null;

  FilterState copyWith({
    DateFilter? filter,
    int? year,
    int? month,
    DateTime? weekStart,
    Set<TransactionCategory>? selectedCategories,
    DateTime? specificDate,
    bool clearSpecificDate = false,
    SortOption? sortBy,
  }) =>
      FilterState(
        filter: filter ?? this.filter,
        year: year ?? this.year,
        month: month ?? this.month,
        weekStart: weekStart ?? this.weekStart,
        selectedCategories:
            selectedCategories ?? this.selectedCategories,
        specificDate:
            clearSpecificDate ? null : (specificDate ?? this.specificDate),
        sortBy: sortBy ?? this.sortBy,
      );
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((ref) {
  final now = DateTime.now();
  return FilterNotifier(FilterState(
    year: now.year,
    month: now.month,
    weekStart: _weekStart(now),
  ));
});

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier(super.initial);

  void setFilter(DateFilter filter) => state = state.copyWith(filter: filter);
  void setYear(int year) => state = state.copyWith(year: year);
  void setMonth(int month) => state = state.copyWith(month: month);
  void setSortBy(SortOption sort) => state = state.copyWith(sortBy: sort);

  void toggleCategory(TransactionCategory cat) {
    final current = Set<TransactionCategory>.from(state.selectedCategories);
    if (current.contains(cat)) {
      current.remove(cat);
    } else {
      current.add(cat);
    }
    state = state.copyWith(selectedCategories: current);
  }

  void setSpecificDate(DateTime? date) =>
      state = date == null
          ? state.copyWith(clearSpecificDate: true)
          : state.copyWith(specificDate: date);

  void clearAdvancedFilters() => state = state.copyWith(
        selectedCategories: {},
        clearSpecificDate: true,
        sortBy: SortOption.dateNewest,
      );

  void previous() {
    if (state.filter == DateFilter.weekly) {
      state = state.copyWith(
          weekStart:
              state.weekStart.subtract(const Duration(days: 7)));
    } else if (state.filter == DateFilter.monthly) {
      state = state.month == 1
          ? state.copyWith(month: 12, year: state.year - 1)
          : state.copyWith(month: state.month - 1);
    } else if (state.filter == DateFilter.yearly) {
      state = state.copyWith(year: state.year - 1);
    }
  }

  void next() {
    final now = DateTime.now();
    if (state.filter == DateFilter.weekly) {
      final nextWeek = state.weekStart.add(const Duration(days: 7));
      if (nextWeek.isAfter(now)) return;
      state = state.copyWith(weekStart: nextWeek);
    } else if (state.filter == DateFilter.monthly) {
      if (state.month == 12) {
        if (state.year < now.year) {
          state = state.copyWith(month: 1, year: state.year + 1);
        }
      } else {
        final nextMonth = state.month + 1;
        if (state.year < now.year || nextMonth <= now.month) {
          state = state.copyWith(month: nextMonth);
        }
      }
    } else if (state.filter == DateFilter.yearly) {
      if (state.year < now.year) {
        state = state.copyWith(year: state.year + 1);
      }
    }
  }
}

// ─── Transaction list ──────────────────────────────────────────────────────────
final transactionListProvider =
    StateNotifierProvider<TransactionNotifier, AsyncValue<List<Transaction>>>(
  (ref) => TransactionNotifier(ref),
);

class TransactionNotifier
    extends StateNotifier<AsyncValue<List<Transaction>>> {
  final Ref _ref;
  final DatabaseService _db = DatabaseService();

  TransactionNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
    _ref.listen(filterProvider, (_, __) => _load());
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final filter = _ref.read(filterProvider);
      List<Transaction> txs;

      if (filter.specificDate != null) {
        final d = filter.specificDate!;
        txs = await _db.getTransactionsByDateRange(
          DateTime(d.year, d.month, d.day),
          DateTime(d.year, d.month, d.day + 1),
        );
      } else {
        switch (filter.filter) {
          case DateFilter.weekly:
            txs = await _db.getTransactionsByWeek(filter.weekStart);
            break;
          case DateFilter.monthly:
            txs = await _db
                .getTransactionsByMonth(filter.year, filter.month);
            break;
          case DateFilter.yearly:
            txs = await _db.getTransactionsByYear(filter.year);
            break;
          case DateFilter.overall:
            txs = await _db.getAllTransactions();
            break;
        }
      }

      // Apply category filter
      if (filter.selectedCategories.isNotEmpty) {
        txs = txs
            .where((t) => filter.selectedCategories.contains(t.category))
            .toList();
      }

      // Apply sort
      switch (filter.sortBy) {
        case SortOption.dateNewest:
          txs.sort((a, b) => b.date.compareTo(a.date));
          break;
        case SortOption.dateOldest:
          txs.sort((a, b) => a.date.compareTo(b.date));
          break;
        case SortOption.amountHigh:
          txs.sort((a, b) => b.amount.compareTo(a.amount));
          break;
        case SortOption.amountLow:
          txs.sort((a, b) => a.amount.compareTo(b.amount));
          break;
      }

      if (mounted) state = AsyncValue.data(txs);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(Transaction tx) async {
    await _db.insertTransaction(tx);
    await _load();
  }

  Future<void> update(Transaction tx) async {
    await _db.updateTransaction(tx);
    await _load();
  }

  Future<void> delete(String id) async {
    await _db.deleteTransaction(id);
    await _load();
  }

  Future<void> refresh() => _load();
}

// ─── Summary ───────────────────────────────────────────────────────────────────
final summaryProvider = Provider<
    ({
      double income,
      double expense,
      double savings,
      double borrowed,
      double lent
    })>((ref) {
  final txAsync = ref.watch(transactionListProvider);
  return txAsync.when(
    data: (txs) {
      double income = 0, expense = 0, borrowed = 0, lent = 0;
      for (final t in txs) {
        switch (t.type) {
          case TransactionType.income:
            income += t.amount;
            break;
          case TransactionType.expense:
            expense += t.amount;
            break;
          case TransactionType.borrowed:
            borrowed += t.amount;
            break;
          case TransactionType.lend:
            lent += t.amount;
            break;
        }
      }
      return (
        income: income,
        expense: expense,
        savings: income - expense,
        borrowed: borrowed,
        lent: lent,
      );
    },
    loading: () =>
        (income: 0, expense: 0, savings: 0, borrowed: 0, lent: 0),
    error: (_, __) =>
        (income: 0, expense: 0, savings: 0, borrowed: 0, lent: 0),
  );
});

final categoryExpenseProvider =
    Provider<Map<TransactionCategory, double>>((ref) {
  final txAsync = ref.watch(transactionListProvider);
  return txAsync.when(
    data: (txs) {
      final map = <TransactionCategory, double>{};
      for (final t in txs) {
        if (t.type == TransactionType.expense) {
          map[t.category] = (map[t.category] ?? 0) + t.amount;
        }
      }
      return map;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

// Borrow/Lend specific provider (all time — for the dedicated tab)
final borrowLendProvider =
    StateNotifierProvider<BorrowLendNotifier,
        AsyncValue<List<Transaction>>>(
  (ref) => BorrowLendNotifier(),
);

class BorrowLendNotifier
    extends StateNotifier<AsyncValue<List<Transaction>>> {
  final DatabaseService _db = DatabaseService();

  BorrowLendNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final all = await _db.getAllTransactions();
      final filtered = all
          .where((t) =>
              t.type == TransactionType.borrowed ||
              t.type == TransactionType.lend)
          .toList();
      filtered.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) state = AsyncValue.data(filtered);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }
}

final isLoadingProvider = Provider<bool>(
    (ref) => ref.watch(transactionListProvider).isLoading);

// ─── Budget provider ───────────────────────────────────────────────────────────
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

// Budget results: compute spend vs limit for each active budget
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

            final prevWeekStart =
                wStart.subtract(const Duration(days: 7));
            final prevWeekTxs =
                await db.getTransactionsByWeek(prevWeekStart);
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
            final prevYear =
                now.month == 1 ? now.year - 1 : now.year;
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

// Security provider
final securityProvider =
    StateNotifierProvider<SecurityNotifier, AsyncValue<bool>>(
  (ref) => SecurityNotifier(),
);

class SecurityNotifier extends StateNotifier<AsyncValue<bool>> {
  SecurityNotifier() : super(const AsyncValue.data(false));

  void setLocked(bool locked) {
    state = AsyncValue.data(locked);
  }
}