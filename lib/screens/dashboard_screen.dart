import 'package:flutter/material.dart' hide DateRangePickerDialog;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/custom_category_model.dart';
import '../providers/custom_category_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/budget_bar.dart';
import '../widgets/category_chart.dart';
import '../widgets/filter_bar.dart';
import '../widgets/summary_cards.dart';
import 'add_transaction_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final catData = ref.watch(categoryExpenseProvider); // kept for SummaryCards compat
    final themeMode = ref.watch(themeModeProvider);
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);

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
                  ref.read(themeModeProvider.notifier).cycle();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: context.appSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Icon(
                    switch (themeMode) {
                      ThemeMode.system => Icons.brightness_auto_rounded,
                      ThemeMode.light => Icons.light_mode_rounded,
                      ThemeMode.dark => Icons.dark_mode_rounded,
                    },
                    color: context.appTextSecondary,
                    size: 18,
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
                _PeriodFilterBar(filter: filter, notifier: notifier),
                const Gap(12),
                if (filter.filter != DateFilter.overall)
                  _PeriodNav(filter: filter, notifier: notifier),
                if (filter.filter != DateFilter.overall) const Gap(12),
                const _AverageInsightCard(),
                const Gap(16),
                SummaryCards(
                  income: summary.income,
                  expense: summary.expense,
                  savings: summary.savings,
                  borrowed: summary.borrowed,
                  lent: summary.lent,
                ),
                const Gap(16),
                const BudgetBar(),
                const Gap(16),
                // CategoryChart now reads its own provider internally
                CategoryChart(data: catData),
                const Gap(16),
                // Use the new unified breakdown list
                const _CategoryBreakdownList(),
                const Gap(64),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Period filter tabs ───────────────────────────────────────────────────────

class _PeriodFilterBar extends StatelessWidget {
  final FilterState filter;
  final FilterNotifier notifier;
  const _PeriodFilterBar({required this.filter, required this.notifier});

  static const _labels = {
    DateFilter.daily: 'Day',
    DateFilter.weekly: 'Week',
    DateFilter.monthly: 'Month',
    DateFilter.yearly: 'Year',
    DateFilter.overall: 'All',
    DateFilter.range: 'Range',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DateFilter.values.map((f) {
          final selected = filter.filter == f;
          final accent = context.appAccent;
          return GestureDetector(
            onTap: () {
              if (f == DateFilter.range) {
                _openRangePicker(context);
              } else {
                notifier.setFilter(f);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openRangePicker(BuildContext context) async {
    final result = await showDialog<(DateTime, DateTime)>(
      context: context,
      builder: (_) => DateRangePickerDialog(
        initialStart: filter.rangeStart,
        initialEnd: filter.rangeEnd,
      ),
    );
    if (result != null) {
      notifier.setCustomRange(result.$1, result.$2);
    }
  }
}

// ─── Period navigator ─────────────────────────────────────────────────────────

class _PeriodNav extends StatelessWidget {
  final FilterState filter;
  final FilterNotifier notifier;
  const _PeriodNav({required this.filter, required this.notifier});

  String _monthShort(int m) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];

  String _label() {
    switch (filter.filter) {
      case DateFilter.daily:
        final d = filter.day;
        final now = DateTime.now();
        if (d.year == now.year &&
            d.month == now.month &&
            d.day == now.day) {
          return 'Today';
        }
        return '${d.day} ${_monthShort(d.month)} ${d.year}';
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
      case DateFilter.range:
        if (filter.rangeStart != null && filter.rangeEnd != null) {
          return '${filter.rangeStart!.day} ${_monthShort(filter.rangeStart!.month)} – ${filter.rangeEnd!.day} ${_monthShort(filter.rangeEnd!.month)} ${filter.rangeEnd!.year}';
        }
        return 'Custom range';
    }
  }

  Future<void> _openPicker(BuildContext context) async {
    switch (filter.filter) {
      case DateFilter.daily:
        final picked = await showDatePicker(
          context: context,
          initialDate: filter.day,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          helpText: 'Select day',
        );
        if (picked != null) notifier.setDay(picked);
        break;

      case DateFilter.weekly:
        final picked = await showDatePicker(
          context: context,
          initialDate: filter.weekStart,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          helpText: 'Select any day in the week',
        );
        if (picked != null) notifier.setWeekFromDate(picked);
        break;

      case DateFilter.monthly:
        final picked = await _showMonthYearPickerDialog(
          context: context,
          initialYear: filter.year,
          initialMonth: filter.month,
          mode: _DashPickerMode.month,
        );
        if (picked != null) notifier.setMonthFromDate(picked);
        break;

      case DateFilter.yearly:
        final picked = await _showMonthYearPickerDialog(
          context: context,
          initialYear: filter.year,
          initialMonth: filter.month,
          mode: _DashPickerMode.year,
        );
        if (picked != null) notifier.setYearValue(picked.year);
        break;

      case DateFilter.range:
        final result = await showDialog<(DateTime, DateTime)>(
          context: context,
          builder: (_) => DateRangePickerDialog(
            initialStart: filter.rangeStart,
            initialEnd: filter.rangeEnd,
          ),
        );
        if (result != null) notifier.setCustomRange(result.$1, result.$2);
        break;

      case DateFilter.overall:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showChevrons = filter.filter != DateFilter.range;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showChevrons)
          _Chevron(
              icon: Icons.chevron_left_rounded, onTap: notifier.previous),
        if (showChevrons) const Gap(16),
        GestureDetector(
          onTap: () => _openPicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _label(),
                style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const Gap(4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: context.appTextMuted, size: 16),
            ],
          ),
        ),
        if (showChevrons) const Gap(16),
        if (showChevrons)
          _Chevron(
              icon: Icons.chevron_right_rounded, onTap: notifier.next),
        if (filter.filter == DateFilter.range) ...[
          const Gap(8),
          GestureDetector(
            onTap: () => notifier.clearCustomRange(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.appExpense.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded,
                      size: 12, color: context.appExpense),
                  const Gap(3),
                  Text(
                    'Clear',
                    style: GoogleFonts.dmSans(
                        color: context.appExpense, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _DashPickerMode { month, year }

Future<DateTime?> _showMonthYearPickerDialog({
  required BuildContext context,
  required int initialYear,
  required int initialMonth,
  required _DashPickerMode mode,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => _DashMonthYearPickerDialog(
      initialYear: initialYear,
      initialMonth: initialMonth,
      mode: mode,
    ),
  );
}

class _DashMonthYearPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final _DashPickerMode mode;

  const _DashMonthYearPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.mode,
  });

  @override
  State<_DashMonthYearPickerDialog> createState() =>
      _DashMonthYearPickerDialogState();
}

class _DashMonthYearPickerDialogState
    extends State<_DashMonthYearPickerDialog> {
  late int _year;
  late int _month;
  final int _minYear = 2020;
  final int _maxYear = DateTime.now().year;

  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  bool _isMonthSelectable(int m) {
    if (_year < DateTime.now().year) return true;
    return m <= DateTime.now().month;
  }

  @override
  Widget build(BuildContext context) {
    final isMonthMode = widget.mode == _DashPickerMode.month;

    return Dialog(
      backgroundColor: context.appSurfaceElevated,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isMonthMode ? 'Select Month' : 'Select Year',
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _year > _minYear
                      ? () => setState(() => _year--)
                      : null,
                  icon: Icon(Icons.chevron_left_rounded,
                      color: _year > _minYear
                          ? context.appTextPrimary
                          : context.appTextMuted),
                ),
                Text('$_year',
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: _year < _maxYear
                      ? () => setState(() => _year++)
                      : null,
                  icon: Icon(Icons.chevron_right_rounded,
                      color: _year < _maxYear
                          ? context.appTextPrimary
                          : context.appTextMuted),
                ),
              ],
            ),
            if (isMonthMode) ...[
              const Gap(8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (_, i) {
                  final m = i + 1;
                  final selectable = _isMonthSelectable(m);
                  return GestureDetector(
                    onTap: selectable
                        ? () => setState(() => _month = m)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: m == _month
                            ? context.appAccent
                            : context.appSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: m == _month
                              ? context.appAccent
                              : context.appBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _monthShort[i],
                          style: GoogleFonts.dmSans(
                            color: !selectable
                                ? context.appTextMuted
                                : m == _month
                                    ? Colors.white
                                    : context.appTextPrimary,
                            fontSize: 12,
                            fontWeight: m == _month
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              const Gap(8),
              SizedBox(
                height: 180,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _maxYear - _minYear + 1,
                  itemBuilder: (_, i) {
                    final y = _minYear + i;
                    final isSelected = y == _year;
                    return GestureDetector(
                      onTap: () => setState(() => _year = y),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.appAccent
                              : context.appSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? context.appAccent
                                : context.appBorder,
                          ),
                        ),
                        child: Center(
                          child: Text('$y',
                              style: GoogleFonts.dmSans(
                                color: isSelected
                                    ? Colors.white
                                    : context.appTextPrimary,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              )),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appTextSecondary,
                      side: BorderSide(color: context.appBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final result = isMonthMode
                          ? DateTime(_year, _month)
                          : DateTime(_year);
                      Navigator.pop(context, result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Select',
                        style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.appSurfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          child: Icon(icon, color: context.appTextSecondary, size: 18),
        ),
      );
}

// ─── Average insight card ─────────────────────────────────────────────────────

class _AverageInsightCard extends ConsumerWidget {
  const _AverageInsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    if (filter.filter == DateFilter.overall ||
        filter.filter == DateFilter.range) {
      return const SizedBox.shrink();
    }

    final insightAsync = ref.watch(averageInsightProvider);

    return insightAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (insight) {
        if (insight == null || insight.average == 0) {
          return const SizedBox.shrink();
        }

        final color =
            insight.isMore ? context.appExpense : context.appIncome;

        String label;
        final l_amount = formatCompact(insight.diff.abs());
        final l_pct = insight.pctDiff.toStringAsFixed(0);

        if (insight.diff.abs() < 1) {
          label = 'Spending is right on average for this ${insight.periodName}';
        } else if (insight.isMore) {
          label = '$l_pct% ($l_amount) more than your ${insight.periodName}ly average';
        } else {
          label = '$l_pct% ($l_amount) less than your ${insight.periodName}ly average';
        }

        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(
                insight.isMore
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: color,
                size: 18,
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.dmSans(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Avg: ${formatCompact(insight.average)}  ·  This ${insight.periodName}: ${formatCompact(insight.current)}',
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
  }
}

// ─── Add button ───────────────────────────────────────────────────────────────

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

// ─── Category breakdown list ──────────────────────────────────────────────────
// Now reads categoryExpenseEntriesProvider and resolves custom categories.

class _CategoryBreakdownList extends ConsumerWidget {
  const _CategoryBreakdownList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(categoryExpenseEntriesProvider);
    final customCats = ref.watch(customCategoryProvider).when(
          data: (list) => {for (final c in list) c.id: c},
          loading: () => <String, CustomCategory>{},
          error: (_, __) => <String, CustomCategory>{},
        );

    if (entries.isEmpty) return const SizedBox();

    final total = entries.fold<double>(0, (s, e) => s + e.amount);

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
          ...entries.map((entry) {
            final pct = total > 0 ? entry.amount / total : 0.0;

            Color color;
            String label;
            IconData icon;

            if (entry.isCustom) {
              final cat = customCats[entry.customCategoryId];
              if (cat != null) {
                color = cat.deleted ? context.appTextMuted : cat.color;
                label = cat.deleted ? '${cat.name} (deleted)' : cat.name;
                icon = cat.icon;
              } else {
                color = context.appTextMuted;
                label = 'Unknown';
                icon = Icons.help_outline_rounded;
              }
            } else {
              final info = categoryInfoMap[entry.category]!;
              color = info.color;
              label = info.label;
              icon = info.icon;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 16),
                      const Gap(8),
                      Text(label,
                          style: GoogleFonts.dmSans(
                              color: context.appTextSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('₹${entry.amount.toStringAsFixed(0)}',
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
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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