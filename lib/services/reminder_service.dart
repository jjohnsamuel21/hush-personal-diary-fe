import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// Wraps flutter_local_notifications for daily writing reminders.
// Call ReminderService.init() once in main() before runApp().
class ReminderService {
  static const int _dailyReminderId = 1;
  static const String _prefEnabled = 'hush_reminder_enabled';
  static const String _prefHour = 'hush_reminder_hour';
  static const String _prefMinute = 'hush_reminder_minute';

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Initialises the plugin and timezone database.
  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    // Re-schedule if there was an active reminder before the app restarted
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefEnabled) ?? false) {
      final hour = prefs.getInt(_prefHour) ?? 20;
      final minute = prefs.getInt(_prefMinute) ?? 0;
      await scheduleDaily(TimeOfDay(hour: hour, minute: minute));
    }
  }

  /// Schedules a daily notification at [time] and persists the setting.
  static Future<void> scheduleDaily(TimeOfDay time) async {
    // Request runtime permission on Android 13+
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    // Cancel any existing reminder before scheduling a new one
    await _plugin.cancel(id: _dailyReminderId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: 'Time to write',
      body: "Open Hush and capture today's thoughts.",
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'hush_reminders',
          'Writing reminders',
          channelDescription: 'Daily prompts to write in your diary',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily at same time
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, true);
    await prefs.setInt(_prefHour, time.hour);
    await prefs.setInt(_prefMinute, time.minute);
  }

  /// Cancels the daily reminder and clears the setting.
  static Future<void> cancelAll() async {
    await _plugin.cancel(id: _dailyReminderId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false;
  }

  static Future<TimeOfDay> getSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_prefHour) ?? 20,
      minute: prefs.getInt(_prefMinute) ?? 0,
    );
  }
}
