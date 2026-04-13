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

              // Group all transactions by date
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
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
                                  padding: const EdgeInsets.only(bottom: 8),
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 60, color: context.appTextMuted),
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
            style: GoogleFonts.dmSans(color: context.appTextMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}