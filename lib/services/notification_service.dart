import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/future_transaction_model.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    // Request exact alarm permission on Android 12+ (API 31+).
    // This is a best-effort request — the user may deny it, in which case
    // scheduleReminders() falls back to inexact alarms automatically.
    await android?.requestExactAlarmsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedule all reminders for a FutureTransaction.
  /// Cancels any existing ones first.
  static Future<void> scheduleReminders(FutureTransaction ft) async {
    await cancelReminders(ft.id);

    for (final offsetMinutes in ft.reminderOffsets) {
      final triggerAt =
          ft.nextDue.subtract(Duration(minutes: offsetMinutes));
      if (triggerAt.isBefore(DateTime.now())) continue;

      final notifId = _notifId(ft.id, offsetMinutes);
      final body = _buildBody(ft, offsetMinutes);

      // Try exact alarm first; fall back to inexact if the permission is
      // denied (throws PlatformException on Android 12+ when not granted).
      await _scheduleWithFallback(notifId, ft.title, body, triggerAt, ft.id);
    }
  }

  static String _buildBody(FutureTransaction ft, int offsetMinutes) {
    final amountStr = ft.amount > 0
        ? '₹${ft.amount.toStringAsFixed(0)}'
        : 'Variable amount';
    if (offsetMinutes == 0) return '$amountStr — due now!';
    if (offsetMinutes < 60) return '$amountStr — due in ${offsetMinutes}m';
    if (offsetMinutes < 1440) {
      return '$amountStr — due in ${offsetMinutes ~/ 60}h';
    }
    return '$amountStr — due in ${offsetMinutes ~/ 1440} day(s)';
  }

  static Future<void> _scheduleWithFallback(
    int notifId,
    String title,
    String body,
    DateTime triggerAt,
    String payload,
  ) async {
    final tzTime = tz.TZDateTime.from(triggerAt, tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'future_transactions',
        'Scheduled Transactions',
        channelDescription: 'Reminders for scheduled transactions',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    // First attempt: exact alarm (requires SCHEDULE_EXACT_ALARM permission).
    try {
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      return; // success — done
    } catch (_) {
      // Exact alarm permission denied or unavailable — fall through to inexact.
    }

    // Second attempt: inexact alarm (always permitted, may fire a few minutes
    // late but still works reliably).
    try {
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (_) {
      // If even inexact fails (e.g. notifications fully disabled), silently
      // swallow — the transaction will still be saved, just without a reminder.
    }
  }

  /// Cancel all reminders for a given future transaction id.
  static Future<void> cancelReminders(String ftId) async {
    const possibleOffsets = [0, 15, 30, 60, 120, 180, 360, 720, 1440, 2880];
    for (final offset in possibleOffsets) {
      await _plugin.cancel(_notifId(ftId, offset));
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Deterministic int ID from a string id + offset.
  static int _notifId(String ftId, int offsetMinutes) {
    return (ftId.hashCode ^ (offsetMinutes * 31)).abs() % 2147483647;
  }
}