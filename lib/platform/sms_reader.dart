import 'package:flutter/services.dart';

/// 一条收件箱短信，对照 Kotlin `SmsImporter.SmsRow`。
class SmsRow {
  const SmsRow(
      {required this.address, required this.body, required this.dateMillis});
  final String address;
  final String body;
  final int dateMillis;
}

/// 短信读取抽象，便于测试时替换。Android 实现走平台通道，
/// 原生侧用 ContentResolver 查询 Telephony.Sms 收件箱。
abstract class SmsReader {
  Future<List<SmsRow>> loadRecentSms(int limit);

  /// app 运行时实时到达的新短信流（原生动态 SMS_RECEIVED 接收器）。
  Stream<SmsRow> newSmsStream();

  /// 取出并清空原生侧缓存的"被杀时收到"的法院短信队列。
  Future<List<SmsRow>> drainPendingSms();

  /// 同步短信监听开关到原生（常驻接收器据此决定是否处理）。
  Future<void> setNativeSmsEnabled(bool enabled);
}

/// 平台通道实现：对应原生 MethodChannel `top.linso.t1/sms` 的 `loadRecentSms`。
class MethodChannelSmsReader implements SmsReader {
  static const MethodChannel _channel = MethodChannel('top.linso.t1/sms');
  static const EventChannel _events = EventChannel('top.linso.t1/sms_events');

  @override
  Stream<SmsRow> newSmsStream() {
    return _events.receiveBroadcastStream().map((e) {
      final m = (e as Map).cast<dynamic, dynamic>();
      return SmsRow(
        address: (m['address'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        dateMillis: (m['date'] as num?)?.toInt() ?? 0,
      );
    });
  }

  @override
  Future<List<SmsRow>> loadRecentSms(int limit) async {
    final result = await _channel
        .invokeMethod<List<dynamic>>('loadRecentSms', {'limit': limit});
    return _mapRows(result);
  }

  @override
  Future<List<SmsRow>> drainPendingSms() async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('drainPendingSms');
      return _mapRows(result);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> setNativeSmsEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setNativeSmsEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  List<SmsRow> _mapRows(List<dynamic>? result) {
    if (result == null) return const [];
    return result.map((e) {
      final m = (e as Map).cast<dynamic, dynamic>();
      return SmsRow(
        address: (m['address'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        dateMillis: (m['date'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}
