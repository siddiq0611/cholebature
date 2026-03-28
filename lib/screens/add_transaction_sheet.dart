import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  /// Pass an existing transaction to edit it instead of creating a new one.
  final Transaction? existing;

  const AddTransactionSheet({super.key, this.existing});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.food;
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _uuid = Uuid();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final tx = widget.existing!;
      _titleCtrl.text = tx.title;
      _amountCtrl.text = tx.amount.toStringAsFixed(2);
      _noteCtrl.text = tx.note ?? '';
      _type = tx.type;
      _category = tx.category;
      _date = tx.date;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final rawTitle = _titleCtrl.text.trim();
    final raw = _amountCtrl.text.trim();

    if (rawTitle.isEmpty) {
      _showError('Please enter a title');
      return;
    }
    if (raw.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }

    // Confirm update
    if (_isEditing) {
      final confirmed = await _confirmDialog('Update Transaction',
          'Are you sure you want to update this transaction?');
      if (!confirmed) return;
    }

    setState(() => _saving = true);

    final tx = Transaction(
      id: _isEditing ? widget.existing!.id : _uuid.v4(),
      title: rawTitle,
      amount: amount,
      category: _category,
      type: _type,
      date: _date,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    final notifier = ref.read(transactionListProvider.notifier);
    if (_isEditing) {
      await notifier.update(tx);
    } else {
      await notifier.add(tx);
    }

    if (mounted) Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: context.appExpense,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.appSurfaceElevated,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w700)),
            content: Text(message,
                style: GoogleFonts.dmSans(color: context.appTextSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: GoogleFonts.dmSans(
                        color: context.appTextSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Confirm',
                    style: GoogleFonts.dmSans(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // KEY FIX: Use SingleChildScrollView + keyboard padding properly
    // viewInsets.bottom gives keyboard height; we add it as bottom padding
    // inside the scroll view so content scrolls above keyboard naturally.
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // Limit max height to avoid full-screen sheet on large phones
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle — outside scroll so it stays visible
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Scrollable content — this handles keyboard overflow correctly
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + keyboardHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Edit Transaction' : 'Add Transaction',
                    style: GoogleFonts.dmSans(
                      color: context.appTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Gap(20),

                  // ── Type toggle (3 options) ──
                  _TypeToggle(
                    selected: _type,
                    onChanged: (t) {
                      setState(() {
                        _type = t;
                        _category = _defaultCategoryFor(t);
                      });
                    },
                  ),
                  const Gap(16),

                  // ── Title ──
                  TextField(
                    controller: _titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title_rounded,
                          color: context.appTextMuted, size: 18),
                    ),
                  ),
                  const Gap(12),

                  // ── Amount ──
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    style: GoogleFonts.dmSans(
                      color: context.appTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      prefixIcon: Icon(Icons.currency_rupee_rounded,
                          color: context.appTextMuted, size: 18),
                    ),
                  ),
                  const Gap(12),

                  // ── Category ──
                  _CategoryPicker(
                    selected: _category,
                    type: _type,
                    onChanged: (c) => setState(() => _category = c),
                  ),
                  const Gap(12),

                  // ── Date ──
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: context.appTextMuted, size: 18),
                          const Gap(10),
                          Text(
                            '${_date.day}/${_date.month}/${_date.year}',
                            style: GoogleFonts.dmSans(
                              color: context.appTextPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: context.appTextMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const Gap(12),

                  // ── Note ──
                  TextField(
                    controller: _noteCtrl,
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary, fontSize: 14),
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: Icon(Icons.note_rounded,
                          color: context.appTextMuted, size: 18),
                    ),
                  ),
                  const Gap(24),

                  // ── Save button ──
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
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEditing
                              ? 'Update Transaction'
                              : 'Save Transaction'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TransactionCategory _defaultCategoryFor(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return TransactionCategory.food;
      case TransactionType.income:
        return TransactionCategory.salary;
      case TransactionType.borrowed:
        return TransactionCategory.borrowed;
    }
  }
}

// ─── Type Toggle (Expense / Income / Borrowed) ─────────────────────────────────
class _TypeToggle extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          _toggleItem(
              context, TransactionType.expense, 'Expense', context.appExpense),
          _toggleItem(
              context, TransactionType.income, 'Income', context.appIncome),
          _toggleItem(context, TransactionType.borrowed, 'Borrowed',
              context.appBorrowed),
        ],
      ),
    );
  }

  Widget _toggleItem(BuildContext context, TransactionType type, String label,
      Color color) {
    final isSelected = selected == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: isSelected ? color : context.appTextMuted,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Category Picker ───────────────────────────────────────────────────────────
class _CategoryPicker extends StatelessWidget {
  final TransactionCategory selected;
  final TransactionType type;
  final ValueChanged<TransactionCategory> onChanged;

  const _CategoryPicker({
    required this.selected,
    required this.type,
    required this.onChanged,
  });

  List<TransactionCategory> get _categories {
    switch (type) {
      case TransactionType.expense:
        return [
          TransactionCategory.food,
          TransactionCategory.travel,
          TransactionCategory.essentials,
          TransactionCategory.shop,
          TransactionCategory.home,
          TransactionCategory.health,
          TransactionCategory.work,
          TransactionCategory.misc,
        ];
      case TransactionType.income:
        return [
          TransactionCategory.salary,
          TransactionCategory.cashback,
          TransactionCategory.gifts,
          TransactionCategory.otherIncome,
        ];
      case TransactionType.borrowed:
        return [TransactionCategory.borrowed];
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
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
          children: cats.map((c) {
            final info = categoryInfoMap[c]!;
            final isSelected = selected == c;
            return GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? info.color.withValues(alpha: 0.18)
                      : context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? info.color : context.appBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(info.icon,
                        color:
                            isSelected ? info.color : context.appTextMuted,
                        size: 14),
                    const Gap(5),
                    Text(
                      info.label,
                      style: GoogleFonts.dmSans(
                        color: isSelected
                            ? info.color
                            : context.appTextSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}