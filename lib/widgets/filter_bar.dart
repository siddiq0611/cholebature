import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  static const _labels = {
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
      switch (filter.filter) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
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
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (filter.filter != DateFilter.overall) ...[
          const Gap(12),
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => notifier.previous(),
              ),
              const Gap(10),
              Text(
                periodLabel(),
                style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const Gap(10),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => notifier.next(),
              ),
            ],
          ),
        ],
      ],
    );
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