// lib/widgets/filter_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final accent = context.appAccent;

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
      }
    }

    final hasAdvancedFilters =
        filter.hasActiveFilters || filter.sortBy != SortOption.dateNewest;

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
                      onTap: () => notifier.setFilter(f),
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
            // Advanced filters button
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
                    color:
                        hasAdvancedFilters ? accent : context.appBorder,
                    width: hasAdvancedFilters ? 1.5 : 1,
                  ),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: hasAdvancedFilters ? accent : context.appTextMuted,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        if (filter.filter != DateFilter.overall ||
            filter.specificDate != null) ...[
          const Gap(12),
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => notifier.previous(),
              ),
              const Gap(10),
              // ── Tappable period label — opens calendar picker ────────────
              GestureDetector(
                onTap: () => _openCalendarPicker(context, filter, notifier),
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
              const Gap(10),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => notifier.next(),
              ),
              if (filter.specificDate != null) ...[
                const Gap(8),
                GestureDetector(
                  onTap: () => notifier.setSpecificDate(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
        // Active filter chips row
        if (filter.selectedCategories.isNotEmpty ||
            filter.sortBy != SortOption.dateNewest) ...[
          const Gap(8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
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

  // ── Calendar picker — opens the right picker for each filter mode ──────────
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
        // Show date picker; then snap to week start
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
        // Show a month picker dialog
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

      case DateFilter.overall:
        // Nothing to pick
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

  Future<void> _pickSpecificDate(
      BuildContext context, FilterNotifier notifier) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) notifier.setSpecificDate(picked);
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

// ── Month/Year picker dialog ───────────────────────────────────────────────────

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

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

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

  bool _isYearSelectable(int y) => y <= _maxYear && y >= _minYear;

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
            // Header
            Text(
              isMonthMode ? 'Select Month' : 'Select Year',
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const Gap(16),

            // Year navigator (always shown)
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
                GestureDetector(
                  onTap: isMonthMode
                      ? null
                      : null, // year mode shows year prominently
                  child: Text(
                    '$_year',
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
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
              // Month grid
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
                  final isSelected = m == _month && _year == widget.initialYear;
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
              // Year grid for year mode
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
            // Actions
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

// ─── Shared sub-widgets ────────────────────────────────────────────────────────

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
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
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

class _AdvancedFilterSheet extends ConsumerWidget {
  final WidgetRef ref;
  const _AdvancedFilterSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final filter = widgetRef.watch(filterProvider);
    final notifier = widgetRef.read(filterProvider.notifier);

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

            // Sort
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

            // Category filter
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