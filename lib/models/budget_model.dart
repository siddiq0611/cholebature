enum BudgetPeriod { dailyWeekday, dailyWeekend, weekly, monthly }

class Budget {
  final String id;
  final BudgetPeriod period;
  final double amount;
  final bool active;

  const Budget({
    required this.id,
    required this.period,
    required this.amount,
    this.active = true,
  });

  String get label {
    switch (period) {
      case BudgetPeriod.dailyWeekday:
        return 'Daily (Weekdays)';
      case BudgetPeriod.dailyWeekend:
        return 'Daily (Weekends)';
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'period': period.index,
        'amount': amount,
        'active': active ? 1 : 0,
      };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'] as String,
        period: BudgetPeriod.values[map['period'] as int],
        amount: (map['amount'] as num).toDouble(),
        active: (map['active'] as int) == 1,
      );

  Budget copyWith({
    String? id,
    BudgetPeriod? period,
    double? amount,
    bool? active,
  }) =>
      Budget(
        id: id ?? this.id,
        period: period ?? this.period,
        amount: amount ?? this.amount,
        active: active ?? this.active,
      );
}

class BudgetResult {
  final Budget budget;
  final double spent;
  final double? previousSpent;

  const BudgetResult({
    required this.budget,
    required this.spent,
    this.previousSpent,
  });

  double get remaining => (budget.amount - spent).clamp(double.negativeInfinity, budget.amount);
  bool get isExceeded => spent > budget.amount;
  double get progress => (spent / budget.amount).clamp(0.0, 1.0);

  /// Percentage change vs previous period. Positive = spent more.
  double? get vsLastPeriodPct {
    if (previousSpent == null || previousSpent! == 0) return null;
    return ((spent - previousSpent!) / previousSpent!) * 100;
  }

  String get insightText {
    final pct = vsLastPeriodPct;
    if (pct == null) return 'No data from last ${budget.label.toLowerCase()}';
    final diff = (spent - previousSpent!).abs();
    if (pct > 5) return 'Spent ₹${diff.toStringAsFixed(0)} more than last period';
    if (pct < -5) return 'Spent ₹${diff.toStringAsFixed(0)} less than last period 🎉';
    return 'Spending is similar to last period';
  }
}