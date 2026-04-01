import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/security_model.dart';
import '../models/transaction_model.dart';
import '../models/future_transaction_model.dart';
import '../providers/security_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/future_transaction_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import 'budget_screen.dart';

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
                _SettingsCard(children: [
                  _SettingsTile(
                    icon: Icons.brightness_auto_rounded,
                    iconColor: context.appAccent,
                    title: 'Theme',
                    subtitle: _themeModeLabel(themeMode),
                    trailing: _ThemeCycleButton(
                      themeMode: themeMode,
                      onCycle: () {
                        final next = switch (themeMode) {
                          ThemeMode.system => ThemeMode.light,
                          ThemeMode.light  => ThemeMode.dark,
                          ThemeMode.dark   => ThemeMode.system,
                        };
                        ref.read(themeModeProvider.notifier).state = next;
                      },
                    ),
                  ),
                ]),

                const Gap(20),
                const _SectionHeader(label: 'Security'),
                const Gap(8),
                _SettingsCard(children: [
                  _SettingsTile(
                    icon: Icons.lock_rounded,
                    iconColor: context.appBorrowed,
                    title: 'App Lock',
                    subtitle: secSettings.enabled
                        ? 'Enabled · ${_lockTypeLabel(secSettings.lockType)}'
                        : 'Disabled',
                    trailing: Switch(
                      value: secSettings.enabled,
                      onChanged: (val) async {
                        if (val) {
                          await _showSetLockSheet(context, ref);
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
                    _SettingsDivider(),
                    _SettingsTile(
                      icon: Icons.timer_rounded,
                      iconColor: context.appAccent,
                      title: 'Auto-Lock After',
                      subtitle: _autoLockLabel(secSettings.autoLockSeconds),
                      onTap: () =>
                          _showAutoLockSheet(context, ref, secSettings),
                    ),
                    _SettingsDivider(),
                    _SettingsTile(
                      icon: Icons.edit_rounded,
                      iconColor: context.appTextSecondary,
                      title: 'Change Lock Method',
                      subtitle: 'PIN, password, or biometric',
                      onTap: () => _showSetLockSheet(context, ref),
                    ),
                  ],
                ]),

                const Gap(20),
                const _SectionHeader(label: 'Finance'),
                const Gap(8),
                _SettingsCard(children: [
                  _SettingsTile(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: context.appIncome,
                    title: 'Budget & Limits',
                    subtitle: 'Set daily, weekly, monthly limits',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const BudgetScreen())),
                  ),
                ]),

                const Gap(20),
                const _SectionHeader(label: 'Data'),
                const Gap(8),
                _SettingsCard(children: [
                  _SettingsTile(
                    icon: Icons.download_rounded,
                    iconColor: context.appAccent,
                    title: 'Export All Data',
                    subtitle:
                        'Transactions + Scheduled → Downloads & share',
                    onTap: () => _exportAll(context, ref),
                  ),
                  _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.upload_rounded,
                    iconColor: context.appIncome,
                    title: 'Import from CSV',
                    subtitle:
                        'Pick one or more CSV files exported from CholeBature',
                    onTap: () => _importAll(context, ref),
                  ),
                ]),

                const Gap(20),
                const _SectionHeader(label: 'About'),
                const Gap(8),
                _SettingsCard(children: [
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: context.appTextSecondary,
                    title: 'Version',
                    subtitle: '3.4.12',
                  ),
                  _SettingsDivider(),
                  _SettingsTile(
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

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System default',
        ThemeMode.light  => 'Light',
        ThemeMode.dark   => 'Dark',
      };

  String _lockTypeLabel(LockType type) => switch (type) {
        LockType.none      => 'None',
        LockType.pin       => 'PIN',
        LockType.password  => 'Password',
        LockType.biometric => 'Biometric',
      };

  String _autoLockLabel(int seconds) {
    if (seconds == 0)   return 'Immediately';
    if (seconds < 60)   return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60} min';
    return '${seconds ~/ 3600}h';
  }

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final txAsync = ref.read(transactionListProvider);
    final txs = txAsync.when<List<Transaction>>(
        data: (v) => v, loading: () => [], error: (_, __) => []);

    final ftAsync = ref.read(futureTransactionProvider);
    final fts = ftAsync.when<List<FutureTransaction>>(
        data: (v) => v, loading: () => [], error: (_, __) => []);

    if (txs.isEmpty && fts.isEmpty) {
      _snack(context, 'Nothing to export', color: context.appBorrowed);
      return;
    }

    _snack(context, 'Preparing export…',
        color: context.appAccent, dur: 2);
    await ExportService.exportAll(
      transactions: txs,
      futureTransactions: fts,
    );
    if (context.mounted) {
      _snack(context, 'Files saved to Downloads & share sheet opened',
          color: context.appIncome, dur: 4);
    }
  }

  Future<void> _importAll(BuildContext context, WidgetRef ref) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurfaceElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Import from CSV',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(
          'Select one or more CSV files exported from CholeBature.\n\n'
          'You can import transactions AND scheduled transactions at the same time. '
          'Duplicates are skipped automatically.',
          style: GoogleFonts.dmSans(
              color: context.appTextSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent),
              child: Text('Choose Files',
                  style: GoogleFonts.dmSans(color: Colors.white))),
        ],
      ),
    );

    if (proceed != true || !context.mounted) return;

    final existingTx = ref.read(transactionListProvider).when<List<Transaction>>(
        data: (v) => v, loading: () => [], error: (_, __) => []);
    final existingFt =
        ref.read(futureTransactionProvider).when<List<FutureTransaction>>(
            data: (v) => v, loading: () => [], error: (_, __) => []);

    _snack(context, 'Opening file picker…',
        color: context.appAccent, dur: 1);

    final result = await ImportService.pickAndParseAll(
      existingTx: existingTx,
      existingFt: existingFt,
    );
    if (result == null || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ImportPreviewDialog(result: result),
    );
    if (confirm != true || !context.mounted) return;

    // Insert transactions
    final txNotifier = ref.read(transactionListProvider.notifier);
    for (final tx in result.transactions) {
      await txNotifier.add(tx);
    }

    // Insert future transactions
    final ftNotifier = ref.read(futureTransactionProvider.notifier);
    for (final ft in result.futureTransactions) {
      await ftNotifier.add(ft);
    }

    if (!context.mounted) return;
    final parts = <String>[];
    if (result.importedTx > 0) parts.add('${result.importedTx} transactions');
    if (result.importedFt > 0) parts.add('${result.importedFt} scheduled');
    final skipped = result.skippedTx + result.skippedFt;
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

  Future<void> _showSetLockSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SetLockSheet(),
    );
  }

  Future<void> _showAutoLockSheet(
      BuildContext context, WidgetRef ref, SecuritySettings settings) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AutoLockSheet(current: settings.autoLockSeconds),
    );
  }
}

// ── Import Preview Dialog ──────────────────────────────────────────────────────

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
              _PRow(icon: Icons.receipt_long_rounded,
                  color: context.appIncome,
                  label: 'Transactions to import',
                  value: '${result.importedTx}'),
            if (result.skippedTx > 0) ...[
              const Gap(8),
              _PRow(icon: Icons.skip_next_rounded,
                  color: context.appBorrowed,
                  label: 'Tx duplicates skipped',
                  value: '${result.skippedTx}'),
            ],
            if (result.importedFt > 0) ...[
              const Gap(8),
              _PRow(icon: Icons.schedule_rounded,
                  color: context.appAccent,
                  label: 'Scheduled to import',
                  value: '${result.importedFt}'),
            ],
            if (result.skippedFt > 0) ...[
              const Gap(8),
              _PRow(icon: Icons.skip_next_rounded,
                  color: context.appBorrowed,
                  label: 'Scheduled duplicates skipped',
                  value: '${result.skippedFt}'),
            ],
            if (result.failed > 0) ...[
              const Gap(8),
              _PRow(icon: Icons.error_outline_rounded,
                  color: context.appExpense,
                  label: 'Failed to parse',
                  value: '${result.failed}'),
            ],
            if (result.errors.isNotEmpty) ...[
              const Gap(10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appExpense.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: context.appExpense.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parse errors:',
                        style: GoogleFonts.dmSans(
                            color: context.appExpense,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const Gap(4),
                    ...result.errors.take(3).map((e) => Text('• $e',
                        style: GoogleFonts.dmSans(
                            color: context.appTextMuted, fontSize: 10))),
                    if (result.errors.length > 3)
                      Text('… and ${result.errors.length - 3} more',
                          style: GoogleFonts.dmSans(
                              color: context.appTextMuted, fontSize: 10)),
                  ],
                ),
              ),
            ],
            if (!result.hasAnything) ...[
              const Gap(12),
              Text('Nothing new to import — all entries already exist.',
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
                style:
                    GoogleFonts.dmSans(color: context.appTextSecondary))),
        if (result.hasAnything)
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appIncome),
              child: Text(
                'Import',
                style: GoogleFonts.dmSans(color: Colors.white),
              )),
      ],
    );
  }
}

class _PRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _PRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});
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

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
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

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 64),
        child: Divider(height: 1, color: context.appBorder),
      );
}

class _ThemeCycleButton extends StatelessWidget {
  final ThemeMode themeMode;
  final VoidCallback onCycle;
  const _ThemeCycleButton(
      {required this.themeMode, required this.onCycle});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onCycle,
        child: Container(
          width: 36, height: 36,
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
            color: context.appTextSecondary, size: 18,
          ),
        ),
      );
}

// ── Set Lock Sheet ─────────────────────────────────────────────────────────────

class _SetLockSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SetLockSheet> createState() => _SetLockSheetState();
}

class _SetLockSheetState extends ConsumerState<_SetLockSheet> {
  LockType _selectedType = LockType.pin;
  final _credCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure  = true;
  bool _saving   = false;
  bool _biometricAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final ok = await SecurityService.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = ok);
  }

  @override
  void dispose() {
    _credCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _error = null; _saving = true; });

    if (_selectedType == LockType.biometric) {
      final r = await SecurityService.authenticateWithBiometricResult();
      if (!mounted) return;
      if (r.success) {
        await ref.read(securitySettingsProvider.notifier).enableBiometric();
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          _saving = false;
          _error  = r.error ?? 'Biometric authentication failed.';
        });
      }
      return;
    }

    final cred    = _credCtrl.text;
    final confirm = _confirmCtrl.text;

    if (_selectedType == LockType.pin) {
      if (cred.length < 4 || cred.length > 6) {
        setState(() { _saving = false; _error = 'PIN must be 4–6 digits'; });
        return;
      }
      if (cred != confirm) {
        setState(() { _saving = false; _error = 'PINs do not match'; });
        return;
      }
    } else {
      if (cred.length < 4) {
        setState(() {
          _saving = false;
          _error = 'Password must be at least 4 characters';
        });
        return;
      }
      if (cred != confirm) {
        setState(() { _saving = false; _error = 'Passwords do not match'; });
        return;
      }
    }

    await ref.read(securitySettingsProvider.notifier).enable(_selectedType, cred);
    if (mounted) Navigator.pop(context);
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
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + kbh),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: context.appBorder,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const Gap(16),
            Text('Set App Lock',
                style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const Gap(16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LockChip(
                    type: LockType.pin,
                    icon: Icons.pin_rounded,
                    label: 'PIN',
                    selected: _selectedType,
                    onTap: () =>
                        setState(() => _selectedType = LockType.pin)),
                _LockChip(
                    type: LockType.password,
                    icon: Icons.key_rounded,
                    label: 'Password',
                    selected: _selectedType,
                    onTap: () =>
                        setState(() => _selectedType = LockType.password)),
                if (_biometricAvailable)
                  _LockChip(
                      type: LockType.biometric,
                      icon: Icons.fingerprint_rounded,
                      label: 'Biometric',
                      selected: _selectedType,
                      onTap: () => setState(
                          () => _selectedType = LockType.biometric)),
              ],
            ),
            const Gap(16),
            if (_selectedType == LockType.biometric)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(children: [
                  Icon(Icons.fingerprint_rounded,
                      color: context.appAccent, size: 28),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      'Tap "Enable Biometric" to scan your fingerprint or face.\n'
                      'Biometrics must be enrolled in your device Settings.',
                      style: GoogleFonts.dmSans(
                          color: context.appTextSecondary, fontSize: 13),
                    ),
                  ),
                ]),
              )
            else ...[
              TextField(
                controller: _credCtrl,
                obscureText: _obscure,
                keyboardType: _selectedType == LockType.pin
                    ? TextInputType.number
                    : TextInputType.text,
                style: GoogleFonts.dmSans(
                    color: context.appTextPrimary, fontSize: 16),
                decoration: InputDecoration(
                  labelText: _selectedType == LockType.pin
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
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const Gap(12),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                keyboardType: _selectedType == LockType.pin
                    ? TextInputType.number
                    : TextInputType.text,
                style: GoogleFonts.dmSans(
                    color: context.appTextPrimary, fontSize: 16),
                decoration: InputDecoration(
                  labelText: _selectedType == LockType.pin
                      ? 'Confirm PIN'
                      : 'Confirm password',
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: context.appTextMuted, size: 18),
                ),
              ),
            ],
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
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_selectedType == LockType.biometric
                        ? 'Enable Biometric'
                        : 'Enable Lock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockChip extends StatelessWidget {
  final LockType type, selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LockChip(
      {required this.type,
      required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isSel = selected == type;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSel
              ? context.appAccent.withValues(alpha: 0.15)
              : context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSel ? context.appAccent : context.appBorder,
              width: isSel ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: isSel ? context.appAccent : context.appTextMuted),
          const Gap(5),
          Text(label,
              style: GoogleFonts.dmSans(
                  color:
                      isSel ? context.appAccent : context.appTextSecondary,
                  fontSize: 12,
                  fontWeight:
                      isSel ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

// ── Auto-Lock Sheet ────────────────────────────────────────────────────────────

class _AutoLockSheet extends ConsumerWidget {
  final int current;
  const _AutoLockSheet({required this.current});

  static const _options = [
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
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2))),
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
                children: _options.map((o) {
                  final isSel = current == o.seconds;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: (isSel
                                ? context.appAccent
                                : context.appTextMuted)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.timer_rounded,
                          color: isSel
                              ? context.appAccent
                              : context.appTextMuted,
                          size: 18),
                    ),
                    title: Text(o.label,
                        style: GoogleFonts.dmSans(
                            color: isSel
                                ? context.appAccent
                                : context.appTextPrimary,
                            fontSize: 14,
                            fontWeight: isSel
                                ? FontWeight.w600
                                : FontWeight.w400)),
                    trailing: isSel
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