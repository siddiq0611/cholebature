enum LockType { none, pin, password }

class SecuritySettings {
  final LockType lockType;
  final bool enabled;
  final int autoLockSeconds; // 0 = immediately on background

  const SecuritySettings({
    this.lockType = LockType.none,
    this.enabled = false,
    this.autoLockSeconds = 30,
  });

  SecuritySettings copyWith({
    LockType? lockType,
    bool? enabled,
    int? autoLockSeconds,
  }) =>
      SecuritySettings(
        lockType: lockType ?? this.lockType,
        enabled: enabled ?? this.enabled,
        autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      );
}