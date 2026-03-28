import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/category_icon.dart';
import 'add_transaction_sheet.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = categoryInfoMap[transaction.category]!;
    final isIncome = transaction.type == TransactionType.income;
    final isBorrowed = transaction.type == TransactionType.borrowed;

    Color typeColor;
    if (isIncome) {
      typeColor = context.appIncome;
    } else if (isBorrowed) {
      typeColor = context.appBorrowed;
    } else {
      typeColor = context.appExpense;
    }

    String typeLabel;
    if (isIncome) {
      typeLabel = 'Income';
    } else if (isBorrowed) {
      typeLabel = 'Borrowed';
    } else {
      typeLabel = 'Expense';
    }

    Future<void> deleteTransaction() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.appSurfaceElevated,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Delete Transaction',
            style: GoogleFonts.dmSans(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this transaction? This cannot be undone.',
            style: GoogleFonts.dmSans(color: context.appTextSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      GoogleFonts.dmSans(color: context.appTextSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: GoogleFonts.dmSans(
                      color: context.appExpense,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        await ref
            .read(transactionListProvider.notifier)
            .delete(transaction.id);
        if (context.mounted) Navigator.pop(context);
      }
    }

    Future<void> editTransaction() async {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddTransactionSheet(existing: transaction),
      );
      if (context.mounted) Navigator.pop(context);
    }

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        title: Text(
          'Transaction Details',
          style: GoogleFonts.dmSans(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.appTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon:
                Icon(Icons.edit_rounded, color: context.appAccent, size: 22),
            onPressed: editTransaction,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: context.appExpense, size: 22),
            onPressed: deleteTransaction,
            tooltip: 'Delete',
          ),
          const Gap(8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appSurfaceElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.appBorder),
              ),
              child: Column(
                children: [
                  CategoryIcon(
                    category: transaction.category,
                    size: 64,
                    iconSize: 28,
                  ),
                  const Gap(16),
                  Text(
                    transaction.title.isNotEmpty
                        ? transaction.title
                        : info.label,
                    style: GoogleFonts.dmSans(
                      color: context.appTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    '${isIncome ? '+' : isBorrowed ? '~' : '-'}${formatCurrency(transaction.amount)}',
                    style: GoogleFonts.dmSans(
                      color: typeColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      typeLabel,
                      style: GoogleFonts.dmSans(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Gap(20),

            // ── Details ──
            _DetailSection(
              title: 'Details',
              rows: [
                _DetailRow(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value: info.label,
                  valueColor: info.color,
                ),
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: formatDate(transaction.date),
                ),
                _DetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: formatTime(transaction.date),
                ),
                if (transaction.note != null &&
                    transaction.note!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.note_rounded,
                    label: 'Note',
                    value: transaction.note!,
                  ),
              ],
            ),

            const Gap(32),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: editTransaction,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appAccent,
                      side: BorderSide(color: context.appAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: deleteTransaction,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appExpense,
                      side: BorderSide(color: context.appExpense),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailRow> rows;

  const _DetailSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
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
            title,
            style: GoogleFonts.dmSans(
              color: context.appTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(12),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: row,
              )),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.appTextMuted, size: 16),
        const Gap(10),
        Text(
          label,
          style: GoogleFonts.dmSans(
              color: context.appTextSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.dmSans(
            color: valueColor ?? context.appTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}