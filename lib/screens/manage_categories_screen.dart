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
            onTap: () => _openSheet(context, ref),
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
            return _EmptyState(onAdd: () => _openSheet(context, ref));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
            children: [
              if (active.isNotEmpty) ...[
                _SectionLabel('Active categories  (${active.length})'),
                const Gap(8),
                ...active.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CategoryCard(
                        cat: e.value,
                        index: e.key,
                        onEdit: () => _openSheet(context, ref, existing: e.value),
                        onDelete: () =>
                            _confirmDelete(context, ref, notifier, e.value),
                      ),
                    )),
              ],
              if (deleted.isNotEmpty) ...[
                const Gap(16),
                _SectionLabel(
                    'Deleted  (${deleted.length})  ·  transactions preserved'),
                const Gap(6),
                Text(
                  'These categories are hidden from pickers but existing transactions still show their name.',
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
                        onRestore: () => notifier.update(
                            e.value.copyWith(deleted: false)),
                        onHardDelete: () =>
                            _confirmHardDelete(context, ref, notifier, e.value),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref,
      {CustomCategory? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      CustomCategoryNotifier notifier, CustomCategory cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${cat.name}"?',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Existing transactions that use this category will be preserved — '
          'they will still display "${cat.name}" but you won\'t be able to create new transactions with it.',
          style: GoogleFonts.dmSans(color: context.appTextSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.dmSans(color: context.appTextSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: context.appExpense),
              child: Text('Delete',
                  style: GoogleFonts.dmSans(
                      color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed == true) await notifier.delete(cat.id);
  }

  Future<void> _confirmHardDelete(BuildContext context, WidgetRef ref,
      CustomCategoryNotifier notifier, CustomCategory cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Permanently remove "${cat.name}"?',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'This cannot be undone. Transactions that referenced this category '
          'will fall back to displaying their category ID.',
          style: GoogleFonts.dmSans(
              color: context.appTextSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.dmSans(color: context.appTextSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: context.appExpense),
              child: Text('Remove permanently',
                  style: GoogleFonts.dmSans(
                      color: Colors.white, fontWeight: FontWeight.w600))),
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
              color: color.withValues(alpha: isDeleted ? 0.5 : 1.0), size: 18),
        ),
        const Gap(12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              cat.name,
              style: GoogleFonts.dmSans(
                color: isDeleted
                    ? context.appTextMuted
                    : context.appTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: isDeleted ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isDeleted)
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
            child:
                Text('Restore', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600)),
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
        .slideY(begin: 0.05, end: 0, duration: 280.ms, delay: (index * 40).ms);
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

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

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.category_rounded, size: 60, color: context.appTextMuted),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
  Color _color = kCategoryColorPalette[0];
  IconData _icon = kCategoryIconOptions[0].icon;
  bool _saving = false;
  String? _error;

  static const _uuid = Uuid();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.existing!.name;
      _color = widget.existing!.color;
      _icon = widget.existing!.icon;
    }
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
        createdAt:
            _isEditing ? widget.existing!.createdAt : DateTime.now(),
      );
      final notifier = ref.read(customCategoryProvider.notifier);
      if (_isEditing) {
        await notifier.update(cat);
      } else {
        await notifier.add(cat);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _error = 'Failed to save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kbh = MediaQuery.of(context).viewInsets.bottom;

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
          // Drag handle
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
                      color: context.appExpense.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: context.appExpense.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline_rounded,
                          color: context.appExpense, size: 16),
                      const Gap(8),
                      Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.dmSans(
                                  color: context.appExpense, fontSize: 13))),
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

                  // ── Preview ──────────────────────────────────────────────
                  Center(
                    child: Column(children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: _color.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: Icon(_icon, color: _color, size: 30),
                      ),
                      const Gap(8),
                      Text(
                        _nameCtrl.text.isEmpty
                            ? 'Preview'
                            : _nameCtrl.text,
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

                  // ── Name ─────────────────────────────────────────────────
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

                  // ── Color picker ─────────────────────────────────────────
                  _SectionLabel('Color'),
                  const Gap(10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: kCategoryColorPalette.map((c) {
                      final isSel = _color.value == c.value;
                      return GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel
                                  ? context.appTextPrimary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSel
                                ? [
                                    BoxShadow(
                                        color: c.withValues(alpha: 0.5),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: isSel
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const Gap(20),

                  // ── Icon picker ──────────────────────────────────────────
                  _SectionLabel('Icon'),
                  const Gap(10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kCategoryIconOptions.map((o) {
                      final isSel =
                          _icon.codePoint == o.icon.codePoint;
                      return GestureDetector(
                        onTap: () => setState(() => _icon = o.icon),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSel
                                ? _color.withValues(alpha: 0.18)
                                : context.appSurfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? _color : context.appBorder,
                              width: isSel ? 1.5 : 1,
                            ),
                          ),
                          child: Tooltip(
                            message: o.label,
                            child: Icon(o.icon,
                                color: isSel
                                    ? _color
                                    : context.appTextMuted,
                                size: 20),
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
                              width: 20, height: 20,
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
