import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../services/database_service.dart';

// ─── Date Filter ───────────────────────────────────────────────────────────────
enum DateFilter { daily, weekly, monthly, yearly, overall, range }

DateTime _weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

class FilterState {
  final DateFilter filter;
  final int year;
  final int month;
  final DateTime weekStart;
  final DateTime day;

  final Set<TransactionCategory> selectedCategories;
  final DateTime? specificDate;
  final SortOption sortBy;

  final DateTime? pickedMonth;
  final DateTime? pickedYear;
  final DateTime? pickedWeek;

  // Custom range
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  FilterState({
    this.filter = DateFilter.monthly,
    required this.year,
    required this.month,
    required this.weekStart,
    required this.day,
    this.selectedCategories = const {},
    this.specificDate,
    this.sortBy = SortOption.dateNewest,
    this.pickedMonth,
    this.pickedYear,
    this.pickedWeek,
    this.rangeStart,
    this.rangeEnd,
  });

  bool get hasActiveFilters =>
      selectedCategories.isNotEmpty || specificDate != null;

  bool get hasCustomRange => rangeStart != null && rangeEnd != null;

  FilterState copyWith({
    DateFilter? filter,
    int? year,
    int? month,
    DateTime? weekStart,
    DateTime? day,
    Set<TransactionCategory>? selectedCategories,
    DateTime? specificDate,
    bool clearSpecificDate = false,
    SortOption? sortBy,
    DateTime? pickedMonth,
    bool clearPickedMonth = false,
    DateTime? pickedYear,
    bool clearPickedYear = false,
    DateTime? pickedWeek,
    bool clearPickedWeek = false,
    DateTime? rangeStart,
    bool clearRangeStart = false,
    DateTime? rangeEnd,
    bool clearRangeEnd = false,
  }) =>
      FilterState(
        filter: filter ?? this.filter,
        year: year ?? this.year,
        month: month ?? this.month,
        weekStart: weekStart ?? this.weekStart,
        day: day ?? this.day,
        selectedCategories: selectedCategories ?? this.selectedCategories,
        specificDate:
            clearSpecificDate ? null : (specificDate ?? this.specificDate),
        sortBy: sortBy ?? this.sortBy,
        pickedMonth:
            clearPickedMonth ? null : (pickedMonth ?? this.pickedMonth),
        pickedYear: clearPickedYear ? null : (pickedYear ?? this.pickedYear),
        pickedWeek: clearPickedWeek ? null : (pickedWeek ?? this.pickedWeek),
        rangeStart: clearRangeStart ? null : (rangeStart ?? this.rangeStart),
        rangeEnd: clearRangeEnd ? null : (rangeEnd ?? this.rangeEnd),
      );
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((ref) {
  final now = DateTime.now();
  return FilterNotifier(FilterState(
    year: now.year,
    month: now.month,
    weekStart: _weekStart(now),
    day: DateTime(now.year, now.month, now.day),
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

  void setDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    state = state.copyWith(day: d, filter: DateFilter.daily);
  }

  void setWeekFromDate(DateTime date) {
    final ws = _weekStart(date);
    state = state.copyWith(
      weekStart: ws,
      filter: DateFilter.weekly,
      pickedWeek: ws,
    );
  }

  void setMonthFromDate(DateTime date) {
    state = state.copyWith(
      year: date.year,
      month: date.month,
      filter: DateFilter.monthly,
      pickedMonth: DateTime(date.year, date.month),
    );
  }

  void setYearValue(int year) {
    state = state.copyWith(
      year: year,
      filter: DateFilter.yearly,
      pickedYear: DateTime(year),
    );
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      rangeStart: DateTime(start.year, start.month, start.day),
      rangeEnd: DateTime(end.year, end.month, end.day, 23, 59, 59),
      filter: DateFilter.range,
    );
  }

  void clearCustomRange() {
    state = state.copyWith(
      clearRangeStart: true,
      clearRangeEnd: true,
      filter: DateFilter.monthly,
    );
  }

  void previous() {
    if (state.filter == DateFilter.daily) {
      final prev = state.day.subtract(const Duration(days: 1));
      state = state.copyWith(day: prev);
    } else if (state.filter == DateFilter.weekly) {
      state = state.copyWith(
          weekStart: state.weekStart.subtract(const Duration(days: 7)));
    } else if (state.filter == DateFilter.monthly) {
      state = state.month == 1
          ? state.copyWith(
              month: 12, year: state.year - 1, clearPickedMonth: true)
          : state.copyWith(month: state.month - 1, clearPickedMonth: true);
    } else if (state.filter == DateFilter.yearly) {
      state = state.copyWith(year: state.year - 1, clearPickedYear: true);
    }
    // range: no-op
  }

  void next() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (state.filter == DateFilter.daily) {
      final next = state.day.add(const Duration(days: 1));
      if (!next.isAfter(today)) {
        state = state.copyWith(day: next);
      }
    } else if (state.filter == DateFilter.weekly) {
      final nextWeek = state.weekStart.add(const Duration(days: 7));
      if (nextWeek.isAfter(now)) return;
      state = state.copyWith(weekStart: nextWeek);
    } else if (state.filter == DateFilter.monthly) {
      if (state.month == 12) {
        if (state.year < now.year) {
          state = state.copyWith(
              month: 1, year: state.year + 1, clearPickedMonth: true);
        }
      } else {
        final nextMonth = state.month + 1;
        if (state.year < now.year || nextMonth <= now.month) {
          state = state.copyWith(month: nextMonth, clearPickedMonth: true);
        }
      }
    } else if (state.filter == DateFilter.yearly) {
      if (state.year < now.year) {
        state = state.copyWith(year: state.year + 1, clearPickedYear: true);
      }
    }
    // range: no-op
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
          case DateFilter.daily:
            final d = filter.day;
            txs = await _db.getTransactionsByDateRange(
              DateTime(d.year, d.month, d.day),
              DateTime(d.year, d.month, d.day + 1),
            );
            break;
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
          case DateFilter.range:
            if (filter.rangeStart != null && filter.rangeEnd != null) {
              txs = await _db.getTransactionsByDateRange(
                filter.rangeStart!,
                filter.rangeEnd!.add(const Duration(seconds: 1)),
              );
            } else {
              txs = await _db.getAllTransactions();
            }
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
    _ref.read(borrowLendProvider.notifier).load();
  }

  Future<void> update(Transaction tx) async {
    await _db.updateTransaction(tx);
    await _load();
    _ref.read(borrowLendProvider.notifier).load();
  }

  Future<void> delete(String id) async {
    await _db.deleteTransaction(id);
    await _load();
    _ref.read(borrowLendProvider.notifier).load();
  }

  Future<void> refresh() => _load();
}

// ─── Summary ───────────────────────────────────────────────────────────────────
final summaryProvider = Provider((ref) {
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
    loading: () => (
      income: 0.0,
      expense: 0.0,
      savings: 0.0,
      borrowed: 0.0,
      lent: 0.0,
    ),
    error: (_, __) => (
      income: 0.0,
      expense: 0.0,
      savings: 0.0,
      borrowed: 0.0,
      lent: 0.0,
    ),
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

// ─── Borrow/Lend provider ──────────────────────────────────────────────────────
final borrowLendProvider =
    StateNotifierProvider<BorrowLendNotifier, AsyncValue<List<Transaction>>>(
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

// ─── Average insight provider ──────────────────────────────────────────────────
class AverageInsightResult {
  final double average;
  final double current;
  final double diff;
  final bool isMore;
  final String periodName;
  final bool hasData;

  const AverageInsightResult({
    required this.average,
    required this.current,
    required this.diff,
    required this.isMore,
    required this.periodName,
    required this.hasData,
  });

  double get pctDiff =>
      average > 0 ? ((diff.abs() / average) * 100) : 0;
}

final averageInsightProvider =
    FutureProvider<AverageInsightResult?>((ref) async {
  final filter = ref.watch(filterProvider);
  if (filter.filter == DateFilter.overall ||
      filter.filter == DateFilter.range) return null;

  final db = DatabaseService();
  final allTxs = await db.getAllTransactions();
  final expenses = allTxs
      .where((t) => t.type == TransactionType.expense)
      .toList();

  if (expenses.isEmpty) return null;

  switch (filter.filter) {
    case DateFilter.daily:
      {
        final Map<String, double> days = {};
        for (final t in expenses) {
          final k = '${t.date.year}-${t.date.month}-${t.date.day}';
          days[k] = (days[k] ?? 0) + t.amount;
        }
        if (days.isEmpty) return null;
        final avg = days.values.reduce((a, b) => a + b) / days.length;
        final d = filter.specificDate ?? filter.day;
        final key = '${d.year}-${d.month}-${d.day}';
        final current = days[key] ?? 0.0;
        final diff = current - avg;
        return AverageInsightResult(
          average: avg,
          current: current,
          diff: diff,
          isMore: diff > 0,
          periodName: 'day',
          hasData: true,
        );
      }

    case DateFilter.weekly:
      {
        final Map<String, double> weeks = {};
        for (final t in expenses) {
          final ws =
              t.date.subtract(Duration(days: t.date.weekday - 1));
          final k = '${ws.year}-${ws.month}-${ws.day}';
          weeks[k] = (weeks[k] ?? 0) + t.amount;
        }
        if (weeks.isEmpty) return null;
        final avg = weeks.values.reduce((a, b) => a + b) / weeks.length;
        final ws = filter.weekStart;
        final key = '${ws.year}-${ws.month}-${ws.day}';
        final current = weeks[key] ?? 0.0;
        final diff = current - avg;
        return AverageInsightResult(
          average: avg,
          current: current,
          diff: diff,
          isMore: diff > 0,
          periodName: 'week',
          hasData: true,
        );
      }

    case DateFilter.monthly:
      {
        final Map<String, double> months = {};
        for (final t in expenses) {
          final k = '${t.date.year}-${t.date.month}';
          months[k] = (months[k] ?? 0) + t.amount;
        }
        if (months.isEmpty) return null;
        final avg =
            months.values.reduce((a, b) => a + b) / months.length;
        final key = '${filter.year}-${filter.month}';
        final current = months[key] ?? 0.0;
        final diff = current - avg;
        return AverageInsightResult(
          average: avg,
          current: current,
          diff: diff,
          isMore: diff > 0,
          periodName: 'month',
          hasData: true,
        );
      }

    case DateFilter.yearly:
      {
        final Map<int, double> years = {};
        for (final t in expenses) {
          years[t.date.year] = (years[t.date.year] ?? 0) + t.amount;
        }
        if (years.isEmpty) return null;
        final avg = years.values.reduce((a, b) => a + b) / years.length;
        final current = years[filter.year] ?? 0.0;
        final diff = current - avg;
        return AverageInsightResult(
          average: avg,
          current: current,
          diff: diff,
          isMore: diff > 0,
          periodName: 'year',
          hasData: true,
        );
      }

    case DateFilter.overall:
    case DateFilter.range:
      return null;
  }
});