import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/database/database.dart' hide StreakReward;
import 'streak_service.dart';

/// ID der Abend-Reminder-Notification. Konstant, damit Re-Schedules die
/// vorherige Planung sauber überschreiben.
const int kReminderNotificationId = 100;

/// Channel auf Android.
const String _channelId = 'streak_reminder';

/// Mindest-Streak, ab dem überhaupt erinnert wird.
const int kReminderMinStreak = 3;

/// Lokale Uhrzeit des Reminders (HH, MM).
const int kReminderHour = 20;
const int kReminderMinute = 0;

class ReminderService {
  ReminderService(this._db, this._streaks);

  final AppDatabase _db;
  final StreakService _streaks;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final localName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localName));
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Streak-Erinnerung',
        description: 'Abend-Reminder, wenn du deinen Streak heute noch nicht verlängert hast.',
        importance: Importance.defaultImportance,
      ),
    );
    _initialized = true;
  }

  /// Fragt die OS-Permission an. Auf Android 13+ ist das nötig, sonst No-Op.
  /// Idempotent — der OS-Dialog kommt nur einmal pro App-Install.
  Future<void> requestPermissionIfNeeded() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Plant — oder storniert — den Abend-Reminder. Logik:
  /// - Toggle aus → storniert alles, return.
  /// - currentStreak < kReminderMinStreak → storniert.
  /// - heute schon eine Session abgeschlossen → storniert.
  /// - sonst → plant für heute 20:00 (lokal) oder morgen 20:00, falls
  ///   die heutige Uhrzeit schon vorbei ist.
  Future<void> rescheduleReminder(String playerId) async {
    await initialize();
    final enabled = await _db.getReminderEnabled(playerId);
    if (!enabled) {
      await _plugin.cancel(kReminderNotificationId);
      return;
    }
    final streak = await _streaks.currentStreak(playerId);
    if (streak < kReminderMinStreak) {
      await _plugin.cancel(kReminderNotificationId);
      return;
    }
    final finishedAts = await _db.finishedAtsForPlayer(playerId);
    if (_hasFinishedToday(finishedAts)) {
      await _plugin.cancel(kReminderNotificationId);
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      kReminderHour,
      kReminderMinute,
    );
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      kReminderNotificationId,
      'Streak retten 🔥',
      'Du hast einen Streak von $streak Tagen — ein Quiz reicht, damit er bleibt.',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Streak-Erinnerung',
          channelDescription:
              'Abend-Reminder, wenn du deinen Streak heute noch nicht verlängert hast.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel() async {
    await initialize();
    await _plugin.cancel(kReminderNotificationId);
  }

  bool _hasFinishedToday(List<int> finishedAts) {
    final now = DateTime.now();
    for (final ms in finishedAts) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        return true;
      }
    }
    return false;
  }
}
