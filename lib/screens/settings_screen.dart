import 'package:chole_bature/models/custom_category_model.dart';
import 'package:chole_bature/providers/custom_category_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/future_transaction_model.dart';
import '../models/security_model.dart';
import '../models/transaction_model.dart';
import '../providers/future_transaction_provider.dart';
import '../providers/security_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../theme/app_theme.dart';
import 'budget_screen.dart';
import 'feedback_screen.dart';
import 'manage_categories_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode   = ref.watch(themeModeProvider);
    final secSettings = ref.watch(securitySettingsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.appBg,
            floating: true,
            snap: true,
            title: Text('Settings',
                style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionHeader(label: 'Appearance'),
                const Gap(8),
                _Card(children: [
                  _Tile(
                    icon: Icons.brightness_auto_rounded,
                    iconColor: context.appAccent,
                    title: 'Theme',
                    subtitle: _themeModeLabel(themeMode),
                    trailing: _ThemeCycleBtn(
                      themeMode: themeMode,
                      onCycle: () => ref.read(themeModeProvider.notifier).cycle(),
                    ),
                  ),
                ]),

                const Gap(20),
                const _SectionHeader(label: 'Security'),
                const Gap(8),
                _Card(children: [
                  _Tile(
                    icon: Icons.lock_rounded,
                    iconColor: context.appBorrowed,
                    title: 'App Lock',
                    subtitle: secSettings.enabled
                        ? 'Enabled · ${_lockLabel(secSettings.lockType)}'
                        : 'Disabled',
                    trailing: Switch(
                      value: secSettings.enabled,
                      onChanged: (val) async {
                        if (val) {
                          await _showSetLock(context, ref);
                        } else {
                          await ref
                              .read(securitySettingsProvider.notifier)
                              .disable();
                        }
                      },
                      activeThumbColor: context.appAccent,
                    ),
                  ),
                  if (secSettings.enabled) ...[
                    _Divider(),
                    _Tile(
                      icon: Icons.timer_rounded,
                      iconColor: context.appAccent,
                      title: 'Auto-Lock After',
                      subtitle: _autoLockLabel(secSettings.autoLockSeconds),
                      onTap: () => _showAutoLock(context, ref, secSettings),
                    ),
                    _Divider(),
                    _Tile(
                      icon: Icons.edit_rounded,
                      iconColor: context.appTextSecondary,
                      title: 'Change Lock Method',
                      subtitle: 'PIN or password',
                      onTap: () => _showSetLock(context, ref),
                    ),
                  ],
                ]),

                const Gap(20),
                const _SectionHeader(label: 'Finance'),
                const Gap(8),
                _Card(children: [
                  _Tile(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: context.appIncome,
                    title: 'Budget & Limits',
                    subtitle: 'Set daily, weekly, monthly limits',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const BudgetScreen())),
                  ),
                  _Divider(),                    
                  _Tile(                        
                    icon: Icons.category_rounded,
                    iconColor: context.appAccent,
                    title: 'Manage Categories',
                    subtitle: 'Create, edit and delete custom categories',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const ManageCategoriesScreen())),
                  ),
                ]),

                const Gap(20),
                const _SectionHeader(label: 'Data'),
                const Gap(8),
                _Card(children: [
                  _Tile(
                    icon: Icons.download_rounded,
                    iconColor: context.appAccent,
                    title: 'Export All Data',
                    subtitle: 'One CSV with transactions + scheduled → Downloads',
                    onTap: () => _export(context, ref),
                  ),
                  _Divider(),
                  _Tile(
                    icon: Icons.upload_rounded,
                    iconColor: context.appIncome,
                    title: 'Import from CSV',
                    subtitle: 'Pick a CholeBature backup CSV to restore',
                    onTap: () => _import(context, ref),
                  ),
                ]),

                const Gap(20),
                const _SectionHeader(label: 'Feedback'),
                const Gap(8),
                _Card(children: [
                  _Tile(
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFFD700),
                    title: 'Rate CholeBature',
                    subtitle: 'Share your feedback and suggestions',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                    ),
                  ),
                ]),

                const Gap(20),
                const _SectionHeader(label: 'About'),
                const Gap(8),
                _Card(children: [
                  _Tile(
                    icon: Icons.info_outline_rounded,
                    iconColor: context.appTextSecondary,
                    title: 'Version',
                    subtitle: '3.5.5',
                  ),
                  _Divider(),
                  _Tile(
                    icon: Icons.person_rounded,
                    iconColor: context.appTextSecondary,
                    title: 'Made by',
                    subtitle: '@siddiq0611',
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode m) => switch (m) {
        ThemeMode.system => 'System default',
        ThemeMode.light  => 'Light',
        ThemeMode.dark   => 'Dark',
      };

  String _lockLabel(LockType t) => switch (t) {
        LockType.none     => 'None',
        LockType.pin      => 'PIN',
        LockType.password => 'Password',
      };

  String _autoLockLabel(int s) {
    if (s == 0)   return 'Immediately';
    if (s < 60)   return '${s}s';
    if (s < 3600) return '${s ~/ 60} min';
    return '${s ~/ 3600}h';
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final txs = ref.read(transactionListProvider).when<List<Transaction>>(
        data: (v) => v, loading: () => [], error: (_, __) => []);
    final fts = ref.read(futureTransactionProvider)
        .when<List<FutureTransaction>>(
            data: (v) => v, loading: () => [], error: (_, __) => []);
    // NEW: read all custom categories (including soft-deleted)
    final cats = ref.read(customCategoryProvider)
        .when<List<CustomCategory>>(
            data: (v) => v, loading: () => [], error: (_, __) => []);

    if (txs.isEmpty && fts.isEmpty && cats.isEmpty) {
      _snack(context, 'Nothing to export', color: context.appBorrowed);
      return;
    }
    _snack(context, 'Preparing…', color: context.appAccent, dur: 2);
    await ExportService.exportAll(
        transactions: txs,
        futureTransactions: fts,
        customCategories: cats);   // NEW
    if (context.mounted) {
      _snack(context, 'Saved to Downloads & share sheet opened',
          color: context.appIncome, dur: 4);
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Import from CSV',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Select a CholeBature backup CSV.\n\n'
          'Transactions and scheduled items are restored. '
          'Duplicates are skipped.',
          style: GoogleFonts.dmSans(
              color: context.appTextSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.dmSans(color: context.appTextSecondary))),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.folder_open_rounded, size: 16, color: Colors.white),
            label: Text('Choose File',
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;

    final existTx = ref.read(transactionListProvider).when<List<Transaction>>(
        data: (v) => v, loading: () => [], error: (_, __) => []);
    final existFt = ref.read(futureTransactionProvider)
        .when<List<FutureTransaction>>(
            data: (v) => v, loading: () => [], error: (_, __) => []);
    // NEW: pass existing custom cats for deduplication
    final existCats = ref.read(customCategoryProvider)
        .when<List<CustomCategory>>(
            data: (v) => v, loading: () => [], error: (_, __) => []);

    _snack(context, 'Opening file picker…', color: context.appAccent, dur: 1);
    final result = await ImportService.pickAndParseAll(
        existingTx: existTx,
        existingFt: existFt,
        existingCustomCats: existCats);   // NEW
    if (result == null || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ImportPreviewDialog(result: result),
    );
    if (confirm != true || !context.mounted) return;

    // NEW: import custom categories FIRST so transactions can reference them
    for (final cat in result.customCategories) {
      await ref.read(customCategoryProvider.notifier).add(cat);
    }
    for (final tx in result.transactions) {
      await ref.read(transactionListProvider.notifier).add(tx);
    }
    for (final ft in result.futureTransactions) {
      await ref.read(futureTransactionProvider.notifier).add(ft);
    }

    if (!context.mounted) return;
    final parts = <String>[];
    if (result.importedCats > 0) parts.add('${result.importedCats} categories');
    if (result.importedTx > 0) parts.add('${result.importedTx} transactions');
    if (result.importedFt > 0) parts.add('${result.importedFt} scheduled');
    final skipped =
        result.skippedTx + result.skippedFt + result.skippedCats;
    _snack(
      context,
      'Imported ${parts.join(' + ')}'
      '${skipped > 0 ? ', skipped $skipped duplicates' : ''}',
      color: context.appIncome,
      dur: 4,
    );
  }

  void _snack(BuildContext context, String msg,
      {required Color color, int dur = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: dur),
    ));
  }

  Future<void> _showSetLock(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SetLockSheet(),
      );

  Future<void> _showAutoLock(
          BuildContext context, WidgetRef ref, SecuritySettings settings) =>
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            _AutoLockSheet(current: settings.autoLockSeconds),
      );
}

// ── Import Preview ─────────────────────────────────────────────────────────────

class _ImportPreviewDialog extends StatelessWidget {
  final ImportResult result;
  const _ImportPreviewDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Import Preview',
          style: GoogleFonts.dmSans(
              color: context.appTextPrimary, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.importedTx > 0)
              _PRow(Icons.receipt_long_rounded, context.appIncome,
                  'Transactions', '${result.importedTx}'),
            if (result.importedCats > 0) ...[
              _PRow(Icons.category_rounded, context.appAccent,
                  'Custom categories', '${result.importedCats}'),
              const Gap(8),
            ],
            if (result.skippedCats > 0) ...[
              _PRow(Icons.skip_next_rounded, context.appBorrowed,
                  'Categories already exist', '${result.skippedCats}'),
              const Gap(8),
            ],
            if (result.skippedTx > 0) ...[
              const Gap(8),
              _PRow(Icons.skip_next_rounded, context.appBorrowed,
                  'Tx duplicates skipped', '${result.skippedTx}'),
            ],
            if (result.importedFt > 0) ...[
              const Gap(8),
              _PRow(Icons.schedule_rounded, context.appAccent,
                  'Scheduled imported', '${result.importedFt}'),
            ],
            if (result.skippedFt > 0) ...[
              const Gap(8),
              _PRow(Icons.skip_next_rounded, context.appBorrowed,
                  'Scheduled duplicates skipped', '${result.skippedFt}'),
            ],
            if (result.failed > 0) ...[
              const Gap(8),
              _PRow(Icons.error_outline_rounded, context.appExpense,
                  'Failed to parse', '${result.failed}'),
            ],
            if (!result.hasAnything) ...[
              const Gap(12),
              Text('Nothing new to import.',
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: context.appTextSecondary))),
        if (result.hasAnything)
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: context.appIncome),
              child: Text('Import',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600))),
      ],
    );
  }
}

class _PRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _PRow(this.icon, this.color, this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: color, size: 16),
        const Gap(8),
        Expanded(
            child: Text(label,
                style: GoogleFonts.dmSans(
                    color: context.appTextSecondary, fontSize: 13))),
        Text(value,
            style: GoogleFonts.dmSans(
                color: color, fontSize: 14, fontWeight: FontWeight.w700)),
      ]);
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: GoogleFonts.dmSans(
          color: context.appTextMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8));
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(children: children),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: GoogleFonts.dmSans(
                        color: context.appTextMuted, fontSize: 12)),
              ]),
            ),
            if (trailing != null) trailing!,
            if (trailing == null && onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: context.appTextMuted, size: 18),
          ]),
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 64),
        child: Divider(height: 1, color: context.appBorder),
      );
}

class _ThemeCycleBtn extends StatelessWidget {
  final ThemeMode themeMode;
  final VoidCallback onCycle;
  const _ThemeCycleBtn({required this.themeMode, required this.onCycle});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onCycle,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.appBorder),
          ),
          child: Icon(
            switch (themeMode) {
              ThemeMode.system => Icons.brightness_auto_rounded,
              ThemeMode.light  => Icons.light_mode_rounded,
              ThemeMode.dark   => Icons.dark_mode_rounded,
            },
            color: context.appTextSecondary,
            size: 18,
          ),
        ),
      );
}

// ── Set Lock Sheet — biometric REMOVED ────────────────────────────────────────

class _SetLockSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SetLockSheet> createState() => _SetLockSheetState();
}

class _SetLockSheetState extends ConsumerState<_SetLockSheet> {
  LockType _type   = LockType.pin;
  final _cred      = TextEditingController();
  final _confirm   = TextEditingController();
  bool _obscure    = true;
  bool _saving     = false;
  String? _error;

  @override
  void dispose() {
    _cred.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _error = null; _saving = true; });

    if (_type == LockType.pin) {
      if (_cred.text.length < 4 || _cred.text.length > 6) {
        setState(() { _saving = false; _error = 'PIN must be 4–6 digits'; });
        return;
      }
    } else {
      if (_cred.text.length < 4) {
        setState(() {
          _saving = false;
          _error = 'Password must be at least 4 characters';
        });
        return;
      }
    }

    if (_cred.text != _confirm.text) {
      setState(() {
        _saving = false;
        _error = _type == LockType.pin ? 'PINs do not match' : 'Passwords do not match';
      });
      return;
    }

    await ref.read(securitySettingsProvider.notifier).enable(_type, _cred.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final kbh = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + kbh),
      child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Gap(16),
            Text('Set App Lock',
                style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const Gap(16),
            // Only PIN and Password — no Biometric
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Chip(LockType.pin, Icons.pin_rounded, 'PIN', _type,
                  () => setState(() => _type = LockType.pin)),
              _Chip(LockType.password, Icons.key_rounded, 'Password', _type,
                  () => setState(() => _type = LockType.password)),
            ]),
            const Gap(16),
            TextField(
              controller: _cred,
              obscureText: _obscure,
              keyboardType: _type == LockType.pin
                  ? TextInputType.number
                  : TextInputType.text,
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary, fontSize: 16),
              decoration: InputDecoration(
                labelText: _type == LockType.pin
                    ? 'Enter PIN (4–6 digits)'
                    : 'Enter password',
                prefixIcon: Icon(Icons.lock_outline_rounded,
                    color: context.appTextMuted, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: context.appTextMuted,
                      size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const Gap(12),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              keyboardType: _type == LockType.pin
                  ? TextInputType.number
                  : TextInputType.text,
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary, fontSize: 16),
              decoration: InputDecoration(
                labelText: _type == LockType.pin ? 'Confirm PIN' : 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline_rounded,
                    color: context.appTextMuted, size: 18),
              ),
            ),
            if (_error != null) ...[
              const Gap(10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appExpense.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: context.appExpense.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: context.appExpense, size: 16),
                    const Gap(8),
                    Expanded(
                      child: Text(_error!,
                          style: GoogleFonts.dmSans(
                              color: context.appExpense, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
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
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Enable Lock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final LockType type, selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Chip(this.type, this.icon, this.label, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) {
    final sel = selected == type;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel
              ? context.appAccent.withValues(alpha: 0.15)
              : context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? context.appAccent : context.appBorder,
              width: sel ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: sel ? context.appAccent : context.appTextMuted),
          const Gap(5),
          Text(label,
              style: GoogleFonts.dmSans(
                  color: sel ? context.appAccent : context.appTextSecondary,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

// ── Auto-Lock Sheet ────────────────────────────────────────────────────────────

class _AutoLockSheet extends ConsumerWidget {
  final int current;
  const _AutoLockSheet({required this.current});

  static const _opts = [
    (label: 'Immediately', seconds: 0),
    (label: '15 seconds',  seconds: 15),
    (label: '30 seconds',  seconds: 30),
    (label: '1 minute',    seconds: 60),
    (label: '5 minutes',   seconds: 300),
    (label: '15 minutes',  seconds: 900),
    (label: '30 minutes',  seconds: 1800),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Gap(16),
          Text('Auto-Lock After',
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const Gap(12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _opts.map((o) {
                  final sel = current == o.seconds;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (sel ? context.appAccent : context.appTextMuted)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.timer_rounded,
                          color: sel ? context.appAccent : context.appTextMuted,
                          size: 18),
                    ),
                    title: Text(o.label,
                        style: GoogleFonts.dmSans(
                            color: sel ? context.appAccent : context.appTextPrimary,
                            fontSize: 14,
                            fontWeight:
                                sel ? FontWeight.w600 : FontWeight.w400)),
                    trailing: sel
                        ? Icon(Icons.check_rounded,
                            color: context.appAccent, size: 18)
                        : null,
                    onTap: () async {
                      await ref
                          .read(securitySettingsProvider.notifier)
                          .setAutoLockTimeout(o.seconds);
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}