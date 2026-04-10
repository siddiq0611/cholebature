import 'package:chole_bature/models/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/borrow_lend_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/borrow_lend_tile.dart';
import 'add_transaction_sheet.dart';

// Pagination for borrow/lend
final blPageProvider = StateProvider<int>((ref) => 0);
const _kBLPageSize = 15;

class BorrowLendScreen extends ConsumerWidget {
  const BorrowLendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blAsync = ref.watch(borrowLendProvider);
    final notifier = ref.read(borrowLendProvider.notifier);
    final page = ref.watch(blPageProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddTransactionSheet(
            defaultType: TransactionType.borrowed,
          ),
        ),
        backgroundColor: context.appAccent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.appBg,
            floating: true,
            snap: true,
            title: Text(
              'Borrow & Lend',
              style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          blAsync.when(
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
                      style: TextStyle(color: context.appExpense))),
            ),
            data: (txs) {
              final entries = txs.map((t) => BorrowLendEntry(t)).toList();
              final borrowed = entries.where((e) => e.isBorrowed).toList();
              final lent = entries.where((e) => e.isLent).toList();
              final summary = BorrowLendSummary.from(entries);

              // Flatten for pagination: borrow section then lend section
              final allEntries = <_SectionedEntry>[];
              if (borrowed.isNotEmpty) {
                allEntries.add(const _SectionedEntry.borrowedHeader());
                for (final e in borrowed) {
                  allEntries.add(_SectionedEntry.entry(e));
                }
              }
              if (lent.isNotEmpty) {
                allEntries.add(const _SectionedEntry.lentHeader());
                for (final e in lent) {
                  allEntries.add(_SectionedEntry.entry(e));
                }
              }

              // Count only entry items for pagination
              final entryItems = allEntries.where((i) => i.entry != null).toList();
              final totalEntries = entryItems.length;
              final totalPages = totalEntries > 0
                  ? (totalEntries / _kBLPageSize).ceil()
                  : 1;
              final clampedPage = page.clamp(0, totalPages - 1);
              final startIdx = clampedPage * _kBLPageSize;
              final endIdx = (startIdx + _kBLPageSize).clamp(0, totalEntries);
              final pageEntries = entryItems
                  .sublist(startIdx, endIdx)
                  .map((i) => i.entry!)
                  .toSet();

              // Build display preserving headers
              final displayItems = <_SectionedEntry>[];
              _SectionedEntry? pendingHeader;
              for (final item in allEntries) {
                if (item.entry == null) {
                  pendingHeader = item;
                } else if (pageEntries.any((e) => e.id == item.entry!.id)) {
                  if (pendingHeader != null) {
                    displayItems.add(pendingHeader);
                    pendingHeader = null;
                  }
                  displayItems.add(item);
                }
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _BLSummary(summary: summary),
                    const Gap(20),
                    if (entries.isEmpty)
                      _EmptyState()
                    else ...[
                      ...displayItems.asMap().entries.map((e) {
                        final item = e.value;
                        if (item.entry == null) {
                          // Section header
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: _SectionHeader(
                              label: item.isBorrowedHeader!
                                  ? 'Borrowed  (I owe)'
                                  : 'Lent  (owed to me)',
                              color: item.isBorrowedHeader!
                                  ? context.appBorrowed
                                  : context.appLend,
                              outstanding: item.isBorrowedHeader!
                                  ? summary.outstandingBorrowed
                                  : summary.outstandingLent,
                              count: item.isBorrowedHeader!
                                  ? borrowed.length
                                  : lent.length,
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BorrowLendTile(
                            entry: item.entry!,
                            index: e.key,
                            onChanged: () => notifier.load(),
                          ),
                        );
                      }),
                      // Pagination bar
                      if (totalPages > 1)
                        _PaginationBar(
                          currentPage: clampedPage,
                          totalPages: totalPages,
                          totalItems: totalEntries,
                          onPrev: clampedPage > 0
                              ? () => ref
                                  .read(blPageProvider.notifier)
                                  .state = clampedPage - 1
                              : null,
                          onNext: clampedPage < totalPages - 1
                              ? () => ref
                                  .read(blPageProvider.notifier)
                                  .state = clampedPage + 1
                              : null,
                        ),
                    ],
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionedEntry {
  final BorrowLendEntry? entry;
  final bool? isBorrowedHeader; // null if it's a data entry

  const _SectionedEntry.entry(this.entry) : isBorrowedHeader = null;
  const _SectionedEntry.borrowedHeader()
      : entry = null,
        isBorrowedHeader = true;
  const _SectionedEntry.lentHeader()
      : entry = null,
        isBorrowedHeader = false;
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
    final start = currentPage * _kBLPageSize + 1;
    final end = ((currentPage + 1) * _kBLPageSize).clamp(0, totalItems);
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

// ── Widgets ────────────────────────────────────────────────────────────────────

class _BLSummary extends StatelessWidget {
  final BorrowLendSummary summary;
  const _BLSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'I Owe',
                total: summary.totalBorrowed,
                outstanding: summary.outstandingBorrowed,
                color: context.appBorrowed,
                icon: Icons.arrow_upward_rounded,
              ),
            ),
            const Gap(10),
            Expanded(
              child: _SummaryCard(
                label: 'Owed to Me',
                total: summary.totalLent,
                outstanding: summary.outstandingLent,
                color: context.appLend,
                icon: Icons.arrow_downward_rounded,
              ),
            ),
          ],
        ),
        const Gap(10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (summary.netPositive ? context.appIncome : context.appExpense)
                    .withValues(alpha: 0.1),
                context.appSurface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (summary.netPositive ? context.appIncome : context.appExpense)
                  .withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (summary.netPositive ? context.appIncome : context.appExpense)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  summary.netPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: summary.netPositive ? context.appIncome : context.appExpense,
                  size: 18,
                ),
              ),
              const Gap(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net Outstanding Position',
                      style: GoogleFonts.dmSans(
                          color: context.appTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  Text(
                    summary.netPositive
                        ? 'Others owe you ${formatCompact(summary.netPosition.abs())}'
                        : 'You owe others ${formatCompact(summary.netPosition.abs())}',
                    style: GoogleFonts.dmSans(
                      color: summary.netPositive ? context.appIncome : context.appExpense,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms);
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double total;
  final double outstanding;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.total,
    required this.outstanding,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.dmSans(
                        color: context.appTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const Gap(2),
                Text(
                  formatCompact(outstanding),
                  style: GoogleFonts.dmSans(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (total != outstanding)
                  Text('of ${formatCompact(total)} total',
                      style: GoogleFonts.dmSans(
                          color: context.appTextMuted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final double outstanding;
  final int count;

  const _SectionHeader({
    required this.label,
    required this.color,
    required this.outstanding,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const Gap(8),
          Text(label,
              style: GoogleFonts.dmSans(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
          const Spacer(),
          Text('${formatCompact(outstanding)} outstanding · $count',
              style: GoogleFonts.dmSans(
                  color: context.appTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handshake_rounded, size: 60, color: context.appTextMuted),
            const Gap(16),
            Text('No borrow/lend entries',
                style: GoogleFonts.dmSans(
                    color: context.appTextSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const Gap(6),
            Text('Tap + to record borrowed or lent money',
                style: GoogleFonts.dmSans(color: context.appTextMuted, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}