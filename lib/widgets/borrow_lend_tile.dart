// Settlement logic:
// - Borrow entry (I owe someone): marking settled creates an EXPENSE transaction
// - Lend entry (owed to me): marking settled creates an INCOME transaction
//
// Settled cards:
// - Show NO action buttons (no "Reopen")
// - Tapping opens a read-only detail bottom sheet
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/borrow_lend_model.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'category_icon.dart';

class BorrowLendTile extends ConsumerWidget {
  final BorrowLendEntry entry;
  final int index;
  final VoidCallback onChanged;

  const BorrowLendTile({
    super.key,
    required this.entry,
    required this.index,
    required this.onChanged,
  });

  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = entry.transaction;
    final color =
        entry.isBorrowed ? context.appBorrowed : context.appLend;
    final prefix = entry.isBorrowed ? '~' : '+';
    final isSettled = entry.settlementStatus == SettlementStatus.settled;

    Color statusColor;
    switch (entry.settlementStatus) {
      case SettlementStatus.settled:
        statusColor = context.appIncome;
        break;
      case SettlementStatus.partial:
        statusColor = context.appBorrowed;
        break;
      case SettlementStatus.open:
        statusColor = color;
        break;
    }

    return Dismissible(
      key: ValueKey('blt_${tx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: context.appExpense.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: context.appExpense, size: 24),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.appSurfaceElevated,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('Delete Entry',
                style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w600)),
            content: Text(
                'Delete this ${entry.isBorrowed ? 'borrow' : 'lend'} entry?',
                style:
                    GoogleFonts.dmSans(color: context.appTextSecondary)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: GoogleFonts.dmSans(
                          color: context.appTextSecondary))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Delete',
                      style: GoogleFonts.dmSans(
                          color: context.appExpense,
                          fontWeight: FontWeight.w600))),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await ref
            .read(transactionListProvider.notifier)
            .delete(tx.id);
        onChanged();
      },
      child: GestureDetector(
        // Tapping always opens detail; settled cards only show details.
        // Open/partial cards show the action sheet.
        onTap: () {
          if (isSettled) {
            _showDetailSheet(context);
          } else {
            _showActionSheet(context, ref);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appSurfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSettled
                  ? context.appIncome.withValues(alpha: 0.25)
                  : color.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Main row ────────────────────────────────────────────────
              Row(
                children: [
                  CategoryIcon(
                    category: tx.category,
                    customCategoryId: tx.customCategoryId,
                    size: 42,
                    iconSize: 18,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.personName.isNotEmpty
                              ? entry.personName
                              : (entry.isBorrowed ? 'Borrowed' : 'Lent'),
                          style: GoogleFonts.dmSans(
                            color: context.appTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.cleanNote.isNotEmpty) ...[
                          const Gap(2),
                          Text(entry.cleanNote,
                              style: GoogleFonts.dmSans(
                                  color: context.appTextMuted,
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const Gap(3),
                        Row(
                          children: [
                            Text(formatDate(tx.date),
                                style: GoogleFonts.dmSans(
                                    color: context.appTextMuted,
                                    fontSize: 11)),
                            const Gap(8),
                            Text(
                              entry.directionLabel,
                              style: GoogleFonts.dmSans(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount + status badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$prefix${formatCompact(tx.amount)}',
                        style: GoogleFonts.dmSans(
                          color: isSettled
                              ? context.appTextMuted
                              : color,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: isSettled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const Gap(4),
                      _StatusBadge(
                          label: entry.statusLabel, color: statusColor),
                      // Small hint for settled entries
                      if (isSettled) ...[
                        const Gap(4),
                        Text(
                          'Tap for details',
                          style: GoogleFonts.dmSans(
                              color: context.appTextMuted, fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // ── Partial progress bar ─────────────────────────────────────
              if (entry.settlementStatus == SettlementStatus.partial) ...[
                const Gap(10),
                _OutstandingBar(entry: entry),
              ],

              // ── Action buttons — only for open/partial entries ───────────
              if (!isSettled) ...[
                const Gap(10),
                Row(
                  children: [
                    Expanded(
                      child: _TileButton(
                        label: 'Mark Settled',
                        icon: Icons.check_circle_outline_rounded,
                        color: context.appIncome,
                        onTap: () => _markFullySettled(context, ref),
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: _TileButton(
                        label: 'Partial',
                        icon: Icons.percent_rounded,
                        color: context.appBorrowed,
                        onTap: () => _markPartial(context, ref),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 40).ms)
        .slideX(
            begin: -0.04,
            end: 0,
            duration: 300.ms,
            delay: (index * 40).ms);
  }

  // ── Detail sheet (settled entries) ────────────────────────────────────────

  void _showDetailSheet(BuildContext context) {
    final tx = entry.transaction;
    final prefix = entry.isBorrowed ? '~' : '+';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
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
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Gap(16),
            // Header row
            Row(
              children: [
                CategoryIcon(
                  category: tx.category,
                  customCategoryId: tx.customCategoryId,
                  size: 42,
                  iconSize: 18,
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.personName.isNotEmpty
                            ? entry.personName
                            : (entry.isBorrowed ? 'Borrowed' : 'Lent'),
                        style: GoogleFonts.dmSans(
                          color: context.appTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(2),
                      _StatusBadge(
                        label: entry.statusLabel,
                        color: context.appIncome,
                      ),
                    ],
                  ),
                ),
                Text(
                  '$prefix${formatCompact(tx.amount)}',
                  style: GoogleFonts.dmSans(
                    color: context.appTextMuted,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
            const Gap(20),
            // Details
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: formatDate(tx.date),
            ),
            const Gap(12),
            _DetailRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Direction',
              value: entry.directionLabel,
            ),
            const Gap(12),
            _DetailRow(
              icon: Icons.check_circle_rounded,
              label: 'Settled amount',
              value: formatCompact(entry.settledAmount),
              valueColor: context.appIncome,
            ),
            if (entry.cleanNote.isNotEmpty) ...[
              const Gap(12),
              _DetailRow(
                icon: Icons.note_rounded,
                label: 'Note',
                value: entry.cleanNote,
              ),
            ],
            const Gap(24),
            // Close button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appTextSecondary,
                  side: BorderSide(color: context.appBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Close',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action sheet (open/partial entries) ──────────────────────────────────

  void _showActionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(entry: entry, ref: ref, onChanged: onChanged),
    );
  }

  // ── Settlement logic ──────────────────────────────────────────────────────

  Future<void> _markFullySettled(
      BuildContext context, WidgetRef ref) async {
    await _addSettlementTransaction(
        ref, entry.outstandingAmount, 'Full repayment');

    final updated = entry.transaction.copyWith(
      note: BorrowLendEntry.settledNote(entry.cleanNote),
    );
    await ref.read(transactionListProvider.notifier).update(updated);
    onChanged();
  }

  Future<void> _markPartial(
      BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurfaceElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Partial Settlement',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Outstanding: ${formatCurrency(entry.outstandingAmount)}',
              style: GoogleFonts.dmSans(
                  color: context.appTextSecondary, fontSize: 13),
            ),
            const Gap(12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}'))
              ],
              autofocus: true,
              style: GoogleFonts.dmSans(color: context.appTextPrimary),
              decoration: InputDecoration(
                labelText: 'Amount being settled now (₹)',
                labelStyle: GoogleFonts.dmSans(
                    color: context.appTextSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.appBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent),
              child: Text('Save',
                  style: GoogleFonts.dmSans(color: Colors.white))),
        ],
      ),
    );

    if (confirmed != true) return;

    final nowSettling = double.tryParse(ctrl.text.trim());
    if (nowSettling == null || nowSettling <= 0) return;

    final capped = nowSettling.clamp(0, entry.outstandingAmount).toDouble();
    final totalSettled = entry.settledAmount + capped;

    await _addSettlementTransaction(ref, capped, 'Partial repayment');

    if (totalSettled >= entry.amount) {
      final updated = entry.transaction.copyWith(
        note: BorrowLendEntry.settledNote(entry.cleanNote),
      );
      await ref.read(transactionListProvider.notifier).update(updated);
    } else {
      final updated = entry.transaction.copyWith(
        note: BorrowLendEntry.partialNote(totalSettled, entry.cleanNote),
      );
      await ref.read(transactionListProvider.notifier).update(updated);
    }
    onChanged();
  }

  Future<void> _addSettlementTransaction(
      WidgetRef ref, double amount, String label) async {
    final counterType = entry.isBorrowed
        ? TransactionType.expense
        : TransactionType.income;

    final counterCategory = entry.isBorrowed
        ? TransactionCategory.misc
        : TransactionCategory.otherIncome;

    final tx = Transaction(
      id: _uuid.v4(),
      title:
          '$label — ${entry.personName.isNotEmpty ? entry.personName : (entry.isBorrowed ? "Borrowed" : "Lent")}',
      amount: amount,
      category: counterCategory,
      type: counterType,
      date: DateTime.now(),
      note: 'Settlement of ${formatCurrency(entry.amount)} '
          '${entry.isBorrowed ? 'borrowed' : 'lent'}',
    );

    await ref.read(transactionListProvider.notifier).add(tx);
  }
}

// ── Action sheet for open/partial entries ──────────────────────────────────────

class _ActionSheet extends ConsumerWidget {
  final BorrowLendEntry entry;
  final WidgetRef ref;
  final VoidCallback onChanged;

  const _ActionSheet({
    required this.entry,
    required this.ref,
    required this.onChanged,
  });

  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
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
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Gap(16),
          Text(
            entry.personName.isNotEmpty
                ? entry.personName
                : (entry.isBorrowed ? 'Borrowed' : 'Lent'),
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          const Gap(4),
          Text(
            '${entry.isBorrowed ? '~' : '+'}${formatCompact(entry.amount)} · ${formatDate(entry.date)}',
            style: GoogleFonts.dmSans(
                color: context.appTextMuted, fontSize: 12),
          ),
          const Gap(16),
          _OptionTile(
            icon: Icons.check_circle_rounded,
            label: 'Mark as Fully Settled',
            color: context.appIncome,
            onTap: () async {
              Navigator.pop(context);
              await _markFullySettled(context, widgetRef);
            },
          ),
          _OptionTile(
            icon: Icons.percent_rounded,
            label: 'Record Partial Payment',
            color: context.appBorrowed,
            onTap: () async {
              Navigator.pop(context);
              await _markPartial(context, widgetRef);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _markFullySettled(BuildContext context, WidgetRef ref) async {
    await _addSettlementTransaction(
        ref, entry.outstandingAmount, 'Full repayment');
    final updated = entry.transaction.copyWith(
      note: BorrowLendEntry.settledNote(entry.cleanNote),
    );
    await ref.read(transactionListProvider.notifier).update(updated);
    onChanged();
  }

  Future<void> _markPartial(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Partial Settlement',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Outstanding: ${formatCurrency(entry.outstandingAmount)}',
              style:
                  GoogleFonts.dmSans(color: context.appTextSecondary, fontSize: 13),
            ),
            const Gap(12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}'))
              ],
              autofocus: true,
              style: GoogleFonts.dmSans(color: context.appTextPrimary),
              decoration: InputDecoration(
                labelText: 'Amount being settled now (₹)',
                labelStyle:
                    GoogleFonts.dmSans(color: context.appTextSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.appBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      GoogleFonts.dmSans(color: context.appTextSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent),
              child: Text('Save',
                  style: GoogleFonts.dmSans(color: Colors.white))),
        ],
      ),
    );

    if (confirmed != true) return;
    final nowSettling = double.tryParse(ctrl.text.trim());
    if (nowSettling == null || nowSettling <= 0) return;

    final capped = nowSettling.clamp(0, entry.outstandingAmount).toDouble();
    final totalSettled = entry.settledAmount + capped;

    await _addSettlementTransaction(ref, capped, 'Partial repayment');

    if (totalSettled >= entry.amount) {
      final updated = entry.transaction.copyWith(
        note: BorrowLendEntry.settledNote(entry.cleanNote),
      );
      await ref.read(transactionListProvider.notifier).update(updated);
    } else {
      final updated = entry.transaction.copyWith(
        note: BorrowLendEntry.partialNote(totalSettled, entry.cleanNote),
      );
      await ref.read(transactionListProvider.notifier).update(updated);
    }
    onChanged();
  }

  Future<void> _addSettlementTransaction(
      WidgetRef ref, double amount, String label) async {
    final counterType = entry.isBorrowed
        ? TransactionType.expense
        : TransactionType.income;
    final counterCategory = entry.isBorrowed
        ? TransactionCategory.misc
        : TransactionCategory.otherIncome;
    final tx = Transaction(
      id: _uuid.v4(),
      title:
          '$label — ${entry.personName.isNotEmpty ? entry.personName : (entry.isBorrowed ? "Borrowed" : "Lent")}',
      amount: amount,
      category: counterCategory,
      type: counterType,
      date: DateTime.now(),
      note: 'Settlement of ${formatCurrency(entry.amount)} '
          '${entry.isBorrowed ? 'borrowed' : 'lent'}',
    );
    await ref.read(transactionListProvider.notifier).add(tx);
  }
}

// ── Private helpers ────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38, height: 38,
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
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: context.appTextMuted, size: 16),
      const Gap(10),
      Text(label,
          style:
              GoogleFonts.dmSans(color: context.appTextSecondary, fontSize: 13)),
      const Spacer(),
      Flexible(
        child: Text(
          value,
          style: GoogleFonts.dmSans(
            color: valueColor ?? context.appTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.dmSans(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _OutstandingBar extends StatelessWidget {
  final BorrowLendEntry entry;
  const _OutstandingBar({required this.entry});

  @override
  Widget build(BuildContext context) {
    final progress = entry.amount > 0
        ? (entry.settledAmount / entry.amount).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Settled ${formatCompact(entry.settledAmount)}',
                style: GoogleFonts.dmSans(
                    color: context.appIncome,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('${formatCompact(entry.outstandingAmount)} outstanding',
                style: GoogleFonts.dmSans(
                    color: context.appBorrowed,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        const Gap(5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: context.appBorder,
            valueColor:
                AlwaysStoppedAnimation<Color>(context.appIncome),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

class _TileButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TileButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
            Icon(icon, color: color, size: 13),
            const Gap(5),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}