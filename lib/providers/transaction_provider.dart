import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

// ─── Filter ────────────────────────────────────────────────────────────────────
enum DateFilter { weekly, monthly, yearly, overall }

DateTime _weekStart(DateTime date) {
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

class FilterState {
  final DateFilter filter;
  final int year;
  final int month;
  final DateTime weekStart;

  FilterState({
    this.filter = DateFilter.monthly,
    required this.year,
    required this.month,
    required this.weekStart,
  });

  FilterState copyWith({
    DateFilter? filter,
    int? year,
    int? month,
    DateTime? weekStart,
  }) {
    return FilterState(
      filter: filter ?? this.filter,
      year: year ?? this.year,
      month: month ?? this.month,
      weekStart: weekStart ?? this.weekStart,
    );
  }
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

  void previous() {
    if (state.filter == DateFilter.weekly) {
      state = state.copyWith(
        weekStart: state.weekStart.subtract(const Duration(days: 7)),
      );
    } else if (state.filter == DateFilter.monthly) {
      if (state.month == 1) {
        state = state.copyWith(month: 12, year: state.year - 1);
      } else {
        state = state.copyWith(month: state.month - 1);
      }
    } else if (state.filter == DateFilter.yearly) {
      state = state.copyWith(year: state.year - 1);
    }
  }

  void next() {
    final now = DateTime.now();
    if (state.filter == DateFilter.weekly) {
      final nextWeek = state.weekStart.add(const Duration(days: 7));
      if (nextWeek.isBefore(now) || _weekStart(now) == state.weekStart) return;
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

// ─── Transactions ──────────────────────────────────────────────────────────────
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
      switch (filter.filter) {
        case DateFilter.weekly:
          txs = await _db.getTransactionsByWeek(filter.weekStart);
          break;
        case DateFilter.monthly:
          txs = await _db.getTransactionsByMonth(filter.year, filter.month);
          break;
        case DateFilter.yearly:
          txs = await _db.getTransactionsByYear(filter.year);
          break;
        case DateFilter.overall:
          txs = await _db.getAllTransactions();
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

// ─── Derived stats ─────────────────────────────────────────────────────────────
final summaryProvider =
    Provider<({double income, double expense, double savings, double borrowed})>(
        (ref) {
  final txAsync = ref.watch(transactionListProvider);
  return txAsync.when(
    data: (txs) {
      double income = 0, expense = 0, borrowed = 0;
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
        }
      }
      return (
        income: income,
        expense: expense,
        savings: income - expense,
        borrowed: borrowed,
      );
    },
    loading: () =>
        (income: 0, expense: 0, savings: 0, borrowed: 0),
    error: (_, __) =>
        (income: 0, expense: 0, savings: 0, borrowed: 0),
  );
});

final categoryExpenseProvider =
    Provider<Map<TransactionCategory, double>>((ref) {
  final txAsync = ref.watch(transactionListProvider);
  return txAsync.when(
    data: (txs) {
      final Map<TransactionCategory, double> map = {};
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

// Loading state derived from transaction list
final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(transactionListProvider).isLoading;
});