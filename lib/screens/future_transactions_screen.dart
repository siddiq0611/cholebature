// lib/screens/future_transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/future_transaction_model.dart';
import '../models/transaction_model.dart';
import '../providers/future_transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/category_icon.dart';
import 'add_future_transaction_sheet.dart';

// ── Pagination provider for scheduled tab ──────────────────────────────────────
final scheduledPageProvider = StateProvider<int>((ref) => 0);
const _kScheduledPageSize = 15;

class FutureTransactionsScreen extends ConsumerWidget {
  const FutureTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ftAsync = ref.watch(futureTransactionProvider);
    final page = ref.watch(scheduledPageProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.appBg,
            floating: true,
            snap: true,
            title: Text('Scheduled',
                style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8)),
            actions: [
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddFutureTransactionSheet(),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: context.appAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    const Gap(4),
                    Text('Schedule',
                        style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ]),
                ),
              ),
            ],
          ),
          ftAsync.when(
            loading: () => SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(
                      color: context.appAccent, strokeCap: StrokeCap.round)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                  child: Text('Error: $e',
                      style: TextStyle(color: context.appExpense))),
            ),
            data: (list) {
              if (list.isEmpty) {
                return SliverFillRemaining(child: _EmptyState());
              }

              final overdue = list.where((ft) => ft.isOverdue).toList();
              final dueToday =
                  list.where((ft) => ft.isDueToday && !ft.isOverdue).toList();
              final upcoming =
                  list.where((ft) => !ft.isOverdue && !ft.isDueToday).toList();

              // Flatten all into sections for pagination
              final allItems = <_SectionedItem>[];
              if (overdue.isNotEmpty) {
                allItems.add(_SectionedItem.header('Overdue', context.appExpense, overdue.length));
                for (final ft in overdue) allItems.add(_SectionedItem.tile(ft));
              }
              if (dueToday.isNotEmpty) {
                allItems.add(_SectionedItem.header('Due Today', context.appBorrowed, dueToday.length));
                for (final ft in dueToday) allItems.add(_SectionedItem.tile(ft));
              }
              if (upcoming.isNotEmpty) {
                allItems.add(_SectionedItem.header('Upcoming', context.appTextSecondary, upcoming.length));
                for (final ft in upcoming) allItems.add(_SectionedItem.tile(ft));
              }

              // Count only tile items for pagination
              final tileItems = allItems.where((i) => i.ft != null).toList();
              final totalTiles = tileItems.length;
              final totalPages = (totalTiles / _kScheduledPageSize).ceil();
              final clampedPage = page.clamp(0, totalPages > 0 ? totalPages - 1 : 0);

              // Get tiles for current page
              final startIdx = clampedPage * _kScheduledPageSize;
              final endIdx = (startIdx + _kScheduledPageSize).clamp(0, totalTiles);
              final pageTiles = tileItems.sublist(startIdx, endIdx).map((i) => i.ft!).toSet();

              // Build display list preserving section headers
              final displayItems = <_SectionedItem>[];
              _SectionedItem? pendingHeader;
              for (final item in allItems) {
                if (item.ft == null) {
                  pendingHeader = item;
                } else if (pageTiles.contains(item.ft)) {
                  if (pendingHeader != null) {
                    displayItems.add(pendingHeader);
                    pendingHeader = null;
                  }
                  displayItems.add(item);
                }
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ...displayItems.asMap().entries.map((e) {
                      final item = e.value;
                      if (item.ft == null) {
                        // Section header
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 8),
                          child: _SectionHeader(
                            label: item.label!,
                            color: item.color!,
                            count: item.count!,
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FutureTransactionTile(ft: item.ft!, index: e.key),
                      );
                    }),
                    // Pagination controls
                    if (totalPages > 1)
                      _PaginationBar(
                        currentPage: clampedPage,
                        totalPages: totalPages,
                        totalItems: totalTiles,
                        onPrev: clampedPage > 0
                            ? () => ref.read(scheduledPageProvider.notifier).state = clampedPage - 1
                            : null,
                        onNext: clampedPage < totalPages - 1
                            ? () => ref.read(scheduledPageProvider.notifier).state = clampedPage + 1
                            : null,
                      ),
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

class _SectionedItem {
  final FutureTransaction? ft;
  final String? label;
  final Color? color;
  final int? count;

  const _SectionedItem.tile(this.ft) : label = null, color = null, count = null;
  const _SectionedItem.header(this.label, this.color, this.count) : ft = null;
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
    final start = currentPage * _kScheduledPageSize + 1;
    final end = ((currentPage + 1) * _kScheduledPageSize).clamp(0, totalItems);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageBtn(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
          ),
          const Gap(16),
          Text(
            '$start–$end of $totalItems',
            style: GoogleFonts.dmSans(
                color: context.appTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const Gap(16),
          _PageBtn(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
          ),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? context.appSurfaceElevated : context.appBorder.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appBorder),
        ),
        child: Icon(icon,
            color: enabled ? context.appTextSecondary : context.appTextMuted,
            size: 18),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  const _SectionHeader({required this.label, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
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
              letterSpacing: 0.4)),
      const Gap(6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text('$count',
            style: GoogleFonts.dmSans(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

// ── Tile ───────────────────────────────────────────────────────────────────────

class FutureTransactionTile extends ConsumerWidget {
  final FutureTransaction ft;
  final int index;
  const FutureTransactionTile({super.key, required this.ft, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = categoryInfoMap[ft.category]!;
    final notifier = ref.read(futureTransactionProvider.notifier);

    Color statusColor;
    String statusLabel;
    if (ft.isOverdue) {
      statusColor = context.appExpense;
      statusLabel = 'Overdue';
    } else if (ft.isDueToday) {
      statusColor = context.appBorrowed;
      statusLabel = 'Due Today';
    } else if (ft.status == FutureStatus.paused) {
      statusColor = context.appTextMuted;
      statusLabel = 'Paused';
    } else {
      statusColor = context.appAccent;
      statusLabel = 'Upcoming';
    }

    final isIncome = ft.type == TransactionType.income;
    final amountColor = isIncome ? context.appIncome : context.appExpense;
    final hasAmount = ft.amount > 0;

    return GestureDetector(
      onTap: () => _showOptions(context, ref, notifier),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ft.isOverdue
                ? context.appExpense.withValues(alpha: 0.4)
                : ft.isDueToday
                    ? context.appBorrowed.withValues(alpha: 0.4)
                    : context.appBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CategoryIcon(category: ft.category, size: 42, iconSize: 18),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ft.title.isNotEmpty ? ft.title : info.label,
                      style: GoogleFonts.dmSans(
                          color: context.appTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11, color: context.appTextMuted),
                      const Gap(4),
                      Text(formatDate(ft.nextDue),
                          style: GoogleFonts.dmSans(
                              color: context.appTextMuted, fontSize: 11)),
                      const Gap(8),
                      Icon(Icons.repeat_rounded,
                          size: 11, color: context.appTextMuted),
                      const Gap(4),
                      Text(ft.recurrenceLabel,
                          style: GoogleFonts.dmSans(
                              color: context.appTextMuted, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  hasAmount
                      ? Text(
                          '${isIncome ? '+' : '-'}₹${ft.amount.toStringAsFixed(0)}',
                          style: GoogleFonts.dmSans(
                              color: amountColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700))
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.appBorrowed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: context.appBorrowed.withValues(alpha: 0.3)),
                          ),
                          child: Text('Variable',
                              style: GoogleFonts.dmSans(
                                  color: context.appBorrowed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                  const Gap(4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(statusLabel,
                        style: GoogleFonts.dmSans(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ]),
            // Quick action buttons for overdue/due today
            if (ft.isOverdue || ft.isDueToday) ...[
              const Gap(10),
              Row(children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Mark Done',
                    icon: Icons.check_circle_rounded,
                    color: context.appIncome,
                    onTap: () => _markDone(context, ref, notifier),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: _ActionButton(
                    label: 'Skip',
                    icon: Icons.skip_next_rounded,
                    color: context.appTextSecondary,
                    onTap: () => notifier.skipCycle(ft),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 40).ms)
        .slideX(begin: -0.04, end: 0, duration: 300.ms, delay: (index * 40).ms);
  }

  /// Shows the mark done dialog using the root navigator — this is the fix
  /// for the "screen dims but nothing happens" bug. We must NOT use the
  /// context that belongs to a bottom sheet or any overlay.
  Future<void> _markDone(
    BuildContext context,
    WidgetRef ref,
    FutureTransactionNotifier notifier,
  ) async {
    // Find the root overlay context — avoids the dialog being swallowed
    // by any bottom sheet's route.
    final result = await showDialog<({double amount, DateTime date})>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => _MarkDoneDialog(ft: ft),
    );
    if (result == null) return;
    await notifier.markDone(ft,
        overrideAmount: result.amount, recordDate: result.date);
  }

  void _showOptions(
    BuildContext context,
    WidgetRef ref,
    FutureTransactionNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (sheetCtx) => _OptionsSheet(
        ft: ft,
        notifier: notifier,
        ref: ref,
        rootContext: context,
      ),
    );
  }
}

// ── Mark Done Dialog ───────────────────────────────────────────────────────────

class _MarkDoneDialog extends StatefulWidget {
  final FutureTransaction ft;
  const _MarkDoneDialog({required this.ft});

  @override
  State<_MarkDoneDialog> createState() => _MarkDoneDialogState();
}

class _MarkDoneDialogState extends State<_MarkDoneDialog> {
  late final TextEditingController _amountCtrl;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.ft.amount > 0 ? widget.ft.amount.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.ft.nextDue.subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _submit() {
    final raw = _amountCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter the amount',
            style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      return;
    }
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a valid amount',
            style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      return;
    }
    // Use rootNavigator: true so we pop the dialog, not any underlying route
    Navigator.of(context, rootNavigator: true).pop((amount: amount, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    final isVariable = widget.ft.amount == 0;

    return AlertDialog(
      backgroundColor: context.appSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      title: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: context.appIncome.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.check_circle_rounded, color: context.appIncome, size: 18),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark as Done',
                  style: GoogleFonts.dmSans(
                      color: context.appTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Text(widget.ft.title,
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(4),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              autofocus: isVariable,
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: isVariable ? 'Enter amount (₹)' : 'Amount (₹)',
                hintText: isVariable ? 'Required' : 'Change if needed',
                prefixIcon: Icon(Icons.currency_rupee_rounded,
                    color: context.appTextMuted, size: 18),
              ),
            ),
            const Gap(12),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      color: context.appTextMuted, size: 16),
                  const Gap(8),
                  Text(
                    '${_date.day}/${_date.month}/${_date.year}',
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary, fontSize: 14),
                  ),
                  const Spacer(),
                  Text('Change',
                      style: GoogleFonts.dmSans(
                          color: context.appAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appTextSecondary,
              side: BorderSide(color: context.appBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
          ),
        ),
        const Gap(10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
            label: Text('Record Transaction',
                style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appIncome,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Options sheet ──────────────────────────────────────────────────────────────

class _OptionsSheet extends ConsumerWidget {
  final FutureTransaction ft;
  final FutureTransactionNotifier notifier;
  final WidgetRef ref;
  final BuildContext rootContext;

  const _OptionsSheet({
    required this.ft,
    required this.notifier,
    required this.ref,
    required this.rootContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final isPaused = ft.status == FutureStatus.paused;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const Gap(16),
          Text(
            ft.title.isNotEmpty ? ft.title : 'Scheduled Transaction',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          const Gap(16),
          _OptionTile(
            icon: Icons.check_circle_rounded,
            label: 'Mark as Done',
            color: context.appIncome,
            onTap: () async {
              Navigator.of(context).pop();
              // Small delay to let the bottom sheet finish dismissing
              await Future.delayed(const Duration(milliseconds: 150));
              if (!rootContext.mounted) return;
              final result = await showDialog<({double amount, DateTime date})>(
                context: rootContext,
                useRootNavigator: true,
                barrierDismissible: true,
                builder: (_) => _MarkDoneDialog(ft: ft),
              );
              if (result != null) {
                await notifier.markDone(ft,
                    overrideAmount: result.amount, recordDate: result.date);
              }
            },
          ),
          _OptionTile(
            icon: Icons.skip_next_rounded,
            label: 'Skip This Cycle',
            color: context.appBorrowed,
            onTap: () {
              Navigator.pop(context);
              notifier.skipCycle(ft);
            },
          ),
          _OptionTile(
            icon: isPaused
                ? Icons.play_circle_rounded
                : Icons.pause_circle_rounded,
            label: isPaused ? 'Resume' : 'Pause',
            color: context.appAccent,
            onTap: () {
              Navigator.pop(context);
              if (isPaused) {
                notifier.resume(ft);
              } else {
                notifier.pause(ft);
              }
            },
          ),
          _OptionTile(
            icon: Icons.edit_rounded,
            label: 'Edit',
            color: context.appTextSecondary,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: rootContext,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddFutureTransactionSheet(existing: ft),
              );
            },
          ),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: context.appExpense,
            onTap: () {
              Navigator.pop(context);
              notifier.delete(ft.id);
            },
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label,
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        onTap: onTap,
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const Gap(5),
              Text(label,
                  style: GoogleFonts.dmSans(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_rounded, size: 60, color: context.appTextMuted),
            const Gap(16),
            Text('No scheduled transactions',
                style: GoogleFonts.dmSans(
                    color: context.appTextSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const Gap(6),
            Text('Tap Schedule to add recurring or future transactions',
                style:
                    GoogleFonts.dmSans(color: context.appTextMuted, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
}