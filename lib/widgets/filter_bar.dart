// lib/widgets/filter_bar.dart
// CHANGED: Added 'Day' filter tab matching the new DateFilter.daily enum value.
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

  // FIX: added DateFilter.daily label
  static const _labels = {
    DateFilter.daily:   'Day',
    DateFilter.weekly:  'Week',
    DateFilter.monthly: 'Month',
    DateFilter.yearly:  'Year',
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
    final filter   = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final accent   = context.appAccent;

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

    final hasAdvancedFilters = filter.hasActiveFilters ||
        filter.sortBy != SortOption.dateNewest;

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
                width: 36, height: 36,
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
              GestureDetector(
                onTap: () => _pickSpecificDate(context, notifier),
                child: Text(
                  periodLabel(),
                  style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
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

  String _sortLabel(SortOption s) {
    switch (s) {
      case SortOption.dateNewest:  return 'Newest first';
      case SortOption.dateOldest:  return 'Oldest first';
      case SortOption.amountHigh:  return 'Amount ↓';
      case SortOption.amountLow:   return 'Amount ↑';
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
    final filter   = widgetRef.watch(filterProvider);
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
                width: 36, height: 4,
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
                final isSel =
                    filter.selectedCategories.contains(cat);
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
      case SortOption.dateNewest:  return 'Newest first';
      case SortOption.dateOldest:  return 'Oldest first';
      case SortOption.amountHigh:  return 'Amount ↓ High';
      case SortOption.amountLow:   return 'Amount ↑ Low';
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
        width: 32, height: 32,
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