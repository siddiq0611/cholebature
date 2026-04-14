import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/custom_category_model.dart';
import '../models/transaction_model.dart';
import '../providers/custom_category_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  static const _labels = {
    DateFilter.daily: 'Day',
    DateFilter.weekly: 'Week',
    DateFilter.monthly: 'Month',
    DateFilter.yearly: 'Year',
    DateFilter.overall: 'All',
    DateFilter.range: 'Range',
  };

  String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month) {
      return '${start.day} – ${end.day} ${_monthShort(start.month)}';
    }
    return '${start.day} ${_monthShort(start.month)} – ${end.day} ${_monthShort(end.month)}';
  }

  String _monthShort(int m) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];

  String _fmtShort(DateTime d) =>
      '${d.day} ${_monthShort(d.month)} ${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final accent = context.appAccent;

    // Resolve custom category names for active filter chips
    final customCatMap = ref.watch(customCategoryProvider).when(
          data: (list) => {for (final c in list) c.id: c},
          loading: () => <String, CustomCategory>{},
          error: (_, __) => <String, CustomCategory>{},
        );

    String periodLabel() {
      if (filter.specificDate != null) {
        return formatDate(filter.specificDate!);
      }
      switch (filter.filter) {
        case DateFilter.daily:
          final now = DateTime.now();
          final d = filter.day;
          if (d.year == now.year &&
              d.month == now.month &&
              d.day == now.day) return 'Today';
          return '${d.day} ${_monthShort(d.month)} ${d.year}';
        case DateFilter.weekly:
          return _weekLabel(filter.weekStart);
        case DateFilter.monthly:
          return formatMonth(DateTime(filter.year, filter.month));
        case DateFilter.yearly:
          return formatYear(filter.year);
        case DateFilter.overall:
          return '';
        case DateFilter.range:
          if (filter.rangeStart != null && filter.rangeEnd != null) {
            return '${_fmtShort(filter.rangeStart!)} – ${_fmtShort(filter.rangeEnd!)}';
          }
          return 'Custom range';
      }
    }

    final hasAdvancedFilters = filter.hasActiveFilters ||
        filter.sortBy != SortOption.dateNewest;

    final showNavRow = filter.filter != DateFilter.overall;
    final showChevrons = filter.filter != DateFilter.range;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: DateFilter.values.map((f) {
                    final selected = filter.filter == f;
                    return GestureDetector(
                      onTap: () {
                        if (f == DateFilter.range) {
                          _openRangePicker(context, filter, notifier);
                        } else {
                          notifier.setFilter(f);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? accent
                              : context.appSurfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? accent : context.appBorder,
                          ),
                        ),
                        child: Text(
                          _labels[f]!,
                          style: GoogleFonts.dmSans(
                            color: selected
                                ? Colors.white
                                : context.appTextSecondary,
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
              ),
            ),
            GestureDetector(
              onTap: () => _showAdvancedFilters(context, ref),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hasAdvancedFilters
                      ? accent.withValues(alpha: 0.15)
                      : context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasAdvancedFilters ? accent : context.appBorder,
                    width: hasAdvancedFilters ? 1.5 : 1,
                  ),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color:
                      hasAdvancedFilters ? accent : context.appTextMuted,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        if (showNavRow) ...[
          const Gap(12),
          Row(
            children: [
              if (showChevrons)
                _NavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => notifier.previous(),
                ),
              if (showChevrons) const Gap(10),
              GestureDetector(
                onTap: () =>
                    _openCalendarPicker(context, filter, notifier),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      periodLabel(),
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
              if (showChevrons) const Gap(10),
              if (showChevrons)
                _NavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => notifier.next(),
                ),
              if (filter.filter == DateFilter.range) ...[
                const Gap(8),
                GestureDetector(
                  onTap: () => notifier.clearCustomRange(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          context.appExpense.withValues(alpha: 0.12),
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
                            color: context.appExpense,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (filter.specificDate != null) ...[
                const Gap(8),
                GestureDetector(
                  onTap: () => notifier.setSpecificDate(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          context.appExpense.withValues(alpha: 0.12),
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
                            color: context.appExpense,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        // Active filter chips (built-in + custom)
        if (filter.selectedCategories.isNotEmpty ||
            filter.selectedCustomCategoryIds.isNotEmpty ||
            filter.sortBy != SortOption.dateNewest) ...[
          const Gap(8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Built-in category chips
                ...filter.selectedCategories.map((cat) {
                  final info = categoryInfoMap[cat]!;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: info.label,
                      color: info.color,
                      icon: info.icon,
                      onRemove: () => notifier.toggleCategory(cat),
                    ),
                  );
                }),
                // Custom category chips
                ...filter.selectedCustomCategoryIds.map((id) {
                  final cat = customCatMap[id];
                  final label = cat?.name ?? 'Unknown';
                  final color = cat != null
                      ? (cat.deleted ? context.appTextMuted : cat.color)
                      : context.appTextMuted;
                  final icon = cat?.icon ?? Icons.category_rounded;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: label,
                      color: color,
                      icon: icon,
                      onRemove: () => notifier.toggleCustomCategory(id),
                    ),
                  );
                }),
                if (filter.sortBy != SortOption.dateNewest)
                  _FilterChip(
                    label: _sortLabel(filter.sortBy),
                    color: context.appAccent,
                    icon: Icons.sort_rounded,
                    onRemove: () =>
                        notifier.setSortBy(SortOption.dateNewest),
                  ),
                if (filter.hasActiveFilters ||
                    filter.sortBy != SortOption.dateNewest)
                  GestureDetector(
                    onTap: () => notifier.clearAdvancedFilters(),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Clear all',
                        style: GoogleFonts.dmSans(
                          color: context.appExpense,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openRangePicker(BuildContext context, FilterState filter,
      FilterNotifier notifier) async {
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

  Future<void> _openCalendarPicker(BuildContext context, FilterState filter,
      FilterNotifier notifier) async {
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
        final picked = await _showMonthYearPicker(
          context: context,
          initialYear: filter.year,
          initialMonth: filter.month,
          mode: _PickerMode.month,
        );
        if (picked != null) notifier.setMonthFromDate(picked);
        break;

      case DateFilter.yearly:
        final picked = await _showMonthYearPicker(
          context: context,
          initialYear: filter.year,
          initialMonth: filter.month,
          mode: _PickerMode.year,
        );
        if (picked != null) notifier.setYearValue(picked.year);
        break;

      case DateFilter.range:
        await _openRangePicker(context, filter, notifier);
        break;

      case DateFilter.overall:
        break;
    }
  }

  String _sortLabel(SortOption s) {
    switch (s) {
      case SortOption.dateNewest:
        return 'Newest first';
      case SortOption.dateOldest:
        return 'Oldest first';
      case SortOption.amountHigh:
        return 'Amount ↓';
      case SortOption.amountLow:
        return 'Amount ↑';
    }
  }

  void _showAdvancedFilters(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AdvancedFilterSheet(ref: ref),
    );
  }
}

// ─── Month/Year picker ────────────────────────────────────────────────────────

enum _PickerMode { month, year }

Future<DateTime?> _showMonthYearPicker({
  required BuildContext context,
  required int initialYear,
  required int initialMonth,
  required _PickerMode mode,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => _MonthYearPickerDialog(
      initialYear: initialYear,
      initialMonth: initialMonth,
      mode: mode,
    ),
  );
}

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final _PickerMode mode;

  const _MonthYearPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.mode,
  });

  @override
  State<_MonthYearPickerDialog> createState() =>
      _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
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
    final isMonthMode = widget.mode == _PickerMode.month;

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
                Text(
                  '$_year',
                  style: GoogleFonts.dmSans(
                      color: context.appTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
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
                    onTap:
                        selectable ? () => setState(() => _month = m) : null,
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
                          child: Text(
                            '$y',
                            style: GoogleFonts.dmSans(
                              color: isSelected
                                  ? Colors.white
                                  : context.appTextPrimary,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
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

// ─── Date Range Picker Dialog (shared) ───────────────────────────────────────

class DateRangePickerDialog extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const DateRangePickerDialog({
    super.key,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<DateRangePickerDialog> createState() =>
      _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<DateRangePickerDialog> {
  DateTime? _start;
  DateTime? _end;

  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmt(DateTime d) =>
      '${d.day} ${_monthShort[d.month - 1]} ${d.year}';

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: isStart ? 'Select start date' : 'Select end date',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
        if (_start != null && _start!.isAfter(picked)) _start = picked;
      }
    });
  }

  Widget _dateButton(BuildContext context, bool isStart) {
    final value = isStart ? _start : _end;
    final accent = context.appAccent;
    return GestureDetector(
      onTap: () => _pickDate(isStart),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: value != null
              ? accent.withValues(alpha: 0.08)
              : context.appSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null ? accent : context.appBorder,
            width: value != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: value != null ? accent : context.appTextMuted,
            ),
            const Gap(6),
            Expanded(
              child: Text(
                value != null ? _fmt(value) : (isStart ? 'Start date' : 'End date'),
                style: GoogleFonts.dmSans(
                  color: value != null
                      ? context.appTextPrimary
                      : context.appTextMuted,
                  fontSize: 13,
                  fontWeight: value != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _start != null && _end != null;

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
              'Select date range',
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const Gap(20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From',
                          style: GoogleFonts.dmSans(
                              color: context.appTextSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const Gap(6),
                      _dateButton(context, true),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(top: 18, left: 10, right: 10),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: context.appTextMuted),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To',
                          style: GoogleFonts.dmSans(
                              color: context.appTextSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const Gap(6),
                      _dateButton(context, false),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(20),
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
                    onPressed: canApply
                        ? () => Navigator.pop(context, (_start!, _end!))
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appAccent,
                      disabledBackgroundColor:
                          context.appAccent.withValues(alpha: 0.3),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Apply',
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

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const Gap(4),
          Text(
            label,
            style: GoogleFonts.dmSans(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          const Gap(4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, color: color, size: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Advanced Filter Sheet ────────────────────────────────────────────────────
// Now shows BOTH built-in and custom categories.

class _AdvancedFilterSheet extends ConsumerWidget {
  final WidgetRef ref;
  const _AdvancedFilterSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final filter = widgetRef.watch(filterProvider);
    final notifier = widgetRef.read(filterProvider.notifier);

    // Only show expense-type custom categories (income ones aren't relevant
    // to the expense transaction list but we include all active ones so users
    // can filter income custom categories too).
    final customCats = widgetRef.watch(customCategoryProvider).when(
          data: (list) => list.where((c) => !c.deleted).toList(),
          loading: () => <CustomCategory>[],
          error: (_, __) => <CustomCategory>[],
        );

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(16),
            Row(
              children: [
                Text(
                  'Filters & Sort',
                  style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    notifier.clearAdvancedFilters();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Reset',
                    style: GoogleFonts.dmSans(
                      color: context.appExpense,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(20),

            // ── Sort ──────────────────────────────────────────────────────
            Text(
              'Sort by',
              style: GoogleFonts.dmSans(
                color: context.appTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SortOption.values.map((s) {
                final isSel = filter.sortBy == s;
                return GestureDetector(
                  onTap: () => notifier.setSortBy(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSel
                          ? context.appAccent.withValues(alpha: 0.15)
                          : context.appSurfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel
                            ? context.appAccent
                            : context.appBorder,
                        width: isSel ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      _sortLabel(s),
                      style: GoogleFonts.dmSans(
                        color: isSel
                            ? context.appAccent
                            : context.appTextSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Gap(20),

            // ── Built-in categories ────────────────────────────────────────
            Text(
              'Filter by category',
              style: GoogleFonts.dmSans(
                color: context.appTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TransactionCategory.values.map((cat) {
                final info = categoryInfoMap[cat]!;
                final isSel = filter.selectedCategories.contains(cat);
                return GestureDetector(
                  onTap: () => notifier.toggleCategory(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSel
                          ? info.color.withValues(alpha: 0.18)
                          : context.appSurfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel ? info.color : context.appBorder,
                        width: isSel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(info.icon,
                            color: isSel
                                ? info.color
                                : context.appTextMuted,
                            size: 13),
                        const Gap(5),
                        Text(
                          info.label,
                          style: GoogleFonts.dmSans(
                            color: isSel
                                ? info.color
                                : context.appTextSecondary,
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Custom categories (only shown if any exist) ────────────────
            if (customCats.isNotEmpty) ...[
              const Gap(16),
              Text(
                'Custom categories',
                style: GoogleFonts.dmSans(
                  color: context.appTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: customCats.map((cat) {
                  final isSel =
                      filter.selectedCustomCategoryIds.contains(cat.id);
                  return GestureDetector(
                    onTap: () => notifier.toggleCustomCategory(cat.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSel
                            ? cat.color.withValues(alpha: 0.18)
                            : context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel ? cat.color : context.appBorder,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon,
                              color: isSel
                                  ? cat.color
                                  : context.appTextMuted,
                              size: 13),
                          const Gap(5),
                          Text(
                            cat.name,
                            style: GoogleFonts.dmSans(
                              color: isSel
                                  ? cat.color
                                  : context.appTextSecondary,
                              fontSize: 12,
                              fontWeight: isSel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const Gap(24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: context.appAccent),
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(SortOption s) {
    switch (s) {
      case SortOption.dateNewest:
        return 'Newest first';
      case SortOption.dateOldest:
        return 'Oldest first';
      case SortOption.amountHigh:
        return 'Amount ↓ High';
      case SortOption.amountLow:
        return 'Amount ↑ Low';
    }
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
}