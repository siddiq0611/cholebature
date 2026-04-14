import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/custom_category_model.dart';
import '../models/transaction_model.dart';
import '../providers/custom_category_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';

// ─── One row of data ──────────────────────────────────────────────────────────

class _RowData {
  final String id;
  final TextEditingController titleCtrl;
  final TextEditingController amountCtrl;
  TransactionType type;
  TransactionCategory category;
  String? customCategoryId;
  DateTime date;

  _RowData({required this.id, required DateTime initialDate})
      : titleCtrl = TextEditingController(),
        amountCtrl = TextEditingController(),
        type = TransactionType.expense,
        category = TransactionCategory.food,
        customCategoryId = null,
        date = initialDate;

  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
  }

  bool get isValid {
    final title = titleCtrl.text.trim();
    final amt = double.tryParse(amountCtrl.text.trim());
    return title.isNotEmpty && amt != null && amt > 0;
  }

  String? get error {
    if (titleCtrl.text.trim().isEmpty) return 'Title missing';
    final amt = double.tryParse(amountCtrl.text.trim());
    if (amt == null || amt <= 0) return 'Invalid amount';
    return null;
  }
}

// ─── Sheet widget ─────────────────────────────────────────────────────────────

class QuickLogSheet extends ConsumerStatefulWidget {
  const QuickLogSheet({super.key});

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  static const _uuid = Uuid();

  final List<_RowData> _rows = [];
  bool _saving = false;
  String? _globalError;
  // Track which rows have been validated (show errors only after first save attempt)
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _addRow(); // Start with one empty row
  }

  @override
  void dispose() {
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(_RowData(id: _uuid.v4(), initialDate: DateTime.now()));
    });
  }

  void _removeRow(int index) {
    _rows[index].dispose();
    setState(() => _rows.removeAt(index));
  }

  Future<void> _saveAll() async {
    setState(() { _attempted = true; _globalError = null; });

    // Validate
    final invalid = _rows.where((r) => !r.isValid).toList();
    if (invalid.isNotEmpty) {
      setState(() => _globalError =
          'Fix ${invalid.length} row${invalid.length > 1 ? 's' : ''} before saving.');
      return;
    }

    setState(() => _saving = true);

    try {
      final notifier = ref.read(transactionListProvider.notifier);
      for (final row in _rows) {
        final tx = Transaction(
          id: _uuid.v4(),
          title: row.titleCtrl.text.trim(),
          amount: double.parse(row.amountCtrl.text.trim()),
          category: row.category,
          type: row.type,
          date: row.date,
          customCategoryId: row.customCategoryId,
        );
        await notifier.add(tx);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _globalError = 'Failed to save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
      child: Column(
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
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

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Log',
                        style: GoogleFonts.dmSans(
                            color: context.appTextPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5)),
                    Text('Add all today\'s transactions at once',
                        style: GoogleFonts.dmSans(
                            color: context.appTextMuted, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                // Row count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.appAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: context.appAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text('${_rows.length} item${_rows.length != 1 ? 's' : ''}',
                      style: GoogleFonts.dmSans(
                          color: context.appAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // ── Error banner ─────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _globalError != null
                ? Container(
                    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.appExpense.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              context.appExpense.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline_rounded,
                          color: context.appExpense, size: 16),
                      const Gap(8),
                      Expanded(
                          child: Text(_globalError!,
                              style: GoogleFonts.dmSans(
                                  color: context.appExpense,
                                  fontSize: 13))),
                      GestureDetector(
                        onTap: () => setState(() => _globalError = null),
                        child: Icon(Icons.close_rounded,
                            color: context.appExpense, size: 16),
                      ),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),

          const Gap(8),

          // ── Row list ─────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding:
                  EdgeInsets.fromLTRB(16, 4, 16, 12 + keyboardHeight),
              child: Column(
                children: [
                  // Column headers
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: Row(children: [
                      SizedBox(
                        width: 28,
                        child: Text('#',
                            style: GoogleFonts.dmSans(
                                color: context.appTextMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Gap(6),
                      Expanded(
                        flex: 3,
                        child: Text('Title',
                            style: GoogleFonts.dmSans(
                                color: context.appTextMuted, fontSize: 11)),
                      ),
                      const Gap(6),
                      Expanded(
                        flex: 2,
                        child: Text('Amount (₹)',
                            style: GoogleFonts.dmSans(
                                color: context.appTextMuted, fontSize: 11)),
                      ),
                      const SizedBox(width: 28),
                    ]),
                  ),

                  // Rows
                  ..._rows.asMap().entries.map((e) => _TransactionRow(
                        key: ValueKey(e.value.id),
                        rowData: e.value,
                        index: e.key,
                        showError: _attempted,
                        onRemove: _rows.length > 1
                            ? () => _removeRow(e.key)
                            : null,
                        onChanged: () => setState(() {}),
                      )),

                  const Gap(8),

                  // Add row button
                  GestureDetector(
                    onTap: _saving ? null : _addRow,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.appBorder,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              color: context.appTextSecondary, size: 16),
                          const Gap(6),
                          Text('Add another transaction',
                              style: GoogleFonts.dmSans(
                                  color: context.appTextSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),

                  const Gap(16),

                  // Summary strip
                  if (_rows.isNotEmpty) _SummaryStrip(rows: _rows),

                  const Gap(16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveAll,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: context.appAccent,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16)),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save_rounded,
                                    color: Colors.white, size: 18),
                                const Gap(8),
                                Text(
                                  'Save ${_rows.length} Transaction${_rows.length != 1 ? 's' : ''}',
                                  style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                              ],
                            ),
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

// ─── Individual transaction row ───────────────────────────────────────────────

class _TransactionRow extends ConsumerStatefulWidget {
  final _RowData rowData;
  final int index;
  final bool showError;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _TransactionRow({
    super.key,
    required this.rowData,
    required this.index,
    required this.showError,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  ConsumerState<_TransactionRow> createState() => _TransactionRowState();
}

class _TransactionRowState extends ConsumerState<_TransactionRow> {
  bool _expanded = true; // First row starts expanded

  @override
  void initState() {
    super.initState();
    // Only first row starts expanded, rest start collapsed
    _expanded = widget.index == 0;
  }

  String get _rowSummary {
    final title = widget.rowData.titleCtrl.text.trim();
    final amt = widget.rowData.amountCtrl.text.trim();
    if (title.isEmpty && amt.isEmpty) return 'Tap to fill in details';
    final prefix = widget.rowData.type == TransactionType.income ? '+' : '-';
    final amtStr = amt.isEmpty ? '?' : '₹$amt';
    return '${title.isEmpty ? 'Untitled' : title}  $prefix$amtStr';
  }

  Color get _typeColor {
    switch (widget.rowData.type) {
      case TransactionType.income:
        return context.appIncome;
      case TransactionType.borrowed:
        return context.appBorrowed;
      case TransactionType.lend:
        return context.appLend;
      default:
        return context.appExpense;
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.rowData;
    final hasError = widget.showError && !row.isValid;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? context.appExpense.withValues(alpha: 0.5)
              : _expanded
                  ? context.appAccent.withValues(alpha: 0.4)
                  : context.appBorder,
          width: hasError || _expanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Row header (always visible) ────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(children: [
                // Index badge
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: hasError
                        ? context.appExpense.withValues(alpha: 0.15)
                        : _typeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${widget.index + 1}',
                        style: GoogleFonts.dmSans(
                            color: hasError
                                ? context.appExpense
                                : _typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    _rowSummary,
                    style: GoogleFonts.dmSans(
                      color: hasError
                          ? context.appExpense
                          : context.appTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasError) ...[
                  const Gap(6),
                  Icon(Icons.warning_amber_rounded,
                      color: context.appExpense, size: 14),
                ],
                const Gap(6),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: context.appTextMuted, size: 18,
                ),
                if (widget.onRemove != null) ...[
                  const Gap(4),
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: context.appExpense.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close_rounded,
                          color: context.appExpense, size: 14),
                    ),
                  ),
                ],
              ]),
            ),
          ),

          // ── Expanded fields ────────────────────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: context.appBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  // Type toggle (compact)
                  _CompactTypeToggle(
                    selected: row.type,
                    onChanged: (t) {
                      setState(() {
                        row.type = t;
                        row.category = _defaultCat(t);
                        row.customCategoryId = null;
                      });
                      widget.onChanged();
                    },
                  ),
                  const Gap(10),

                  // Title + Amount side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: row.titleCtrl,
                          textCapitalization:
                              TextCapitalization.sentences,
                          onChanged: (_) {
                            setState(() {});
                            widget.onChanged();
                          },
                          style: GoogleFonts.dmSans(
                              color: context.appTextPrimary,
                              fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Title',
                            labelStyle: GoogleFonts.dmSans(
                                color: context.appTextMuted,
                                fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.amountCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'))
                          ],
                          onChanged: (_) {
                            setState(() {});
                            widget.onChanged();
                          },
                          style: GoogleFonts.dmSans(
                            color: context.appTextPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: '₹ Amount',
                            labelStyle: GoogleFonts.dmSans(
                                color: context.appTextMuted,
                                fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(10),

                  // Category + Date row
                  Row(
                    children: [
                      // Category picker (compact chip scroll)
                      Expanded(
                        child: _CompactCategoryPicker(
                          selected: row.category,
                          customCategoryId: row.customCategoryId,
                          type: row.type,
                          onChanged: (cat, customId) {
                            setState(() {
                              row.category = cat;
                              row.customCategoryId = customId;
                            });
                            widget.onChanged();
                          },
                        ),
                      ),
                      const Gap(8),
                      // Date picker button
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: row.date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => row.date = picked);
                            widget.onChanged();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: context.appSurface,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: context.appBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  color: context.appTextMuted, size: 13),
                              const Gap(5),
                              Text(
                                '${row.date.day}/${row.date.month}',
                                style: GoogleFonts.dmSans(
                                    color: context.appTextPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Collapse button
                  const Gap(6),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = false),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.keyboard_arrow_up_rounded,
                            color: context.appTextMuted, size: 14),
                        const Gap(3),
                        Text('Collapse',
                            style: GoogleFonts.dmSans(
                                color: context.appTextMuted,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  TransactionCategory _defaultCat(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return TransactionCategory.food;
      case TransactionType.income:
        return TransactionCategory.salary;
      case TransactionType.borrowed:
        return TransactionCategory.borrowed;
      case TransactionType.lend:
        return TransactionCategory.lend;
    }
  }
}

// ─── Compact type toggle ──────────────────────────────────────────────────────

class _CompactTypeToggle extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _CompactTypeToggle(
      {required this.selected, required this.onChanged});

  static const _opts = [
    (type: TransactionType.expense, label: 'Expense'),
    (type: TransactionType.income, label: 'Income'),
    (type: TransactionType.borrowed, label: 'Borrow'),
    (type: TransactionType.lend, label: 'Lend'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: _opts.map((o) {
          final isSel = selected == o.type;
          Color color;
          switch (o.type) {
            case TransactionType.income:
              color = context.appIncome;
              break;
            case TransactionType.borrowed:
              color = context.appBorrowed;
              break;
            case TransactionType.lend:
              color = context.appLend;
              break;
            default:
              color = context.appExpense;
          }
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSel
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(o.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                        color: isSel ? color : context.appTextMuted,
                        fontSize: 11,
                        fontWeight: isSel
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Compact category picker ──────────────────────────────────────────────────

class _CompactCategoryPicker extends ConsumerWidget {
  final TransactionCategory selected;
  final String? customCategoryId;
  final TransactionType type;
  final void Function(TransactionCategory, String?) onChanged;

  const _CompactCategoryPicker({
    required this.selected,
    required this.customCategoryId,
    required this.type,
    required this.onChanged,
  });

  List<TransactionCategory> get _builtinCats {
    switch (type) {
      case TransactionType.expense:
        return [
          TransactionCategory.food, TransactionCategory.travel,
          TransactionCategory.essentials, TransactionCategory.shop,
          TransactionCategory.home, TransactionCategory.health,
          TransactionCategory.work, TransactionCategory.misc,
        ];
      case TransactionType.income:
        return [
          TransactionCategory.salary, TransactionCategory.cashback,
          TransactionCategory.gifts, TransactionCategory.otherIncome,
        ];
      case TransactionType.borrowed:
        return [TransactionCategory.borrowed];
      case TransactionType.lend:
        return [TransactionCategory.lend];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCustom = type == TransactionType.expense ||
        type == TransactionType.income;
    final matchingType = type == TransactionType.expense
        ? CustomCategoryType.expense
        : CustomCategoryType.income;
    final customCats = showCustom
        ? ref.watch(customCategoryProvider).when(
              data: (list) => list
                  .where((c) =>
                      !c.deleted && c.categoryType == matchingType)
                  .toList(),
              loading: () => <CustomCategory>[],
              error: (_, __) => <CustomCategory>[],
            )
        : <CustomCategory>[];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._builtinCats.map((c) {
            final info = categoryInfoMap[c]!;
            final isSel = customCategoryId == null && selected == c;
            return _CatChip(
              label: info.label,
              icon: info.icon,
              color: info.color,
              isSelected: isSel,
              onTap: () => onChanged(c, null),
            );
          }),
          ...customCats.map((c) {
            final isSel = customCategoryId == c.id;
            return _CatChip(
              label: c.name,
              icon: c.icon,
              color: c.color,
              isSelected: isSel,
              onTap: () => onChanged(TransactionCategory.misc, c.id),
            );
          }),
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : context.appBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: isSelected ? color : context.appTextMuted,
              size: 11),
          const Gap(4),
          Text(label,
              style: GoogleFonts.dmSans(
                  color: isSelected ? color : context.appTextSecondary,
                  fontSize: 11,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w400)),
        ]),
      ),
    );
  }
}

// ─── Summary strip ────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final List<_RowData> rows;
  const _SummaryStrip({required this.rows});

  @override
  Widget build(BuildContext context) {
    double totalExpense = 0;
    double totalIncome = 0;
    int validCount = 0;

    for (final r in rows) {
      final amt = double.tryParse(r.amountCtrl.text.trim()) ?? 0;
      if (r.type == TransactionType.expense) totalExpense += amt;
      if (r.type == TransactionType.income) totalIncome += amt;
      if (r.isValid) validCount++;
    }

    final net = totalIncome - totalExpense;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          _StripItem(
              label: 'Income',
              value: '₹${totalIncome.toStringAsFixed(0)}',
              color: context.appIncome),
          _Divider(),
          _StripItem(
              label: 'Expense',
              value: '₹${totalExpense.toStringAsFixed(0)}',
              color: context.appExpense),
          _Divider(),
          _StripItem(
              label: 'Net',
              value:
                  '${net >= 0 ? '+' : ''}₹${net.toStringAsFixed(0)}',
              color: net >= 0 ? context.appIncome : context.appExpense),
          _Divider(),
          _StripItem(
              label: 'Ready',
              value: '$validCount/${rows.length}',
              color: validCount == rows.length
                  ? context.appIncome
                  : context.appBorrowed),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StripItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(label,
            style: GoogleFonts.dmSans(
                color: context.appTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
        const Gap(2),
        Text(value,
            style: GoogleFonts.dmSans(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 28, color: context.appBorder,
      margin: const EdgeInsets.symmetric(horizontal: 4));
}