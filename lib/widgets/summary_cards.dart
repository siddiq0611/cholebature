import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class SummaryCards extends StatelessWidget {
  final double income;
  final double expense;
  final double savings;
  final double borrowed;

  const SummaryCards({
    super.key,
    required this.income,
    required this.expense,
    required this.savings,
    required this.borrowed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Net Savings — green/red based on positive/negative
            Expanded(
              child: _BigCard(
                title: 'Net Savings',
                subtitle: income > 0
                    ? '${((savings / income) * 100).clamp(0.0, 100.0).toStringAsFixed(0)}% of income saved'
                    : 'No income recorded',
                amount: savings,
                progressValue:
                    income > 0 ? (savings / income).clamp(0.0, 1.0) : 0.0,
                cardColor: savings >= 0
                    ? context.appIncome
                    : context.appExpense,
                icon: Icons.savings_rounded,
              ),
            ),
            const Gap(10),
            // Net Worth — always blue; shows savings minus borrowed
            Expanded(
              child: _BigCard(
                title: 'Net Worth',
                subtitle: borrowed > 0
                    ? '−${formatCompact(borrowed)} borrowed'
                    : 'No liabilities',
                amount: savings - borrowed,
                progressValue: income > 0
                    ? ((savings - borrowed) / income).clamp(0.0, 1.0)
                    : 0.0,
                cardColor: context.appAccent, // always blue
                icon: Icons.account_balance_rounded,
              ),
            ),
          ],
        ),
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: 'Income',
                amount: income,
                color: context.appIncome,
                icon: Icons.arrow_downward_rounded,
              ),
            ),
            const Gap(10),
            Expanded(
              child: _MiniCard(
                label: 'Expenses',
                amount: expense,
                color: context.appExpense,
                icon: Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ),
        if (borrowed > 0) ...[
          const Gap(10),
          _MiniCard(
            label: 'Borrowed',
            amount: borrowed,
            color: context.appBorrowed,
            icon: Icons.handshake_rounded,
            fullWidth: true,
          ),
        ],
      ],
    );
  }
}

class _BigCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final double progressValue;
  final Color cardColor;
  final IconData icon;

  const _BigCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.progressValue,
    required this.cardColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor.withValues(alpha: 0.12),
            context.appSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardColor.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: cardColor, size: 15),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: context.appTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(10),
          Text(
            formatCurrency(amount),
            style: GoogleFonts.dmSans(
              color: cardColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
          const Gap(10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue.abs(),
              backgroundColor: context.appBorder,
              valueColor: AlwaysStoppedAnimation<Color>(cardColor),
              minHeight: 4,
            ),
          ),
          const Gap(6),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              color: context.appTextMuted,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms);
  }
}

class _MiniCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool fullWidth;

  const _MiniCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
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
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: context.appTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(2),
                Text(
                  formatCompact(amount),
                  style: GoogleFonts.dmSans(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return card
        .animate()
        .fadeIn(duration: 400.ms, delay: 150.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 150.ms);
  }
}