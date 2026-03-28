import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../models/security_model.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final _localAuth = LocalAuthentication();

  // Storage keys
  static const _kEnabled = 'lock_enabled';
  static const _kType = 'lock_type';
  static const _kHash = 'lock_hash';
  static const _kTimeout = 'lock_timeout_seconds';

  // ─── Read settings ─────────────────────────────────────────────────────────

  static Future<SecuritySettings> loadSettings() async {
    final enabled = await _storage.read(key: _kEnabled);
    final typeStr = await _storage.read(key: _kType);
    final timeoutStr = await _storage.read(key: _kTimeout);

    LockType type = LockType.none;
    if (typeStr != null) {
      type = LockType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => LockType.none,
      );
    }

    return SecuritySettings(
      enabled: enabled == 'true',
      lockType: type,
      autoLockSeconds: int.tryParse(timeoutStr ?? '30') ?? 30,
    );
  }

  // ─── Save settings ─────────────────────────────────────────────────────────

  static Future<void> saveSettings(SecuritySettings settings) async {
    await _storage.write(
        key: _kEnabled, value: settings.enabled.toString());
    await _storage.write(key: _kType, value: settings.lockType.name);
    await _storage.write(
        key: _kTimeout, value: settings.autoLockSeconds.toString());
  }

  static Future<void> setCredential(String value) async {
    final hash = _hash(value);
    await _storage.write(key: _kHash, value: hash);
  }

  static Future<void> disable() async {
    await _storage.write(key: _kEnabled, value: 'false');
    await _storage.write(key: _kType, value: LockType.none.name);
    await _storage.delete(key: _kHash);
  }

  // ─── Verify ────────────────────────────────────────────────────────────────

  static Future<bool> verifyCredential(String input) async {
    final stored = await _storage.read(key: _kHash);
    if (stored == null) return false;
    return _hash(input) == stored;
  }

  // ─── Biometric ─────────────────────────────────────────────────────────────

  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access CholeBature',
        options: const AuthenticationOptions(
          biometricOnly: false, // allows device PIN as fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}