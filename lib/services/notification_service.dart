import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const _notifId = 0;
  static const _enabledKey = 'notifications_enabled';

  static const _androidDetails = AndroidNotificationDetails(
    'daily_wonder',
    'Daily Wonder',
    channelDescription: 'Your daily reminder to discover a new wonder',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_notification',
    largeIcon: DrawableResourceAndroidBitmap('awe_mascot'),
  );
  static const _notifDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (details) {
          debugPrint('[NotificationService] Notification received/tapped: ${details.payload}');
        },
      );

      if (await isEnabled()) {
        await _scheduleAt8AM();
      }
    } catch (e) {
      debugPrint('[NotificationService] initialize error: $e');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      return true;
    } catch (e) {
      debugPrint('[NotificationService] requestPermission error: $e');
      return false;
    }
  }

  Future<void> scheduleDaily() async {
    try {
      await _scheduleAt8AM();
    } catch (e) {
      debugPrint('[NotificationService] scheduleDaily error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
  }

  Future<void> cancel() async {
    try {
      await _plugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, false);
    } catch (e) {
      debugPrint('[NotificationService] cancel error: $e');
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> showNow() async {
    try {
      await _plugin.show(
        _notifId,
        'Your daily wonder awaits ✨',
        'Tap to discover something extraordinary today',
        _notifDetails,
      );
    } catch (e) {
      debugPrint('[NotificationService] showNow error: $e');
    }
  }

  Future<void> _scheduleAt8AM() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notifId,
      'Your daily wonder awaits ✨',
      'Tap to discover something extraordinary today',
      scheduled,
      _notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
