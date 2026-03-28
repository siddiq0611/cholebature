import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/budget_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class BudgetBar extends ConsumerWidget {
  const BudgetBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(budgetResultsProvider);

    return resultsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (results) {
        if (results.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Budget Overview',
                  style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${results.where((r) => r.isExceeded).length} exceeded',
                  style: GoogleFonts.dmSans(
                    color: results.any((r) => r.isExceeded)
                        ? context.appExpense
                        : context.appTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Gap(12),
            ...results.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BudgetRow(result: e.value, index: e.key),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final BudgetResult result;
  final int index;

  const _BudgetRow({required this.result, required this.index});

  @override
  Widget build(BuildContext context) {
    final isExceeded = result.isExceeded;
    final progress = result.progress;
    final barColor = isExceeded
        ? context.appExpense
        : progress > 0.8
            ? context.appBorrowed
            : context.appIncome;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExceeded
              ? context.appExpense.withValues(alpha: 0.35)
              : context.appBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isExceeded
                          ? context.appExpense
                          : context.appAccent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  result.budget.label,
                  style: GoogleFonts.dmSans(
                    color: isExceeded
                        ? context.appExpense
                        : context.appAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: formatCompact(result.spent),
                      style: GoogleFonts.dmSans(
                        color: isExceeded
                            ? context.appExpense
                            : context.appTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${formatCompact(result.budget.amount)}',
                      style: GoogleFonts.dmSans(
                        color: context.appTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.appBorder,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 5,
            ),
          ),
          const Gap(6),
          Row(
            children: [
              if (isExceeded)
                Text(
                  '${formatCompact(result.spent - result.budget.amount)} over budget',
                  style: GoogleFonts.dmSans(
                    color: context.appExpense,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Text(
                  '${formatCompact(result.remaining)} remaining',
                  style: GoogleFonts.dmSans(
                    color: context.appIncome,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const Spacer(),
              if (result.insightText.isNotEmpty)
                Flexible(
                  child: Text(
                    result.insightText,
                    style: GoogleFonts.dmSans(
                      color: context.appTextMuted,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 50).ms)
        .slideY(begin: 0.05, end: 0, duration: 300.ms, delay: (index * 50).ms);
  }
}