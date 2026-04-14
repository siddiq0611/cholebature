import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/custom_category_model.dart';
import '../providers/custom_category_provider.dart';
import '../theme/app_theme.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catAsync = ref.watch(customCategoryProvider);
    final notifier = ref.read(customCategoryProvider.notifier);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        title: Text('Custom Categories',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.appTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          GestureDetector(
            onTap: () => _openSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: context.appAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                const Gap(4),
                Text('New',
                    style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ]),
            ),
          ),
        ],
      ),
      body: catAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: context.appAccent)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cats) {
          final active = cats.where((c) => !c.deleted).toList();
          final deleted = cats.where((c) => c.deleted).toList();

          if (cats.isEmpty) {
            return _EmptyState(onAdd: () => _openSheet(context));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
            children: [
              if (active.isNotEmpty) ...[
                _SectionLabel('Active  (${active.length})'),
                const Gap(8),
                ...active.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CategoryCard(
                        cat: e.value,
                        index: e.key,
                        onEdit: () =>
                            _openSheet(context, existing: e.value),
                        onDelete: () =>
                            _confirmDelete(context, notifier, e.value),
                      ),
                    )),
              ],
              if (deleted.isNotEmpty) ...[
                const Gap(16),
                _SectionLabel(
                    'Deleted  (${deleted.length})  ·  transactions preserved'),
                const Gap(6),
                Text(
                  'Hidden from pickers but existing transactions still show their name.',
                  style: GoogleFonts.dmSans(
                      color: context.appTextMuted, fontSize: 11, height: 1.5),
                ),
                const Gap(10),
                ...deleted.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CategoryCard(
                        cat: e.value,
                        index: e.key,
                        isDeleted: true,
                        onRestore: () =>
                            notifier.update(e.value.copyWith(deleted: false)),
                        onHardDelete: () =>
                            _confirmHardDelete(context, notifier, e.value),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openSheet(BuildContext context, {CustomCategory? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context,
      CustomCategoryNotifier notifier, CustomCategory cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${cat.name}"?',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Existing transactions will be preserved — they will still display '
          '"${cat.name}" but you won\'t be able to create new ones with it.',
          style: GoogleFonts.dmSans(
              color: context.appTextSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      GoogleFonts.dmSans(color: context.appTextSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: context.appExpense),
              child: Text('Delete',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed == true) await notifier.delete(cat.id);
  }

  Future<void> _confirmHardDelete(BuildContext context,
      CustomCategoryNotifier notifier, CustomCategory cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Permanently remove "${cat.name}"?',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'This cannot be undone.',
          style: GoogleFonts.dmSans(
              color: context.appTextSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      GoogleFonts.dmSans(color: context.appTextSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: context.appExpense),
              child: Text('Remove permanently',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed == true) await notifier.hardDelete(cat.id);
  }
}

// ─── Category card ────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final CustomCategory cat;
  final int index;
  final bool isDeleted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onHardDelete;

  const _CategoryCard({
    required this.cat,
    required this.index,
    this.isDeleted = false,
    this.onEdit,
    this.onDelete,
    this.onRestore,
    this.onHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDeleted ? context.appTextMuted : cat.color;
    final typeLabel = cat.categoryType == CustomCategoryType.expense
        ? 'Expense'
        : 'Income';
    final typeColor = cat.categoryType == CustomCategoryType.expense
        ? context.appExpense
        : context.appIncome;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDeleted
              ? context.appBorder
              : cat.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDeleted ? 0.08 : 0.15),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(cat.icon,
              color: color.withValues(alpha: isDeleted ? 0.5 : 1.0),
              size: 18),
        ),
        const Gap(12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  style: GoogleFonts.dmSans(
                    color: isDeleted
                        ? context.appTextMuted
                        : context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration:
                        isDeleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const Gap(2),
                if (!isDeleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(typeLabel,
                        style: GoogleFonts.dmSans(
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  Text('Deleted · transactions preserved',
                      style: GoogleFonts.dmSans(
                          color: context.appTextMuted, fontSize: 11)),
              ]),
        ),
        if (!isDeleted) ...[
          IconButton(
            icon: Icon(Icons.edit_rounded,
                color: context.appTextMuted, size: 16),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const Gap(8),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: context.appExpense, size: 16),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ] else ...[
          TextButton(
            onPressed: onRestore,
            style: TextButton.styleFrom(
                foregroundColor: context.appIncome,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text('Restore',
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: Icon(Icons.delete_forever_rounded,
                color: context.appExpense, size: 16),
            onPressed: onHardDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ]),
    )
        .animate()
        .fadeIn(duration: 280.ms, delay: (index * 40).ms)
        .slideY(
            begin: 0.05,
            end: 0,
            duration: 280.ms,
            delay: (index * 40).ms);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: GoogleFonts.dmSans(
          color: context.appTextMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8));
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_rounded,
                  size: 60, color: context.appTextMuted),
              const Gap(16),
              Text('No custom categories yet',
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Gap(6),
              Text('Tap "New" to create your first category',
                  style: GoogleFonts.dmSans(
                      color: context.appTextMuted, fontSize: 13)),
              const Gap(24),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
      );
}

// ─── Create / Edit sheet ──────────────────────────────────────────────────────

class _CategorySheet extends ConsumerStatefulWidget {
  final CustomCategory? existing;
  const _CategorySheet({this.existing});

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _nameCtrl = TextEditingController();
  Color _color = const Color(0xFFEF5350);
  IconData _icon = Icons.category_rounded;
  CustomCategoryType _type = CustomCategoryType.expense;
  bool _saving = false;
  String? _error;

  // HSV sliders state
  double _hue = 0;
  double _saturation = 0.8;
  double _value = 0.9;

  static const _uuid = Uuid();
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _color = e.color;
      _type = e.categoryType;
      _icon = e.icon;
      final hsv = HSVColor.fromColor(_color);
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
    } else {
      _syncColorFromHSV();
    }
  }

  void _syncColorFromHSV() {
    _color =
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }

    // Check for duplicate name within the same category type
    final allCats = ref.read(customCategoryProvider).when(
      data: (list) => list,
      loading: () => <CustomCategory>[],
      error: (_, __) => <CustomCategory>[],
    );

    final defaultNames = categoryInfoMap.values
        .map((e) => e.label.toLowerCase())
        .toSet();

    final normalized = name.trim().toLowerCase();

    final isDuplicate =
      defaultNames.contains(normalized) ||   // ✅ NEW (default check)
      allCats.any((c) =>
        !c.deleted &&
        c.categoryType == _type &&
        c.name.trim().toLowerCase() == normalized &&
        (_isEditing ? c.id != widget.existing!.id : true),
      );

    if (isDuplicate) {
      setState(() => _error =
          'A ${_type == CustomCategoryType.expense ? 'expense' : 'income'} '
          'category named "$name" already exists.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final cat = CustomCategory(
        id: _isEditing ? widget.existing!.id : _uuid.v4(),
        name: name,
        colorValue: _color.value,
        iconCodePoint: _icon.codePoint,
        iconFontFamily: _icon.fontFamily ?? 'MaterialIcons',
        deleted: false,
        createdAt: _isEditing ? widget.existing!.createdAt : DateTime.now(),
        categoryType: _type,
      );
      final notifier = ref.read(customCategoryProvider.notifier);
      if (_isEditing) {
        await notifier.update(cat);
      } else {
        await notifier.add(cat);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Failed to save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kbh = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          // Error banner
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _error != null
                ? Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          context.appExpense.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: context.appExpense
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline_rounded,
                          color: context.appExpense, size: 16),
                      const Gap(8),
                      Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.dmSans(
                                  color: context.appExpense,
                                  fontSize: 13))),
                      GestureDetector(
                        onTap: () => setState(() => _error = null),
                        child: Icon(Icons.close_rounded,
                            color: context.appExpense, size: 16),
                      ),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + kbh),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Edit Category' : 'New Category',
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5),
                  ),
                  const Gap(20),

                  // ── Preview ───────────────────────────────────────────
                  Center(
                    child: Column(children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _color.withValues(alpha: 0.5),
                              width: 2),
                        ),
                        child: Icon(_icon, color: _color, size: 34),
                      ),
                      const Gap(8),
                      Text(
                        _nameCtrl.text.isEmpty ? 'Preview' : _nameCtrl.text,
                        style: GoogleFonts.dmSans(
                            color: _nameCtrl.text.isEmpty
                                ? context.appTextMuted
                                : context.appTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                  const Gap(24),

                  // ── Type toggle ───────────────────────────────────────
                  _FieldLabel('Category type'),
                  const Gap(8),
                  Container(
                    decoration: BoxDecoration(
                      color: context.appSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: Row(children: [
                      _TypeOption(
                        label: 'Expense',
                        selected: _type == CustomCategoryType.expense,
                        color: context.appExpense,
                        onTap: () => setState(
                            () => _type = CustomCategoryType.expense),
                      ),
                      _TypeOption(
                        label: 'Income',
                        selected: _type == CustomCategoryType.income,
                        color: context.appIncome,
                        onTap: () => setState(
                            () => _type = CustomCategoryType.income),
                      ),
                    ]),
                  ),
                  const Gap(20),

                  // ── Name ──────────────────────────────────────────────
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() => _error = null),
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Category name',
                      prefixIcon: Icon(Icons.label_rounded,
                          color: context.appTextMuted, size: 18),
                    ),
                  ),
                  const Gap(20),

                  // ── Color picker (HSV sliders) ─────────────────────────
                  _FieldLabel('Color'),
                  const Gap(12),

                  // Big color preview swatch
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: context.appBorder, width: 1),
                    ),
                  ),
                  const Gap(14),

                  // Hue slider
                  _SliderRow(
                    label: 'Hue',
                    value: _hue,
                    min: 0,
                    max: 360,
                    trackGradient: LinearGradient(colors: [
                      const HSVColor.fromAHSV(1, 0, 1, 1).toColor(),
                      const HSVColor.fromAHSV(1, 60, 1, 1).toColor(),
                      const HSVColor.fromAHSV(1, 120, 1, 1).toColor(),
                      const HSVColor.fromAHSV(1, 180, 1, 1).toColor(),
                      const HSVColor.fromAHSV(1, 240, 1, 1).toColor(),
                      const HSVColor.fromAHSV(1, 300, 1, 1).toColor(),
                      const HSVColor.fromAHSV(1, 360, 1, 1).toColor(),
                    ]),
                    thumbColor: _color,
                    onChanged: (v) => setState(() {
                      _hue = v;
                      _syncColorFromHSV();
                    }),
                  ),
                  const Gap(10),

                  // Saturation slider
                  _SliderRow(
                    label: 'Saturation',
                    value: _saturation,
                    min: 0,
                    max: 1,
                    trackGradient: LinearGradient(colors: [
                      HSVColor.fromAHSV(1, _hue, 0, _value).toColor(),
                      HSVColor.fromAHSV(1, _hue, 1, _value).toColor(),
                    ]),
                    thumbColor: _color,
                    onChanged: (v) => setState(() {
                      _saturation = v;
                      _syncColorFromHSV();
                    }),
                  ),
                  const Gap(10),

                  // Brightness slider
                  _SliderRow(
                    label: 'Brightness',
                    value: _value,
                    min: 0,
                    max: 1,
                    trackGradient: LinearGradient(colors: [
                      Colors.black,
                      HSVColor.fromAHSV(1, _hue, _saturation, 1)
                          .toColor(),
                    ]),
                    thumbColor: _color,
                    onChanged: (v) => setState(() {
                      _value = v;
                      _syncColorFromHSV();
                    }),
                  ),
                  const Gap(20),

                  // ── Icon picker ───────────────────────────────────────
                  _FieldLabel('Icon'),
                  const Gap(10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kCategoryIconOptions.map((o) {
                      final isSel = _icon.codePoint == o.icon.codePoint;
                      return GestureDetector(
                        onTap: () => setState(() => _icon = o.icon),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSel
                                ? _color.withValues(alpha: 0.18)
                                : context.appSurfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? _color : context.appBorder,
                              width: isSel ? 2 : 1,
                            ),
                          ),
                          child: Tooltip(
                            message: o.label,
                            child: Icon(o.icon,
                                color: isSel
                                    ? _color
                                    : context.appTextMuted,
                                size: 22),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Gap(28),

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
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing
                              ? 'Update Category'
                              : 'Create Category'),
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

// ─── Type option button ───────────────────────────────────────────────────────

class _TypeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: selected ? color : context.appTextMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── HSV slider row ───────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final LinearGradient trackGradient;
  final Color thumbColor;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.trackGradient,
    required this.thumbColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: GoogleFonts.dmSans(
                color: context.appTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
              thumbColor: thumbColor,
              overlayColor: thumbColor.withValues(alpha: 0.2),
              trackShape: _GradientTrackShape(gradient: trackGradient),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Custom gradient track ────────────────────────────────────────────────────

class _GradientTrackShape extends SliderTrackShape {
  final LinearGradient gradient;
  const _GradientTrackShape({required this.gradient});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const trackHeight = 10.0;
    final trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
        offset.dx, trackTop, parentBox.size.width, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
        parentBox: parentBox,
        offset: offset,
        sliderTheme: sliderTheme);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    context.canvas.drawRRect(rrect, paint);
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.dmSans(
            color: context.appTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500),
      );
}