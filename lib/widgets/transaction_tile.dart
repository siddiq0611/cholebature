import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../screens/transaction_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'category_icon.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onDelete;
  final int index;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onDelete,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final info = categoryInfoMap[transaction.category]!;
    final isIncome = transaction.type == TransactionType.income;
    final isBorrowed = transaction.type == TransactionType.borrowed;

    Color amountColor;
    String amountPrefix;
    if (isIncome) {
      amountColor = context.appIncome;
      amountPrefix = '+';
    } else if (isBorrowed) {
      amountColor = context.appBorrowed;
      amountPrefix = '~';
    } else {
      amountColor = context.appExpense;
      amountPrefix = '-';
    }

    String typeLabel;
    if (isIncome) {
      typeLabel = 'Income';
    } else if (isBorrowed) {
      typeLabel = 'Borrowed';
    } else {
      typeLabel = 'Expense';
    }

    return Dismissible(
      key: ValueKey(transaction.id),
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
            title: Text(
              'Delete Transaction',
              style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to delete this transaction?',
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
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TransactionDetailScreen(transaction: transaction),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appSurfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              CategoryIcon(
                category: transaction.category,
                customCategoryId: transaction.customCategoryId,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title.isNotEmpty
                          ? transaction.title
                          : info.label,
                      style: GoogleFonts.dmSans(
                        color: context.appTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (transaction.note != null &&
                        transaction.note!.isNotEmpty) ...[
                      const Gap(2),
                      Text(
                        transaction.note!,
                        style: GoogleFonts.dmSans(
                            color: context.appTextMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Gap(3),
                    Text(
                      formatDayMonth(transaction.date),
                      style: GoogleFonts.dmSans(
                          color: context.appTextMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$amountPrefix${formatCompact(transaction.amount)}',
                    style: GoogleFonts.dmSans(
                      color: amountColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeLabel,
                      style: GoogleFonts.dmSans(
                        color: amountColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 30).ms)
        .slideX(
            begin: -0.05,
            end: 0,
            duration: 300.ms,
            delay: (index * 30).ms);
  }
}