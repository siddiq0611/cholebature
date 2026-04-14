import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/filter_bar.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionListProvider);
    final notifier = ref.read(transactionListProvider.notifier);

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.appBg,
            floating: true,
            snap: true,
            title: Text(
              'Transactions',
              style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(child: FilterBar()),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            sliver: SliverToBoxAdapter(child: _SummaryBar()),
          ),
          txAsync.when(
            loading: () => SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: context.appAccent,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error: $e',
                    style: TextStyle(color: context.appExpense)),
              ),
            ),
            data: (txs) {
              if (txs.isEmpty) {
                return SliverFillRemaining(child: _EmptyState());
              }

              final grouped = <String, List<Transaction>>{};
              for (final t in txs) {
                final key = formatDate(t.date);
                grouped.putIfAbsent(key, () => []).add(t);
              }
              final keys = grouped.keys.toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final key = keys[i];
                      final dayTxs = grouped[key]!;
                      final dayTotal = dayTxs.fold<double>(
                        0,
                        (sum, t) =>
                            sum +
                            (t.type == TransactionType.expense
                                ? -t.amount
                                : t.amount),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Text(
                                  key,
                                  style: GoogleFonts.dmSans(
                                    color: context.appTextSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${dayTotal >= 0 ? '+' : ''}${formatCompact(dayTotal)}',
                                  style: GoogleFonts.dmSans(
                                    color: dayTotal >= 0
                                        ? context.appIncome
                                        : context.appExpense,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...dayTxs.asMap().entries.map(
                                (entry) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: TransactionTile(
                                    transaction: entry.value,
                                    index: entry.key,
                                    onDelete: () =>
                                        notifier.delete(entry.value.id),
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                    childCount: keys.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends ConsumerWidget {
  const _SummaryBar();
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
 
    // Net = income - expenses (ignore borrow/lend in the headline number)
    final net = summary.income - summary.expense;
    final hasData = summary.income != 0 || summary.expense != 0 ||
        summary.borrowed != 0 || summary.lent != 0;
 
    if (!hasData) return const SizedBox.shrink();
 
    final isPositive = net >= 0;
    final color = isPositive ? context.appIncome : context.appExpense;
 
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isPositive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPositive ? 'Net surplus' : 'Net deficit',
              style: GoogleFonts.dmSans(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            formatCompact(net.abs()),
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: context.appTextMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const Gap(3),
        Text(
          formatCompact(value.abs()),
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: context.appBorder,
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 60, color: context.appTextMuted),
          const Gap(16),
          Text(
            'No transactions yet',
            style: GoogleFonts.dmSans(
              color: context.appTextSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Text(
            'Tap + to record your first transaction',
            style: GoogleFonts.dmSans(
                color: context.appTextMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}