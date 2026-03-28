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
  bool _obscure = true;
  bool _loading = false;
  LockType _lockType = LockType.none;

  // The actual PIN length stored — we don't know it upfront, so we try
  // to verify after 4 digits if correct, or keep accepting up to 6.
  // We verify on each digit ≥ 4 attempt but only auto-submit on match.
  int _pinMaxLength = 6; // default display — actual check drives flow

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final settings = await SecurityService.loadSettings();
    if (mounted) setState(() => _lockType = settings.lockType);
    if (settings.lockType == LockType.biometric) {
      await _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    setState(() => _loading = true);
    final success = await SecurityService.authenticateWithBiometric();
    if (success && mounted) {
      _unlock();
    } else if (mounted) {
      setState(() {
        _loading = false;
        _error = 'Biometric failed. Enter your PIN or password below.';
        _lockType = LockType.pin;
      });
    }
  }

  Future<void> _verifyInput(String input) async {
    setState(() => _loading = true);
    final ok = await SecurityService.verifyCredential(input);
    if (ok && mounted) {
      _unlock();
    } else if (mounted) {
      setState(() {
        _loading = false;
        _error =
            'Incorrect ${_lockType == LockType.pin ? 'PIN' : 'password'}. Try again.';
        _pinInput = '';
        _inputCtrl.clear();
      });
    }
  }

  void _unlock() {
    ref.read(appLockedProvider.notifier).state = false;
  }

  void _onDigit(String d) {
    // Allow up to 6 digits
    if (_pinInput.length >= 6) return;
    setState(() {
      _pinInput += d;
      _error = null;
    });

    // Try verifying at every digit position ≥ 4.
    // This handles both 4-digit and 6-digit PINs seamlessly:
    // - 4-digit PIN: verifies on 4th digit, unlocks immediately if correct
    // - 6-digit PIN: fails silently on 4th/5th, verifies on 6th
    if (_pinInput.length >= 4) {
      _tryPinAttempt(_pinInput);
    }
  }

  Future<void> _tryPinAttempt(String pin) async {
    // Don't show loading spinner for intermediate attempts to avoid flicker
    final ok = await SecurityService.verifyCredential(pin);
    if (!mounted) return;

    if (ok) {
      _unlock();
    } else if (pin.length == 6) {
      // Exhausted all digits — show error
      setState(() {
        _error = 'Incorrect PIN. Try again.';
        _pinInput = '';
      });
    }
    // For 4 or 5 digits wrong: stay silent and wait for more digits
  }

  void _onBackspace() {
    if (_pinInput.isEmpty) return;
    setState(() {
      _pinInput = _pinInput.substring(0, _pinInput.length - 1);
      _error = null;
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
                  _lockType == LockType.biometric
                      ? 'Use biometric to unlock'
                      : _lockType == LockType.pin
                          ? 'Enter your PIN'
                          : 'Enter your password',
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary, fontSize: 14),
                ),
                if (_error != null) ...[
                  const Gap(12),
                  Text(
                    _error!,
                    style: GoogleFonts.dmSans(
                        color: context.appExpense, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
                const Gap(32),

                if (_loading)
                  CircularProgressIndicator(
                      color: context.appAccent,
                      strokeCap: StrokeCap.round)
                else if (_lockType == LockType.biometric)
                  _BiometricButton(onTap: _tryBiometric)
                else if (_lockType == LockType.pin)
                  _PinInput(
                    pinLength: _pinInput.length,
                    maxLength: _pinMaxLength,
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
  final int pinLength;
  final int maxLength;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _PinInput({
    required this.pinLength,
    required this.maxLength,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Dot indicators — show up to maxLength dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxLength, (i) {
            final filled = i < pinLength;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? context.appAccent : Colors.transparent,
                border: Border.all(
                  color:
                      filled ? context.appAccent : context.appBorder,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const Gap(32),
        // Number pad
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
                    onTap: () {
                      if (key == '⌫') {
                        onBackspace();
                      } else {
                        onDigit(key);
                      }
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: context.appBorder),
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