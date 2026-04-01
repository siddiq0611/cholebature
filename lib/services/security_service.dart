import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import '../models/security_model.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final _localAuth = LocalAuthentication();

  static const _kEnabled   = 'lock_enabled';
  static const _kType      = 'lock_type';
  static const _kHash      = 'lock_hash';
  static const _kTimeout   = 'lock_timeout_seconds';
  static const _kPinLength = 'lock_pin_length';

  // ─── Read ──────────────────────────────────────────────────────────────────

  static Future<SecuritySettings> loadSettings() async {
    final enabled    = await _storage.read(key: _kEnabled);
    final typeStr    = await _storage.read(key: _kType);
    final timeoutStr = await _storage.read(key: _kTimeout);

    final type = typeStr == null
        ? LockType.none
        : LockType.values.firstWhere(
            (t) => t.name == typeStr,
            orElse: () => LockType.none,
          );

    return SecuritySettings(
      enabled: enabled == 'true',
      lockType: type,
      autoLockSeconds: int.tryParse(timeoutStr ?? '30') ?? 30,
    );
  }

  static Future<int?> loadPinLength() async {
    final raw = await _storage.read(key: _kPinLength);
    return raw != null ? int.tryParse(raw) : null;
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  static Future<void> saveSettings(SecuritySettings settings) async {
    await _storage.write(key: _kEnabled, value: settings.enabled.toString());
    await _storage.write(key: _kType,    value: settings.lockType.name);
    await _storage.write(key: _kTimeout, value: settings.autoLockSeconds.toString());
  }

  static Future<void> setCredential(String value, {bool isPin = false}) async {
    await _storage.write(key: _kHash, value: _hash(value));
    if (isPin) {
      await _storage.write(key: _kPinLength, value: value.length.toString());
    } else {
      await _storage.delete(key: _kPinLength);
    }
  }

  static Future<void> disable() async {
    await _storage.write(key: _kEnabled,  value: 'false');
    await _storage.write(key: _kType,     value: LockType.none.name);
    await _storage.delete(key: _kHash);
    await _storage.delete(key: _kPinLength);
  }

  // ─── Verify ────────────────────────────────────────────────────────────────

  static Future<bool> verifyCredential(String input) async {
    final stored = await _storage.read(key: _kHash);
    if (stored == null) return false;
    return _hash(input) == stored;
  }

  // ─── Biometric ─────────────────────────────────────────────────────────────
  // NOTE: MainActivity MUST extend FlutterFragmentActivity (not FlutterActivity)
  // for local_auth to work on Android. See android/app/src/main/kotlin/.../MainActivity.kt

  static Future<bool> isBiometricAvailable() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Returns (success, errorMessage).
  static Future<({bool success, String? error})>
      authenticateWithBiometricResult() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access CholeBature',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: false,
        ),
      );
      return (success: ok, error: ok ? null : 'Authentication was cancelled.');
    } on PlatformException catch (e) {
      return (success: false, error: _errMsg(e));
    } catch (e) {
      return (success: false, error: 'Unexpected error: $e');
    }
  }

  static String _errMsg(PlatformException e) {
    switch (e.code) {
      case auth_error.notAvailable:
        return 'Biometric hardware is not available on this device.';
      case auth_error.notEnrolled:
        return 'No fingerprints enrolled. Go to Settings → Biometrics and add one.';
      case auth_error.lockedOut:
        return 'Too many failed attempts. Wait 30 seconds and try again.';
      case auth_error.permanentlyLockedOut:
        return 'Biometrics permanently locked. Use PIN or Password instead.';
      case auth_error.passcodeNotSet:
        return 'No device screen lock set. Enable one in device Settings first.';
      default:
        return e.message ?? 'Biometric auth failed (${e.code}).';
    }
  }

  static Future<bool> authenticateWithBiometric() async =>
      (await authenticateWithBiometricResult()).success;

  static String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}