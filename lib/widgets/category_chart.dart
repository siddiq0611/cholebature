import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';

class CategoryChart extends StatefulWidget {
  final Map<TransactionCategory, double> data;

  const CategoryChart({super.key, required this.data});

  @override
  State<CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<CategoryChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return _EmptyChart();

    final sorted = widget.data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (s, e) => s + e.value);

    final sections = sorted.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final info = categoryInfoMap[e.key]!;
      final isTouched = i == _touchedIndex;
      final pct = total > 0 ? (e.value / total * 100) : 0;

      return PieChartSectionData(
        value: e.value,
        color: info.color,
        radius: isTouched ? 68 : 56,
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        borderSide: isTouched
            ? BorderSide(color: info.color, width: 2)
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

          // ── Pie chart — fixed size, never overflows ──
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

          // ── Legend grid — shows ALL categories in a 2-column grid ──
          // Using a grid avoids Row overflow regardless of category count.
          _LegendGrid(entries: sorted, total: total),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 200.ms);
  }
}

/// Two-column legend grid — expands to fit any number of categories.
class _LegendGrid extends StatelessWidget {
  final List<MapEntry<TransactionCategory, double>> entries;
  final double total;

  const _LegendGrid({required this.entries, required this.total});

  @override
  Widget build(BuildContext context) {
    // Split into two columns
    final left = <MapEntry<TransactionCategory, double>>[];
    final right = <MapEntry<TransactionCategory, double>>[];
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
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final MapEntry<TransactionCategory, double> entry;
  final double total;

  const _LegendItem({required this.entry, required this.total});

  @override
  Widget build(BuildContext context) {
    final info = categoryInfoMap[entry.key]!;
    final pct = total > 0 ? entry.value / total * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: info.color,
              shape: BoxShape.circle,
            ),
          ),
          const Gap(6),
          Expanded(
            child: Text(
              info.label,
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