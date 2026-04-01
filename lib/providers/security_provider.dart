import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/security_model.dart';
import '../services/security_service.dart';

final securitySettingsProvider =
    StateNotifierProvider<SecuritySettingsNotifier, SecuritySettings>(
  (ref) => SecuritySettingsNotifier(),
);

class SecuritySettingsNotifier extends StateNotifier<SecuritySettings> {
  SecuritySettingsNotifier() : super(const SecuritySettings()) {
    _load();
  }

  Future<void> _load() async {
    final settings = await SecurityService.loadSettings();
    if (mounted) state = settings;
  }

  Future<void> enable(LockType type, String credential) async {
    // Pass isPin=true when the type is PIN so the digit count gets stored
    await SecurityService.setCredential(
      credential,
      isPin: type == LockType.pin,
    );
    final updated = state.copyWith(enabled: true, lockType: type);
    await SecurityService.saveSettings(updated);
    if (mounted) state = updated;
  }

  Future<void> disable() async {
    await SecurityService.disable();
    final updated = state.copyWith(enabled: false, lockType: LockType.none);
    if (mounted) state = updated;
  }

  Future<void> enableBiometric() async {
    final updated =
        state.copyWith(enabled: true, lockType: LockType.biometric);
    await SecurityService.saveSettings(updated);
    if (mounted) state = updated;
  }

  Future<void> setAutoLockTimeout(int seconds) async {
    final updated = state.copyWith(autoLockSeconds: seconds);
    await SecurityService.saveSettings(updated);
    if (mounted) state = updated;
  }
}

// Whether the app is currently showing the lock screen
final appLockedProvider = StateProvider<bool>((ref) => false);