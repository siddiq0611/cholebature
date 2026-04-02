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
  final double lent;

  const SummaryCards({
    super.key,
    required this.income,
    required this.expense,
    required this.savings,
    required this.borrowed,
    this.lent = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Net worth = savings - what you owe + what others owe you
    // Borrowed = liability (you owe), Lent = asset (owed to you)
    final netWorth = savings - borrowed + lent;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BigCard(
                  title: 'Net Savings',
                  subtitle: income > 0
                      ? '${((savings / income) * 100).clamp(0.0, 100.0).toStringAsFixed(0)}% of income saved'
                      : 'No income recorded',
                  amount: savings,
                  progressValue: income > 0
                      ? (savings / income).clamp(0.0, 1.0)
                      : 0.0,
                  cardColor:
                      savings >= 0 ? context.appIncome : context.appExpense,
                  icon: Icons.savings_rounded,
                ),
              ),
              const Gap(10),
              Expanded(
                child: _BigCard(
                  title: 'Net Worth',
                  // Show breakdown in subtitle
                  subtitle: borrowed > 0 || lent > 0
                      ? '${lent > 0 ? '+${formatCompact(lent)} lent' : ''}${borrowed > 0 && lent > 0 ? '  ' : ''}${borrowed > 0 ? '−${formatCompact(borrowed)} owed' : ''}'
                      : 'No outstanding balances',
                  amount: netWorth,
                  progressValue: income > 0
                      ? (netWorth / income).clamp(0.0, 1.0)
                      : 0.0,
                  cardColor: netWorth >= 0
                      ? context.appAccent
                      : context.appExpense,
                  icon: Icons.account_balance_rounded,
                ),
              ),
            ],
          ),
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

        if (borrowed > 0 || lent > 0) ...[
          const Gap(10),
          Row(
            children: [
              if (borrowed > 0)
                Expanded(
                  child: _MiniCard(
                    label: 'I Owe',
                    amount: borrowed,
                    color: context.appBorrowed,
                    icon: Icons.handshake_rounded,
                  ),
                ),
              if (borrowed > 0 && lent > 0) const Gap(10),
              if (lent > 0)
                Expanded(
                  child: _MiniCard(
                    label: 'Owed to Me',
                    amount: lent,
                    color: context.appLend,
                    icon: Icons.send_rounded,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BigCard extends StatelessWidget {
  final String title, subtitle;
  final double amount, progressValue;
  final Color cardColor;
  final IconData icon;

  const _BigCard({
    required this.title, required this.subtitle,
    required this.amount, required this.progressValue,
    required this.cardColor, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor.withValues(alpha: 0.12), context.appSurface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: cardColor, size: 15),
            ),
            const Gap(8),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const Gap(10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCurrency(amount),
              style: GoogleFonts.dmSans(
                color: cardColor, fontSize: 18,
                fontWeight: FontWeight.w700, letterSpacing: -0.8,
              ),
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
          Text(subtitle,
              style: GoogleFonts.dmSans(
                  color: context.appTextMuted, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms);
  }
}

class _MiniCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _MiniCard({
    required this.label, required this.amount,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const Gap(8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500)),
              const Gap(2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatCompact(amount),
                  style: GoogleFonts.dmSans(
                      color: color, fontSize: 15,
                      fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
              ),
            ],
          ),
        ),
      ]),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 150.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 150.ms);
  }
}