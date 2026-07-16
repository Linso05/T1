import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 常驻待办通知，对照 Kotlin `T1TaskNotifier`。
/// 有未处理任务时显示低优先级 ongoing 通知，清空后取消。
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static const int _id = 1001;
  static const String _channelId = 't1_todo';

  Future<void> _ensureInit() async {
    if (_inited) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _inited = true;
  }

  /// 同步未处理任务通知。count<=0 取消。
  Future<void> sync(int count, String summary) async {
    if (count <= 0) {
      await cancel();
      return;
    }
    await _ensureInit();
    const details = AndroidNotificationDetails(
      _channelId,
      '待办提醒',
      channelDescription: '未处理的法院送达任务',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
    );
    await _plugin.show(
      _id,
      'T1 待办 $count 件',
      summary,
      const NotificationDetails(android: details),
    );
  }

  Future<void> cancel() async {
    if (!_inited) return;
    await _plugin.cancel(_id);
  }
}
