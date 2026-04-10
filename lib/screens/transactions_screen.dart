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

// Pagination state for transactions tab
final txPageProvider = StateProvider<int>((ref) => 0);
const _kTxPageSize = 15;

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionListProvider);
    final notifier = ref.read(transactionListProvider.notifier);
    final page = ref.watch(txPageProvider);

    // Reset page when filter changes
    ref.listen(filterProvider, (_, __) {
      ref.read(txPageProvider.notifier).state = 0;
    });

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

              // Paginate the flat list first
              final totalTxs = txs.length;
              final totalPages = (totalTxs / _kTxPageSize).ceil();
              final clampedPage = page.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
              final startIdx = clampedPage * _kTxPageSize;
              final endIdx = (startIdx + _kTxPageSize).clamp(0, totalTxs);
              final pageTxs = txs.sublist(startIdx, endIdx);

              // Group paginated transactions by date
              final grouped = <String, List<Transaction>>{};
              for (final t in pageTxs) {
                final key = formatDate(t.date);
                grouped.putIfAbsent(key, () => []).add(t);
              }
              final keys = grouped.keys.toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      // Last item is pagination bar
                      if (i == keys.length) {
                        if (totalPages <= 1) return const SizedBox.shrink();
                        return _PaginationBar(
                          currentPage: clampedPage,
                          totalPages: totalPages,
                          totalItems: totalTxs,
                          onPrev: clampedPage > 0
                              ? () => ref.read(txPageProvider.notifier).state = clampedPage - 1
                              : null,
                          onNext: clampedPage < totalPages - 1
                              ? () => ref.read(txPageProvider.notifier).state = clampedPage + 1
                              : null,
                        );
                      }

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
                    childCount: keys.length + 1, // +1 for pagination bar
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

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final start = currentPage * _kTxPageSize + 1;
    final end = ((currentPage + 1) * _kTxPageSize).clamp(0, totalItems);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
          const Gap(16),
          Column(
            children: [
              Text(
                '$start–$end of $totalItems',
                style: GoogleFonts.dmSans(
                    color: context.appTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                'Page ${currentPage + 1} of $totalPages',
                style: GoogleFonts.dmSans(
                    color: context.appTextMuted, fontSize: 11),
              ),
            ],
          ),
          const Gap(16),
          _PageBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PageBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? context.appSurfaceElevated
              : context.appBorder.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appBorder),
        ),
        child: Icon(icon,
            color: enabled ? context.appTextSecondary : context.appTextMuted,
            size: 20),
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