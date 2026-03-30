// Amount is OPTIONAL when scheduling.
// If left blank → the "Mark Done" dialog asks for it at completion time.
// If filled     → pre-filled in the "Mark Done" dialog but still editable.
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/future_transaction_model.dart';
import '../models/transaction_model.dart';
import '../providers/future_transaction_provider.dart';
import '../theme/app_theme.dart';

class AddFutureTransactionSheet extends ConsumerStatefulWidget {
  final FutureTransaction? existing;
  const AddFutureTransactionSheet({super.key, this.existing});

  @override
  ConsumerState<AddFutureTransactionSheet> createState() =>
      _AddFutureTransactionSheetState();
}

class _AddFutureTransactionSheetState
    extends ConsumerState<AddFutureTransactionSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(); // optional
  final _noteCtrl = TextEditingController();

  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.food;
  RecurrenceType _recurrence = RecurrenceType.once;
  List<int> _recurrenceDays = [];
  DateTime _nextDue = DateTime.now().add(const Duration(days: 1));
  List<int> _reminderOffsets = [0];
  bool _saving = false;

  static const _uuid = Uuid();
  bool get _isEditing => widget.existing != null;

  static const _availableOffsets = [
    (label: 'At due time', minutes: 0),
    (label: '15 min before', minutes: 15),
    (label: '30 min before', minutes: 30),
    (label: '1 hour before', minutes: 60),
    (label: '2 hours before', minutes: 120),
    (label: '3 hours before', minutes: 180),
    (label: '1 day before', minutes: 1440),
    (label: '2 days before', minutes: 2880),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final ft = widget.existing!;
      _titleCtrl.text = ft.title;
      if (ft.amount > 0) {
        _amountCtrl.text = ft.amount.toStringAsFixed(2);
      }
      _noteCtrl.text = ft.note ?? '';
      _type = ft.type == TransactionType.income
          ? TransactionType.income
          : TransactionType.expense;
      _category = ft.category;
      _recurrence = ft.recurrence;
      _recurrenceDays = List.from(ft.recurrenceDays);
      _nextDue = ft.nextDue;
      _reminderOffsets = List.from(ft.reminderOffsets);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  TransactionCategory _defaultCategoryFor(TransactionType type) =>
      type == TransactionType.income
          ? TransactionCategory.salary
          : TransactionCategory.food;

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDue,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextDue),
    );
    if (!mounted) return;
    setState(() {
      _nextDue = DateTime(
        picked.year, picked.month, picked.day,
        time?.hour ?? _nextDue.hour,
        time?.minute ?? _nextDue.minute,
      );
    });
  }

  Future<void> _save() async {
    final rawTitle = _titleCtrl.text.trim();
    if (rawTitle.isEmpty) { _showError('Please enter a title'); return; }
    if (_recurrence == RecurrenceType.weekly && _recurrenceDays.isEmpty) {
      _showError('Please select at least one day for weekly recurrence');
      return;
    }

    // Amount is optional — store 0 if blank (means "ask at mark-done time")
    final raw = _amountCtrl.text.trim();
    double amount = 0;
    if (raw.isNotEmpty) {
      final parsed = double.tryParse(raw);
      if (parsed == null || parsed < 0) {
        _showError('Enter a valid amount or leave blank');
        return;
      }
      amount = parsed;
    }

    setState(() => _saving = true);

    try {
      final ft = FutureTransaction(
        id: _isEditing ? widget.existing!.id : _uuid.v4(),
        title: rawTitle,
        amount: amount,
        category: _category,
        type: _type,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        recurrence: _recurrence,
        recurrenceDays: _recurrenceDays,
        nextDue: _nextDue,
        reminderOffsets: _reminderOffsets.isEmpty ? [0] : _reminderOffsets,
        createdAt: _isEditing ? widget.existing!.createdAt : DateTime.now(),
      );

      final notifier = ref.read(futureTransactionProvider.notifier);
      if (_isEditing) {
        await notifier.update(ft);
      } else {
        await notifier.add(ft);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Failed to save: ${e.toString()}');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
      backgroundColor: context.appExpense,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final amountIsBlank = _amountCtrl.text.trim().isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + keyboardHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Edit Scheduled Transaction' : 'Schedule Transaction',
                    style: GoogleFonts.dmSans(
                      color: context.appTextPrimary, fontSize: 20,
                      fontWeight: FontWeight.w700, letterSpacing: -0.5,
                    ),
                  ),
                  const Gap(20),

                  // ── Type ─────────────────────────────────────────────────
                  _TypeToggle(
                    selected: _type,
                    onChanged: (t) => setState(() {
                      _type = t;
                      _category = _defaultCategoryFor(t);
                    }),
                  ),
                  const Gap(16),

                  // ── Title ────────────────────────────────────────────────
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

                  // ── Amount (optional) ────────────────────────────────────
                  TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.dmSans(
                      color: context.appTextPrimary, fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)  — optional',
                      hintText: 'Leave blank to enter when marking done',
                      hintStyle: GoogleFonts.dmSans(
                          color: context.appTextMuted, fontSize: 12),
                      prefixIcon: Icon(Icons.currency_rupee_rounded,
                          color: context.appTextMuted, size: 18),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            amountIsBlank ? 'Variable' : 'Fixed',
                            style: GoogleFonts.dmSans(
                              color: amountIsBlank
                                  ? context.appBorrowed
                                  : context.appIncome,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: (amountIsBlank
                                  ? context.appBorrowed
                                  : context.appIncome)
                              .withValues(alpha: 0.12),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Text(
                      amountIsBlank
                          ? 'You\'ll be asked to enter the amount when marking as done'
                          : 'Amount pre-filled at mark-done but can be changed',
                      style: GoogleFonts.dmSans(
                          color: context.appTextMuted, fontSize: 11),
                    ),
                  ),
                  const Gap(12),

                  // ── Category ─────────────────────────────────────────────
                  _CategoryPicker(
                    selected: _category, type: _type,
                    onChanged: (c) => setState(() => _category = c),
                  ),
                  const Gap(12),

                  // ── Recurrence ───────────────────────────────────────────
                  _SectionLabel(label: 'Recurrence'),
                  const Gap(8),
                  _RecurrencePicker(
                    selected: _recurrence,
                    onChanged: (r) => setState(() => _recurrence = r),
                  ),
                  const Gap(12),

                  if (_recurrence == RecurrenceType.weekly) ...[
                    _SectionLabel(label: 'Days of Week'),
                    const Gap(8),
                    _WeekdayPicker(
                      selected: _recurrenceDays,
                      onChanged: (d) => setState(() => _recurrenceDays = d),
                    ),
                    const Gap(12),
                  ],

                  // ── Due date/time ────────────────────────────────────────
                  _SectionLabel(label: 'Next Due Date & Time'),
                  const Gap(8),
                  GestureDetector(
                    onTap: _pickDueDate,
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
                            '${_nextDue.day}/${_nextDue.month}/${_nextDue.year}  '
                            '${_nextDue.hour.toString().padLeft(2, '0')}:${_nextDue.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.dmSans(
                                color: context.appTextPrimary, fontSize: 14),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: context.appTextMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const Gap(12),

                  // ── Reminders ────────────────────────────────────────────
                  _SectionLabel(label: 'Reminders'),
                  const Gap(8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _availableOffsets.map((o) {
                      final isSel = _reminderOffsets.contains(o.minutes);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSel) {
                            _reminderOffsets.remove(o.minutes);
                          } else {
                            _reminderOffsets.add(o.minutes);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSel
                                ? context.appAccent.withValues(alpha: 0.18)
                                : context.appSurfaceElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel ? context.appAccent : context.appBorder,
                              width: isSel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(o.label,
                              style: GoogleFonts.dmSans(
                                color: isSel
                                    ? context.appAccent
                                    : context.appTextSecondary,
                                fontSize: 12,
                                fontWeight: isSel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const Gap(12),

                  // ── Note ─────────────────────────────────────────────────
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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: context.appAccent),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing ? 'Update Schedule' : 'Save Schedule'),
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
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: GoogleFonts.dmSans(
          color: context.appTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500));
}

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
      child: Row(children: [
        _item(context, TransactionType.expense, 'Expense', context.appExpense),
        _item(context, TransactionType.income, 'Income', context.appIncome),
      ]),
    );
  }

  Widget _item(BuildContext ctx, TransactionType type, String label, Color color) {
    final isSel = selected == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  color: isSel ? color : ctx.appTextMuted,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _RecurrencePicker extends StatelessWidget {
  final RecurrenceType selected;
  final ValueChanged<RecurrenceType> onChanged;
  const _RecurrencePicker({required this.selected, required this.onChanged});

  static const _options = [
    (type: RecurrenceType.once, label: 'One-time', icon: Icons.looks_one_rounded),
    (type: RecurrenceType.daily, label: 'Daily', icon: Icons.today_rounded),
    (type: RecurrenceType.weekly, label: 'Weekly', icon: Icons.view_week_rounded),
    (type: RecurrenceType.monthly, label: 'Monthly', icon: Icons.calendar_month_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((o) {
        final isSel = selected == o.type;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(o.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSel
                    ? context.appAccent.withValues(alpha: 0.15)
                    : context.appSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSel ? context.appAccent : context.appBorder,
                    width: isSel ? 1.5 : 1),
              ),
              child: Column(children: [
                Icon(o.icon, size: 16,
                    color: isSel ? context.appAccent : context.appTextMuted),
                const Gap(4),
                Text(o.label,
                    style: GoogleFonts.dmSans(
                        color: isSel ? context.appAccent : context.appTextSecondary,
                        fontSize: 10,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  const _WeekdayPicker({required this.selected, required this.onChanged});

  static const _days = [
    (day: 1, label: 'M'), (day: 2, label: 'T'), (day: 3, label: 'W'),
    (day: 4, label: 'T'), (day: 5, label: 'F'), (day: 6, label: 'S'),
    (day: 7, label: 'S'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _days.map((d) {
        final isSel = selected.contains(d.day);
        return Expanded(
          child: GestureDetector(
            onTap: () {
              final updated = List<int>.from(selected);
              if (isSel) { updated.remove(d.day); } else {
                updated.add(d.day); updated.sort();
              }
              onChanged(updated);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 36,
              decoration: BoxDecoration(
                color: isSel ? context.appAccent : context.appSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSel ? context.appAccent : context.appBorder),
              ),
              child: Center(
                child: Text(d.label,
                    style: GoogleFonts.dmSans(
                        color: isSel ? Colors.white : context.appTextSecondary,
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final TransactionCategory selected;
  final TransactionType type;
  final ValueChanged<TransactionCategory> onChanged;
  const _CategoryPicker(
      {required this.selected, required this.type, required this.onChanged});

  List<TransactionCategory> get _cats {
    if (type == TransactionType.income) {
      return [
        TransactionCategory.salary, TransactionCategory.cashback,
        TransactionCategory.gifts, TransactionCategory.otherIncome,
      ];
    }
    return [
      TransactionCategory.food, TransactionCategory.travel,
      TransactionCategory.essentials, TransactionCategory.shop,
      TransactionCategory.home, TransactionCategory.health,
      TransactionCategory.work, TransactionCategory.misc,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category',
            style: GoogleFonts.dmSans(
                color: context.appTextSecondary, fontSize: 12,
                fontWeight: FontWeight.w500)),
        const Gap(8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _cats.map((c) {
            final info = categoryInfoMap[c]!;
            final isSel = selected == c;
            return GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isSel
                      ? info.color.withValues(alpha: 0.18)
                      : context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSel ? info.color : context.appBorder,
                      width: isSel ? 1.5 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(info.icon,
                      color: isSel ? info.color : context.appTextMuted,
                      size: 14),
                  const Gap(5),
                  Text(info.label,
                      style: GoogleFonts.dmSans(
                          color: isSel ? info.color : context.appTextSecondary,
                          fontSize: 12,
                          fontWeight:
                              isSel ? FontWeight.w600 : FontWeight.w400)),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}