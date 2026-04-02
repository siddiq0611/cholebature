// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/budget_bar.dart';
import '../widgets/category_chart.dart';
import '../widgets/footer_credit.dart';
import '../widgets/summary_cards.dart';
import 'add_transaction_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary    = ref.watch(summaryProvider);
    final catData    = ref.watch(categoryExpenseProvider);
    final themeMode  = ref.watch(themeModeProvider);
    final filter     = ref.watch(filterProvider);
    final notifier   = ref.read(filterProvider.notifier);

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.appBg,
            floating: true,
            snap: true,
            title: Text(
              'CholeBature',
              style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () {
                  final next = switch (themeMode) {
                    ThemeMode.system => ThemeMode.light,
                    ThemeMode.light  => ThemeMode.dark,
                    ThemeMode.dark   => ThemeMode.system,
                  };
                  ref.read(themeModeProvider.notifier).state = next;
                },
                child: Container(
                  width: 36, height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: context.appSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Icon(
                    switch (themeMode) {
                      ThemeMode.system => Icons.brightness_auto_rounded,
                      ThemeMode.light  => Icons.light_mode_rounded,
                      ThemeMode.dark   => Icons.dark_mode_rounded,
                    },
                    color: context.appTextSecondary, size: 18,
                  ),
                ),
              ),
              _AddButton(),
              const Gap(16),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Period filter tabs ──────────────────────────────────────
                _PeriodFilterBar(filter: filter, notifier: notifier),
                const Gap(12),

                // ── Period label + nav ──────────────────────────────────────
                if (filter.filter != DateFilter.overall)
                  _PeriodNav(filter: filter, notifier: notifier),
                if (filter.filter != DateFilter.overall)
                  const Gap(12),

                // ── Average insight ─────────────────────────────────────────
                _AverageInsightCard(filter: filter),
                const Gap(16),

                // ── Summary cards ───────────────────────────────────────────
                SummaryCards(
                  income:   summary.income,
                  expense:  summary.expense,
                  savings:  summary.savings,
                  borrowed: summary.borrowed,
                  lent:     summary.lent,
                ),
                const Gap(16),
                const BudgetBar(),
                const Gap(16),
                CategoryChart(data: catData),
                const Gap(16),
                _CategoryBreakdownList(data: catData, total: summary.expense),
                const Gap(64),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period filter tabs ─────────────────────────────────────────────────────────

class _PeriodFilterBar extends StatelessWidget {
  final FilterState filter;
  final FilterNotifier notifier;
  const _PeriodFilterBar({required this.filter, required this.notifier});

  static const _labels = {
    DateFilter.weekly:  'Week',
    DateFilter.monthly: 'Month',
    DateFilter.yearly:  'Year',
    DateFilter.overall: 'All',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DateFilter.values.map((f) {
          final selected = filter.filter == f;
          final accent   = context.appAccent;
          return GestureDetector(
            onTap: () => notifier.setFilter(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? accent : context.appSurfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? accent : context.appBorder),
              ),
              child: Text(
                _labels[f]!,
                style: GoogleFonts.dmSans(
                  color:
                      selected ? Colors.white : context.appTextSecondary,
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Period navigator (prev / label / next) ────────────────────────────────────

class _PeriodNav extends StatelessWidget {
  final FilterState filter;
  final FilterNotifier notifier;
  const _PeriodNav({required this.filter, required this.notifier});

  String _monthShort(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun',
       'Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  String _label() {
    switch (filter.filter) {
      case DateFilter.weekly:
        final end = filter.weekStart.add(const Duration(days: 6));
        return filter.weekStart.month == end.month
            ? '${filter.weekStart.day} – ${end.day} ${_monthShort(filter.weekStart.month)}'
            : '${filter.weekStart.day} ${_monthShort(filter.weekStart.month)} – ${end.day} ${_monthShort(end.month)}';
      case DateFilter.monthly:
        return '${_monthShort(filter.month)} ${filter.year}';
      case DateFilter.yearly:
        return '${filter.year}';
      case DateFilter.overall:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Chevron(
          icon: Icons.chevron_left_rounded,
          onTap: notifier.previous,
        ),
        const Gap(16),
        Text(
          _label(),
          style: GoogleFonts.dmSans(
            color: context.appTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const Gap(16),
        _Chevron(
          icon: Icons.chevron_right_rounded,
          onTap: notifier.next,
        ),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Chevron({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: context.appSurfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          child:
              Icon(icon, color: context.appTextSecondary, size: 18),
        ),
      );
}

// ── Average spending insight ───────────────────────────────────────────────────

class _AverageInsightCard extends ConsumerWidget {
  final FilterState filter;
  const _AverageInsightCard({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filter.filter == DateFilter.overall) return const SizedBox.shrink();

    final txAsync = ref.watch(transactionListProvider);

    return txAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (currentTxs) {
        // Current period expense
        final currentExpense = currentTxs
            .where((t) =>
                t.type.index == 0) // expense
            .fold(0.0, (s, t) => s + t.amount);

        return FutureBuilder<double>(
          future: _computeAverage(ref, filter),
          builder: (context, snap) {
            if (!snap.hasData || snap.data == 0) {
              return const SizedBox.shrink();
            }
            final avg  = snap.data!;
            final diff = currentExpense - avg;
            final isMore = diff > 0;
            final color =
                isMore ? context.appExpense : context.appIncome;
            final pct =
                avg > 0 ? ((diff.abs() / avg) * 100).toStringAsFixed(0) : '0';

            final periodName = switch (filter.filter) {
              DateFilter.weekly  => 'week',
              DateFilter.monthly => 'month',
              DateFilter.yearly  => 'year',
              DateFilter.overall => '',
            };

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(
                    isMore
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: color, size: 18,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMore
                              ? '$pct% more than average $periodName'
                              : diff == 0
                                  ? 'On par with average $periodName'
                                  : '$pct% less than average $periodName 🎉',
                          style: GoogleFonts.dmSans(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Avg: ${formatCompact(avg)}  ·  This $periodName: ${formatCompact(currentExpense)}',
                          style: GoogleFonts.dmSans(
                            color: context.appTextMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<double> _computeAverage(WidgetRef ref, FilterState filter) async {
    // We read historical expenses for the last N periods and average them
    final db = ref.read(transactionListProvider.notifier);
    // Use a simple approach: read the all-time list from DB and bucket manually
    // To avoid complexity, just compute based on what we have in state
    // (this is a UI hint, not financial advice)

    // For now read all transactions and compute average per period
    try {
      final allTxAsync = ref.read(transactionListProvider);
      return allTxAsync.when(
        data: (txs) {
          if (txs.isEmpty) return 0.0;
          final expenses = txs.where((t) => t.type.index == 0);
          if (expenses.isEmpty) return 0.0;

          switch (filter.filter) {
            case DateFilter.weekly:
              // Group by week number and average
              final Map<String, double> weeks = {};
              for (final t in expenses) {
                final wStart = t.date.subtract(
                    Duration(days: t.date.weekday - 1));
                final key =
                    '${wStart.year}-${wStart.month}-${wStart.day}';
                weeks[key] = (weeks[key] ?? 0) + t.amount;
              }
              if (weeks.isEmpty) return 0;
              return weeks.values.reduce((a, b) => a + b) /
                  weeks.length;

            case DateFilter.monthly:
              final Map<String, double> months = {};
              for (final t in expenses) {
                final key = '${t.date.year}-${t.date.month}';
                months[key] = (months[key] ?? 0) + t.amount;
              }
              if (months.isEmpty) return 0;
              return months.values.reduce((a, b) => a + b) /
                  months.length;

            case DateFilter.yearly:
              final Map<int, double> years = {};
              for (final t in expenses) {
                years[t.date.year] =
                    (years[t.date.year] ?? 0) + t.amount;
              }
              if (years.isEmpty) return 0;
              return years.values.reduce((a, b) => a + b) /
                  years.length;

            case DateFilter.overall:
              return 0;
          }
        },
        loading: () => 0.0,
        error: (_, __) => 0.0,
      );
    } catch (_) {
      return 0.0;
    }
  }
}

// ── Add button ─────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddTransactionSheet(),
        ),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: context.appAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              const Gap(4),
              Text('Add',
                  style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      );
}

// ── Category breakdown ─────────────────────────────────────────────────────────

class _CategoryBreakdownList extends StatelessWidget {
  final Map data;
  final double total;
  const _CategoryBreakdownList(
      {required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category Details',
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Gap(14),
          ...sorted.map((entry) {
            final info = categoryInfoMap[entry.key]!;
            final pct  = total > 0 ? entry.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(info.icon, color: info.color, size: 16),
                      const Gap(8),
                      Text(info.label,
                          style: GoogleFonts.dmSans(
                              color: context.appTextSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(
                          '₹${entry.value.toStringAsFixed(0)}',
                          style: GoogleFonts.dmSans(
                              color: context.appTextPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Gap(6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      backgroundColor: context.appBorder,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(info.color),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}