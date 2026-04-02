// lib/services/security_service.dart
// Biometric REMOVED completely.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/security_model.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

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

    LockType type;
    if (typeStr == null || typeStr == 'none' || typeStr == 'biometric') {
      type = LockType.none;
    } else {
      type = LockType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => LockType.none,
      );
    }

    // If was biometric, treat as disabled
    final isEnabled = enabled == 'true' && type != LockType.none;

    return SecuritySettings(
      enabled: isEnabled,
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

  static String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}