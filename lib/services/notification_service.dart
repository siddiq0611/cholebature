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
      String body;
      if (offsetMinutes == 0) {
        body = '₹${ft.amount.toStringAsFixed(0)} — due now!';
      } else if (offsetMinutes < 60) {
        body = '₹${ft.amount.toStringAsFixed(0)} — due in ${offsetMinutes}m';
      } else if (offsetMinutes < 1440) {
        body =
            '₹${ft.amount.toStringAsFixed(0)} — due in ${offsetMinutes ~/ 60}h';
      } else {
        body =
            '₹${ft.amount.toStringAsFixed(0)} — due in ${offsetMinutes ~/ 1440} day(s)';
      }

      await _plugin.zonedSchedule(
        notifId,
        ft.title,
        body,
        tz.TZDateTime.from(triggerAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'future_transactions',
            'Scheduled Transactions',
            channelDescription: 'Reminders for scheduled transactions',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: ft.id,
      );
    }
  }

  /// Cancel all reminders for a given future transaction id.
  static Future<void> cancelReminders(String ftId) async {
    // We use offsets 0, 30, 60, 120, 1440 as standard; cancel a range
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
    // Use hash of id + offset, keep within int32 range
    return (ftId.hashCode ^ (offsetMinutes * 31)).abs() % 2147483647;
  }
}