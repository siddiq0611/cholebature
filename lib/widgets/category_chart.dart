import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../models/custom_category_model.dart';
import '../providers/custom_category_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';

// CategoryChart now reads categoryExpenseEntriesProvider so custom categories
// appear as their own slices instead of being merged into "Misc".
class CategoryChart extends ConsumerStatefulWidget {
  // Keep the old data param for backward-compat but it is ignored now —
  // the widget reads the provider directly.
  final Map<TransactionCategory, double> data;

  const CategoryChart({super.key, required this.data});

  @override
  ConsumerState<CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends ConsumerState<CategoryChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(categoryExpenseEntriesProvider);
    final customCats = ref.watch(customCategoryProvider).when(
          data: (list) => {for (final c in list) c.id: c},
          loading: () => <String, CustomCategory>{},
          error: (_, __) => <String, CustomCategory>{},
        );

    if (entries.isEmpty) return _EmptyChart();

    final total = entries.fold<double>(0, (s, e) => s + e.amount);

    final sections = entries.asMap().entries.map((mapEntry) {
      final i = mapEntry.key;
      final e = mapEntry.value;
      final isTouched = i == _touchedIndex;
      final pct = total > 0 ? (e.amount / total * 100) : 0;

      Color color;
      if (e.isCustom) {
        final cat = customCats[e.customCategoryId];
        color = cat != null ? (cat.deleted ? context.appTextMuted : cat.color) : context.appTextMuted;
      } else {
        color = categoryInfoMap[e.category]!.color;
      }

      return PieChartSectionData(
        value: e.amount,
        color: color,
        radius: isTouched ? 68 : 56,
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        borderSide: isTouched
            ? BorderSide(color: color, width: 2)
            : const BorderSide(color: Colors.transparent, width: 0),
      );
    }).toList();

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
          Text(
            'Spending Breakdown',
            style: GoogleFonts.dmSans(
              color: context.appTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(16),

          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sections: sections,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),

          const Gap(16),

          _LegendGrid(entries: entries, total: total, customCats: customCats),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 200.ms);
  }
}

class _LegendGrid extends StatelessWidget {
  final List<CategoryExpenseEntry> entries;
  final double total;
  final Map<String, CustomCategory> customCats;

  const _LegendGrid({
    required this.entries,
    required this.total,
    required this.customCats,
  });

  @override
  Widget build(BuildContext context) {
    final left = <CategoryExpenseEntry>[];
    final right = <CategoryExpenseEntry>[];
    for (var i = 0; i < entries.length; i++) {
      if (i.isEven) {
        left.add(entries[i]);
      } else {
        right.add(entries[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: left
                .map((e) => _LegendItem(
                      entry: e,
                      total: total,
                      customCats: customCats,
                    ))
                .toList(),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            children: right
                .map((e) => _LegendItem(
                      entry: e,
                      total: total,
                      customCats: customCats,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final CategoryExpenseEntry entry;
  final double total;
  final Map<String, CustomCategory> customCats;

  const _LegendItem({
    required this.entry,
    required this.total,
    required this.customCats,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? entry.amount / total * 100 : 0.0;

    Color color;
    String label;

    if (entry.isCustom) {
      final cat = customCats[entry.customCategoryId];
      if (cat != null) {
        color = cat.deleted ? context.appTextMuted : cat.color;
        label = cat.deleted ? '${cat.name} (deleted)' : cat.name;
      } else {
        color = context.appTextMuted;
        label = 'Unknown';
      }
    } else {
      final info = categoryInfoMap[entry.category]!;
      color = info.color;
      label = info.label;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const Gap(6),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: context.appTextSecondary,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: GoogleFonts.dmSans(
              color: context.appTextPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.pie_chart_outline_rounded,
              color: context.appTextMuted, size: 40),
          const Gap(12),
          Text(
            'No expense data yet',
            style: GoogleFonts.dmSans(
                color: context.appTextMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}