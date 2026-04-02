// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/future_transaction_model.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _androidDetails = AndroidNotificationDetails(
    'cholebature_overdue',
    'Overdue Reminders',
    channelDescription: 'Notifies when a scheduled transaction is overdue',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const _details = NotificationDetails(
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
        const InitializationSettings(android: android, iOS: ios));
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  // No-op: we don't schedule alarms — overdue check fires on app resume
  static Future<void> scheduleReminders(FutureTransaction ft) async {}

  static Future<void> cancelReminders(String ftId) async {
    try { await _plugin.cancel(_id(ftId)); } catch (_) {}
  }

  static Future<void> cancelAll() async {
    try { await _plugin.cancelAll(); } catch (_) {}
  }

  /// Call from HomeShell on initState and on app resume.
  /// Shows one notification per overdue transaction (once per session).
  static final _notifiedIds = <String>{};

  static Future<void> checkAndNotifyOverdue(
      List<FutureTransaction> all) async {
    for (final ft in all) {
      if (!ft.isOverdue) continue;
      if (_notifiedIds.contains(ft.id)) continue;
      _notifiedIds.add(ft.id);
      final amt = ft.amount > 0
          ? '₹${ft.amount.toStringAsFixed(0)}'
          : 'Variable amount';
      try {
        await _plugin.show(
          _id(ft.id),
          '⏰ Overdue: ${ft.title}',
          '$amt — was due ${ft.nextDue.day}/${ft.nextDue.month}/${ft.nextDue.year}',
          _details,
          payload: ft.id,
        );
      } catch (_) {}
    }
  }

  static int _id(String ftId) => ftId.hashCode.abs() % 2147483647;
}