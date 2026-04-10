import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/future_transaction_model.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _tzInitialized = false;

  static const _androidDetails = AndroidNotificationDetails(
    'cholebature_reminders',
    'Transaction Reminders',
    channelDescription: 'Reminders for scheduled transactions',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    enableVibration: true,
    playSound: true,
  );

  static const _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone data
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }

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
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Request exact alarm permission on Android 12+
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  /// Schedule a notification for each reminderOffset of the FutureTransaction.
  /// Each scheduled notification fires at: nextDue - offset minutes.
  static Future<void> scheduleReminders(FutureTransaction ft) async {
    // Cancel existing reminders for this ft first
    await cancelReminders(ft.id);

    // Don't schedule if paused or already past
    if (ft.status == FutureStatus.paused) return;

    final now = DateTime.now();
    final offsets = ft.reminderOffsets.isEmpty ? [0] : ft.reminderOffsets;

    for (int i = 0; i < offsets.length; i++) {
      final offset = offsets[i];
      final fireTime = ft.nextDue.subtract(Duration(minutes: offset));

      // Skip if the fire time is in the past
      if (fireTime.isBefore(now)) continue;

      final notifId = _notifId(ft.id, i);

      String title;
      String body;
      final amtStr =
          ft.amount > 0 ? '₹${ft.amount.toStringAsFixed(0)}' : 'Variable amount';

      if (offset == 0) {
        title = '⏰ Due Now: ${ft.title}';
        body = '$amtStr is due today';
      } else if (offset < 60) {
        title = '⏰ Due in ${offset}min: ${ft.title}';
        body = '$amtStr due at ${_timeStr(ft.nextDue)}';
      } else if (offset < 1440) {
        title = '⏰ Due in ${offset ~/ 60}h: ${ft.title}';
        body = '$amtStr due at ${_timeStr(ft.nextDue)}';
      } else {
        title = '📅 Tomorrow: ${ft.title}';
        body = '$amtStr due ${ft.nextDue.day}/${ft.nextDue.month}';
      }

      try {
        await _plugin.zonedSchedule(
          notifId,
          title,
          body,
          tz.TZDateTime.from(fireTime, tz.local),
          _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: ft.id,
        );
      } catch (e) {
        // Fallback: try inexact if exact alarms not permitted
        try {
          await _plugin.zonedSchedule(
            notifId,
            title,
            body,
            tz.TZDateTime.from(fireTime, tz.local),
            _details,
            androidScheduleMode: AndroidScheduleMode.inexact,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: ft.id,
          );
        } catch (_) {}
      }
    }
  }

  static Future<void> cancelReminders(String ftId) async {
    // Cancel up to 8 reminder slots per ft
    for (int i = 0; i < 8; i++) {
      try {
        await _plugin.cancel(_notifId(ftId, i));
      } catch (_) {}
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Called on app launch / resume — shows immediate notifications for
  /// overdue items that haven't been notified yet this session.
  static final _notifiedIds = <String>{};

  static Future<void> checkAndNotifyOverdue(
      List<FutureTransaction> all) async {
    for (final ft in all) {
      if (!ft.isOverdue) continue;
      if (_notifiedIds.contains(ft.id)) continue;
      _notifiedIds.add(ft.id);
      final amt =
          ft.amount > 0 ? '₹${ft.amount.toStringAsFixed(0)}' : 'Variable amount';
      try {
        await _plugin.show(
          _notifId(ft.id, 99), // slot 99 = overdue immediate
          '⚠️ Overdue: ${ft.title}',
          '$amt — was due ${ft.nextDue.day}/${ft.nextDue.month}/${ft.nextDue.year}',
          _details,
          payload: ft.id,
        );
      } catch (_) {}
    }
  }

  // Unique notification ID: combine ft hashCode with slot index
  static int _notifId(String ftId, int slot) =>
      (ftId.hashCode.abs() % 10000000) + slot;

  static String _timeStr(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }
}