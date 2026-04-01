// Notifications are shown only on explicit demand (e.g. when the app checks
// for overdue items on resume). We do NOT show a notification immediately when
// a transaction is saved — that was causing the "notification fires right away"
// bug.
//
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/future_transaction_model.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _androidDetails = AndroidNotificationDetails(
    'cholebature_general',
    'General Notifications',
    channelDescription: 'General app notifications',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher',
  );

  static const _notifDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(
          alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  /// Called when a FutureTransaction is saved/updated.
  /// Does NOT fire an immediate notification — that would confuse the user.
  /// Instead, call [checkAndNotifyOverdue] from HomeShell on app resume
  /// to show notifications for actually-overdue items.
  static Future<void> scheduleReminders(FutureTransaction ft) async {
    // Intentionally a no-op at save time.
    // Overdue checks happen in checkAndNotifyOverdue().
  }

  /// Cancel any notification we may have shown for this transaction.
  static Future<void> cancelReminders(String ftId) async {
    try {
      await _plugin.cancel(_notifId(ftId));
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Call this from HomeShell.didChangeAppLifecycleState (resumed) and on
  /// initState to notify the user about overdue transactions.
  static Future<void> checkAndNotifyOverdue(
      List<FutureTransaction> all) async {
    final now = DateTime.now();
    for (final ft in all) {
      if (ft.isOverdue) {
        final amountStr = ft.amount > 0
            ? '₹${ft.amount.toStringAsFixed(0)}'
            : 'Variable amount';
        try {
          await _plugin.show(
            _notifId(ft.id),
            '⏰ Overdue: ${ft.title}',
            '$amountStr was due on '
                '${ft.nextDue.day}/${ft.nextDue.month}/${ft.nextDue.year}',
            _notifDetails,
            payload: ft.id,
          );
        } catch (_) {}
      }
    }
  }

  static int _notifId(String ftId) =>
      ftId.hashCode.abs() % 2147483647;
}