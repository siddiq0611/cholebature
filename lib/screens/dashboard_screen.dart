import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_bar.dart';
import '../widgets/category_chart.dart';
import '../widgets/summary_cards.dart';
import 'add_transaction_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final catData = ref.watch(categoryExpenseProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.appBg,
            floating: true,
            snap: true,
            expandedHeight: 0,
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
                    ThemeMode.light => ThemeMode.dark,
                    ThemeMode.dark => ThemeMode.system,
                  };
                  ref.read(themeModeProvider.notifier).state = next;
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
                _MonthLabel(),
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
                CategoryChart(data: catData),
                const Gap(16),
                _CategoryBreakdownList(
                    data: catData, total: summary.expense),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return Text(
      '${months[now.month - 1]} ${now.year}',
      style: GoogleFonts.dmSans(
        color: context.appTextSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddTransactionSheet(),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.appAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            const Gap(4),
            Text(
              'Add',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownList extends StatelessWidget {
  final Map data;
  final double total;

  const _CategoryBreakdownList({required this.data, required this.total});

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
          Text(
            'Category Details',
            style: GoogleFonts.dmSans(
              color: context.appTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(14),
          ...sorted.map((entry) {
            final info = categoryInfoMap[entry.key]!;
            final pct = total > 0 ? entry.value / total : 0.0;
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
                      Text('₹${entry.value.toStringAsFixed(0)}',
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