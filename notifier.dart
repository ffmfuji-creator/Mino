import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// 后台提醒：应用进入后台时，按计时结束时间预约一条系统通知。
/// 应用在前台时不预约（用应用内提示音/振动），回到前台时取消预约，避免重复提醒。
class Notifier {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const int _endId = 1001;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@drawable/ic_stat_mino');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// 请求通知权限（安卓 13+ 会弹出系统授权框）。
  static Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: false, sound: true);
    } catch (_) {}
  }

  /// 预约「当前阶段结束」的通知。
  static Future<void> scheduleEnd({
    required int endAtMs,
    required bool focus,
    required bool sound,
    required bool vibrate,
  }) async {
    if (!_ready) return;
    if (endAtMs <= DateTime.now().millisecondsSinceEpoch) return;

    final when = DateTime.fromMillisecondsSinceEpoch(endAtMs, isUtc: true);
    final scheduled = tz.TZDateTime.utc(when.year, when.month, when.day,
        when.hour, when.minute, when.second, when.millisecond);

    // 安卓 8+ 的声音/振动由「渠道」决定，所以按设置组合使用不同渠道
    final channelId = 'mino_alert_${sound ? 's' : 'x'}${vibrate ? 'v' : 'x'}';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        '计时提醒',
        channelDescription: '专注或休息结束时提醒',
        importance: Importance.max,
        priority: Priority.high,
        playSound: sound,
        enableVibration: vibrate,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: sound),
    );

    final title = focus ? '专注完成' : '休息结束';
    final body = focus ? '干得漂亮，休息一下吧' : '休息结束，回来继续专注吧';

    try {
      await _plugin.zonedSchedule(
        _endId,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // 精确闹钟不可用时退回到普通模式（可能有几分钟延迟）
      try {
        await _plugin.zonedSchedule(
          _endId,
          title,
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {}
    }
  }

  static Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_endId);
    } catch (_) {}
  }
}
