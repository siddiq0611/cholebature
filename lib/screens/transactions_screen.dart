import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/search_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/filter_bar.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      ref.read(transactionSearchProvider.notifier).state =
          _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchActive = true);
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    setState(() => _searchActive = false);
    _searchCtrl.clear();
    ref.read(transactionSearchProvider.notifier).state = '';
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionListProvider);
    final notifier = ref.read(transactionListProvider.notifier);
    final query = ref.watch(transactionSearchProvider).trim().toLowerCase();

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: context.appBg,
            floating: true,
            snap: true,
            title: _searchActive
                ? TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    autofocus: true,
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search by name or note…',
                      hintStyle: GoogleFonts.dmSans(
                          color: context.appTextMuted, fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                : Text(
                    'Transactions',
                    style: GoogleFonts.dmSans(
                      color: context.appTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
            actions: [
              if (_searchActive)
                // Clear / close search
                GestureDetector(
                  onTap: _closeSearch,
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: context.appSurfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: context.appTextSecondary, size: 18),
                  ),
                )
              else ...[
                // Search icon
                GestureDetector(
                  onTap: _openSearch,
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: context.appSurfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: Icon(Icons.search_rounded,
                        color: context.appTextSecondary, size: 18),
                  ),
                ),
                const Gap(8),
              ],
            ],
          ),

          // ── Search hint strip (when search is active) ──────────────────
          if (_searchActive)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverToBoxAdapter(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: query.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: context.appAccent.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    context.appAccent.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline_rounded,
                                color: context.appAccent, size: 14),
                            const Gap(8),
                            Text('Type to search by title or note',
                                style: GoogleFonts.dmSans(
                                    color: context.appAccent, fontSize: 12)),
                          ]),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),

          // ── Filter bar (hidden during active search) ───────────────────
          if (!_searchActive)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(child: FilterBar()),
            ),

          // ── Summary bar ────────────────────────────────────────────────
          if (!_searchActive)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              sliver: SliverToBoxAdapter(child: _SummaryBar()),
            ),

          // ── Transaction list ───────────────────────────────────────────
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
            data: (allTxs) {
              // Apply search filter on top of existing provider results
              final txs = query.isEmpty
                  ? allTxs
                  : allTxs.where((t) {
                      final titleMatch =
                          t.title.toLowerCase().contains(query);
                      final noteMatch =
                          (t.note ?? '').toLowerCase().contains(query);
                      return titleMatch || noteMatch;
                    }).toList();

              if (txs.isEmpty) {
                return SliverFillRemaining(
                  child: query.isNotEmpty
                      ? _NoSearchResults(query: query)
                      : _EmptyState(),
                );
              }

              // Show flat list when searching (no date grouping)
              if (query.isNotEmpty) {
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TransactionTile(
                          transaction: txs[i],
                          index: i,
                          onDelete: () => notifier.delete(txs[i].id),
                        ),
                      ),
                      childCount: txs.length,
                    ),
                  ),
                );
              }

              // Normal grouped list
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

// ─── No search results ────────────────────────────────────────────────────────

class _NoSearchResults extends StatelessWidget {
  final String query;
  const _NoSearchResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: context.appTextMuted),
          const Gap(16),
          Text(
            'No results for "$query"',
            style: GoogleFonts.dmSans(
              color: context.appTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Text(
            'Try a different title or note',
            style: GoogleFonts.dmSans(
                color: context.appTextMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Summary bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends ConsumerWidget {
  const _SummaryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);

    final net = summary.income - summary.expense;
    final hasData = summary.income != 0 ||
        summary.expense != 0 ||
        summary.borrowed != 0 ||
        summary.lent != 0;

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

// ─── Empty state ──────────────────────────────────────────────────────────────

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