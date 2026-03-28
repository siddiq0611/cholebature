import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetListProvider);
    final resultsAsync = ref.watch(budgetResultsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        title: Text(
          'Budgets',
          style: GoogleFonts.dmSans(
            color: context.appTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_rounded, color: context.appTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          GestureDetector(
            onTap: () => _showAddBudgetSheet(context, ref),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: context.appAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded,
                      color: Colors.white, size: 16),
                  const Gap(4),
                  Text(
                    'Add Budget',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: budgetsAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: context.appAccent)),
        error: (e, _) =>
            Center(child: Text('Error: $e')),
        data: (budgets) {
          if (budgets.isEmpty) {
            return _EmptyBudgetState(
                onAdd: () => _showAddBudgetSheet(context, ref));
          }

          return resultsAsync.when(
            loading: () => Center(
                child: CircularProgressIndicator(color: context.appAccent)),
            error: (e, _) =>
                Center(child: Text('Error: $e')),
            data: (results) {
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                itemCount: results.length,
                separatorBuilder: (_, __) => const Gap(12),
                itemBuilder: (ctx, i) => _BudgetCard(
                  result: results[i],
                  index: i,
                  onDelete: () => ref
                      .read(budgetListProvider.notifier)
                      .delete(results[i].budget.id),
                  onEdit: () =>
                      _showAddBudgetSheet(context, ref,
                          existing: results[i].budget),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddBudgetSheet(BuildContext context, WidgetRef ref,
      {Budget? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AddBudgetSheet(existing: existing, uuid: _uuid),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetResult result;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BudgetCard({
    required this.result,
    required this.index,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final budget = result.budget;
    final isExceeded = result.isExceeded;
    final barColor = isExceeded
        ? context.appExpense
        : result.progress > 0.8
            ? context.appBorrowed
            : context.appIncome;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExceeded
              ? context.appExpense.withValues(alpha: 0.4)
              : context.appBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.appAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  budget.label,
                  style: GoogleFonts.dmSans(
                    color: context.appAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_rounded,
                    color: context.appTextMuted, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Gap(8),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded,
                    color: context.appExpense, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Gap(12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent',
                    style: GoogleFonts.dmSans(
                      color: context.appTextMuted,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    formatCompact(result.spent),
                    style: GoogleFonts.dmSans(
                      color: isExceeded
                          ? context.appExpense
                          : context.appTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              const Gap(8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ ${formatCompact(budget.amount)}',
                  style: GoogleFonts.dmSans(
                    color: context.appTextMuted,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              if (isExceeded)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.appExpense.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${formatCompact(result.spent - budget.amount)} over',
                    style: GoogleFonts.dmSans(
                      color: context.appExpense,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: GoogleFonts.dmSans(
                        color: context.appTextMuted,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      formatCompact(result.remaining),
                      style: GoogleFonts.dmSans(
                        color: context.appIncome,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Gap(10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: result.progress,
              backgroundColor: context.appBorder,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
          const Gap(10),
          Row(
            children: [
              Icon(
                result.vsLastPeriodPct != null && result.vsLastPeriodPct! > 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 13,
                color: context.appTextMuted,
              ),
              const Gap(4),
              Expanded(
                child: Text(
                  result.insightText,
                  style: GoogleFonts.dmSans(
                    color: context.appTextMuted,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, delay: (index * 60).ms)
        .slideY(begin: 0.06, end: 0, duration: 350.ms, delay: (index * 60).ms);
  }
}

class _AddBudgetSheet extends ConsumerStatefulWidget {
  final Budget? existing;
  final Uuid uuid;

  const _AddBudgetSheet({this.existing, required this.uuid});

  @override
  ConsumerState<_AddBudgetSheet> createState() =>
      _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<_AddBudgetSheet> {
  final _amountCtrl = TextEditingController();
  BudgetPeriod _period = BudgetPeriod.monthly;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _amountCtrl.text =
          widget.existing!.amount.toStringAsFixed(0);
      _period = widget.existing!.period;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a valid amount',
            style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: context.appExpense,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);

    final budget = Budget(
      id: _isEditing ? widget.existing!.id : widget.uuid.v4(),
      period: _period,
      amount: amount,
    );

    await ref.read(budgetListProvider.notifier).upsert(budget);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + keyboardHeight),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),
          Text(
            _isEditing ? 'Edit Budget' : 'Add Budget',
            style: GoogleFonts.dmSans(
              color: context.appTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(20),

          // Period selector
          Text(
            'Period',
            style: GoogleFonts.dmSans(
              color: context.appTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BudgetPeriod.values.map((p) {
              final isSel = _period == p;
              return GestureDetector(
                onTap: () => setState(() => _period = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel
                        ? context.appAccent.withValues(alpha: 0.15)
                        : context.appSurfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isSel ? context.appAccent : context.appBorder,
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _budgetPeriodLabel(p),
                    style: GoogleFonts.dmSans(
                      color: isSel
                          ? context.appAccent
                          : context.appTextSecondary,
                      fontSize: 13,
                      fontWeight:
                          isSel ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Gap(16),

          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            autofocus: true,
            style: GoogleFonts.dmSans(
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Budget Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee_rounded,
                  color: context.appTextMuted, size: 18),
            ),
          ),
          const Gap(24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Update Budget' : 'Save Budget'),
            ),
          ),
        ],
      ),
    );
  }

  String _budgetPeriodLabel(BudgetPeriod p) {
    switch (p) {
      case BudgetPeriod.dailyWeekday:
        return 'Weekdays';
      case BudgetPeriod.dailyWeekend:
        return 'Weekends';
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
    }
  }
}

class _EmptyBudgetState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBudgetState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_rounded,
              size: 60, color: context.appTextMuted),
          const Gap(16),
          Text(
            'No budgets set',
            style: GoogleFonts.dmSans(
              color: context.appTextSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Text(
            'Set daily, weekly or monthly spending limits',
            style: GoogleFonts.dmSans(
              color: context.appTextMuted,
              fontSize: 13,
            ),
          ),
          const Gap(24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Budget'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}