import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/security_model.dart';
import '../providers/security_provider.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _inputCtrl = TextEditingController();
  String _pinInput = '';
  String? _error;
  bool _obscure   = true;
  bool _loading   = false;

  // Null until _init() completes — prevents flash of wrong UI.
  LockType? _lockType;

  // Actual PIN length: read from the stored hash by trying lengths 4–6.
  // We determine this by attempting verification at each length during init.
  // Simpler approach: we store the PIN length separately.
  // Even simpler: just show 6 dots always but only fill up to entered count.
  // BEST approach: store pin length in secure storage at set-time, read here.
  int _pinLength = 6; // default; overridden once we load the real length

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final settings = await SecurityService.loadSettings();
    // Read the stored PIN length (if any)
    final storedLen = await SecurityService.loadPinLength();
    if (!mounted) return;
    setState(() {
      _lockType  = settings.lockType;
      _pinLength = storedLen ?? 6;
      _loading   = false;
    });
    if (settings.lockType == LockType.biometric) {
      await _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    setState(() => _loading = true);
    final result = await SecurityService.authenticateWithBiometricResult();
    if (!mounted) return;
    if (result.success) {
      _unlock();
    } else {
      setState(() {
        _loading  = false;
        _error    = result.error ?? 'Biometric failed. Use PIN or password.';
        _lockType = LockType.pin;
      });
    }
  }

  Future<void> _verifyInput(String input) async {
    setState(() => _loading = true);
    final ok = await SecurityService.verifyCredential(input);
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      setState(() {
        _loading   = false;
        _error     =
            'Incorrect ${_lockType == LockType.pin ? 'PIN' : 'password'}. Try again.';
        _pinInput  = '';
        _inputCtrl.clear();
      });
    }
  }

  void _unlock() {
    ref.read(appLockedProvider.notifier).state = false;
  }

  void _onDigit(String d) {
    if (_pinInput.length >= _pinLength) return;
    setState(() {
      _pinInput += d;
      _error = null;
    });
    // Try verifying once we have enough digits.
    // For 4-digit PIN: verify on 4th digit.
    // For 5-digit PIN: verify on 5th digit.
    // For 6-digit PIN: verify on 6th digit.
    if (_pinInput.length == _pinLength) {
      _verifyInput(_pinInput);
    } else if (_pinInput.length >= 4 && _pinLength > _pinInput.length) {
      // Try early in case user has a shorter PIN than _pinLength
      _tryPinEarly(_pinInput);
    }
  }

  Future<void> _tryPinEarly(String pin) async {
    final ok = await SecurityService.verifyCredential(pin);
    if (!mounted) return;
    if (ok) _unlock();
    // else: wait for more digits
  }

  void _onBackspace() {
    if (_pinInput.isEmpty) return;
    setState(() {
      _pinInput = _pinInput.substring(0, _pinInput.length - 1);
      _error    = null;
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.appAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded,
                      color: context.appAccent, size: 36),
                ),
                const Gap(20),
                Text(
                  'App Locked',
                  style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(8),
                Text(
                  _lockType == null
                      ? 'Checking lock settings…'
                      : _lockType == LockType.biometric
                          ? 'Use biometric to unlock'
                          : _lockType == LockType.pin
                              ? 'Enter your PIN'
                              : 'Enter your password',
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary, fontSize: 14),
                ),
                if (_error != null) ...[
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.appExpense.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              context.appExpense.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.dmSans(
                          color: context.appExpense, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const Gap(32),
                if (_loading || _lockType == null)
                  CircularProgressIndicator(
                      color: context.appAccent,
                      strokeCap: StrokeCap.round)
                else if (_lockType == LockType.biometric)
                  _BiometricButton(onTap: _tryBiometric)
                else if (_lockType == LockType.pin)
                  _PinInput(
                    pinInput: _pinInput,
                    pinLength: _pinLength,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                  )
                else if (_lockType == LockType.password)
                  _PasswordInput(
                    controller: _inputCtrl,
                    obscure: _obscure,
                    onToggleObscure: () =>
                        setState(() => _obscure = !_obscure),
                    onSubmit: _verifyInput,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _BiometricButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BiometricButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: context.appAccent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
              color: context.appAccent.withValues(alpha: 0.4), width: 2),
        ),
        child: Icon(Icons.fingerprint_rounded,
            color: context.appAccent, size: 44),
      ),
    );
  }
}

class _PinInput extends StatelessWidget {
  final String pinInput;   // the digits typed so far
  final int pinLength;     // total expected digits (4, 5, or 6)
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _PinInput({
    required this.pinInput,
    required this.pinLength,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Dot indicators: exactly pinLength dots ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pinLength, (i) {
            final filled = i < pinInput.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? context.appAccent
                    : Colors.transparent,
                border: Border.all(
                  color: filled
                      ? context.appAccent
                      : context.appBorder,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const Gap(32),
        // ── Number pad ──
        ...[
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ].map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((key) {
                  if (key.isEmpty) return const SizedBox(width: 80);
                  return GestureDetector(
                    onTap: () =>
                        key == '⌫' ? onBackspace() : onDigit(key),
                    child: Container(
                      width: 72,
                      height: 72,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Center(
                        child: Text(
                          key,
                          style: GoogleFonts.dmSans(
                            color: key == '⌫'
                                ? context.appExpense
                                : context.appTextPrimary,
                            fontSize: key == '⌫' ? 20 : 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )),
      ],
    );
  }
}

class _PasswordInput extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final void Function(String) onSubmit;

  const _PasswordInput({
    required this.controller,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: true,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          style: GoogleFonts.dmSans(color: context.appTextPrimary),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline_rounded,
                color: context.appTextMuted, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: context.appTextMuted,
                  size: 18),
              onPressed: onToggleObscure,
            ),
          ),
          onSubmitted: onSubmit,
        ),
        const Gap(16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => onSubmit(controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: context.appAccent),
            child: const Text('Unlock'),
          ),
        ),
      ],
    );
  }
}