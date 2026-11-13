import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notif_sound.dart';
import 'train_reminder.dart';

/// The System's own nudges: today's quest board, a streak about to break and
/// the weekly missions closing. All three are plain repeating local
/// notifications, so they need no backend and survive a reboot.
///
/// The daily nudge is a repeating time match; the streak one only exists while
/// the hunter has a streak, and the weekly one repeats on the last day of the
/// hunter's week.
class SystemReminder {
  SystemReminder._();
  static final SystemReminder instance = SystemReminder._();

  static const dailyId = 2100;
  static const streakId = 2200;
  static const weeklyId = 2300;

  /// Late enough to be a last call, early enough to still train.
  static const streakMinuteOfDay = 21 * 60;
  static const weeklyMinuteOfDay = 18 * 60;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool enabled = true;
  Future<void> _queue = Future.value();
  String _applied = '';

  Future<void> _serial(Future<void> Function() job) =>
      _queue = _queue.then((_) => job()).catchError((Object e) => debugPrint('Aviso del Sistema: $e'));

  AndroidNotificationDetails get _android => AndroidNotificationDetails(
        NotifSound.channelOf('system_reminder', SoundGroup.train),
        'System reminders',
        channelDescription: 'Daily quests, streak at risk and weekly missions.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: NotifSound.plays(SoundGroup.train),
        sound: NotifSound.soundOf(SoundGroup.train),
      );

  DarwinNotificationDetails get _darwin => const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      );

  Future<void> cancel() => _serial(() async {
        _applied = '';
        await _cancelAll();
      });

  Future<void> _cancelAll() async {
    if (!enabled) return;
    for (final id in const [dailyId, streakId, weeklyId]) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {}
    }
  }

  Future<void> schedule({
    required bool daily,
    required int minuteOfDay,
    required bool streak,
    required bool weekly,
    required int weekEndWeekday,
  }) =>
      _serial(() => _schedule(daily, minuteOfDay, streak, weekly, weekEndWeekday));

  Future<void> _schedule(
    bool daily,
    int minuteOfDay,
    bool streak,
    bool weekly,
    int weekEndWeekday,
  ) async {
    if (!enabled) return;
    final at = minuteOfDay.clamp(0, 24 * 60 - 1);
    final key = '${daily ? 1 : 0}|$at|${streak ? 1 : 0}|${weekly ? 1 : 0}|$weekEndWeekday';
    if (key == _applied) return;
    _applied = key;
    await _cancelAll();
    final mode = await reminderMode(_plugin);

    Future<void> put(int id, DateTime when, String title, String body, DateTimeComponents? every) async {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: atLocal(when),
          notificationDetails: NotificationDetails(android: _android, iOS: _darwin),
          androidScheduleMode: mode,
          matchDateTimeComponents: every,
        );
      } catch (e) {
        debugPrint('No se pudo programar el aviso del Sistema: $e');
      }
    }

    if (daily) {
      await put(
        dailyId,
        _next(at),
        "Today's quests are ready",
        'Open Level Up and clear the board while you still have the day.',
        DateTimeComponents.time,
      );
    }
    if (streak) {
      await put(
        streakId,
        _next(streakMinuteOfDay),
        'Streak at risk',
        'No quest logged today. One session before midnight keeps the streak alive.',
        DateTimeComponents.time,
      );
    }
    if (weekly) {
      await put(
        weeklyId,
        _next(weeklyMinuteOfDay, weekday: weekEndWeekday),
        'Weekly missions close tonight',
        'Finish your objectives before the week resets and the reward is lost.',
        DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// The next wall-clock occurrence, today if still ahead.
  DateTime _next(int minuteOfDay, {int? weekday}) {
    final now = DateTime.now();
    final delta = weekday == null ? 0 : (weekday - now.weekday + 7) % 7;
    final today = DateTime(now.year, now.month, now.day + delta, minuteOfDay ~/ 60, minuteOfDay % 60);
    if (today.isAfter(now)) return today;
    return DateTime(now.year, now.month, now.day + delta + (weekday == null ? 1 : 7), minuteOfDay ~/ 60,
        minuteOfDay % 60);
  }
}
