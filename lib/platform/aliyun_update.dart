import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../ui/fp/fp_widgets.dart' show showFpToast;

/// 阿里云 EMAS 云发布（Taobao OneSDK）更新桥接。
/// 检测由原生 SDK 完成；发现新版本→原生广播→这里弹确认框→回传确认/取消。
/// [checkForResult] 把异步广播包成一个 Future，便于 UI 转圈/toast。
class AliyunUpdate {
  AliyunUpdate._();

  static const MethodChannel _ch = MethodChannel('top.linso.t1/update');
  static GlobalKey<NavigatorState>? _navKey;
  static Completer<String>? _pending;

  static void init(GlobalKey<NavigatorState> navKey) {
    _navKey = navKey;
    _ch.setMethodCallHandler((call) async {
      final m = call.arguments is Map
          ? (call.arguments as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      switch (call.method) {
        case 'onUpdateNotify':
          _finish('update'); // 先停转圈，再弹窗
          await _showDialog(m);
        case 'onUpdateResult':
          // 检查结束：若没收到「发现新版本」，视为已是最新。
          if (m['found'] != true) _finish('latest');
      }
      return null;
    });
  }

  /// 触发原生检测，返回即时状态字符串（如 code=CHECKING/CONFIG_MISSING…）。
  static Future<String> check() async =>
      (await _ch.invokeMethod<String>('checkUpdate')) ?? '';

  static Future<String> status() async =>
      (await _ch.invokeMethod<String>('updateStatus')) ?? '';

  /// 检测并等待结果：'update'(已弹窗) / 'latest' / 'config_missing' /
  /// 'dependency_missing' / 'timeout' / 'error'。
  static Future<String> checkForResult(
      {Duration timeout = const Duration(seconds: 20)}) async {
    if (_pending != null && !_pending!.isCompleted) _finish('superseded');
    final c = Completer<String>();
    _pending = c;
    String status = '';
    try {
      status = await check();
    } catch (_) {
      _finish('error');
      return c.future;
    }
    if (status.contains('CONFIG_MISSING')) {
      _finish('config_missing');
    } else if (status.contains('DEPENDENCY_MISSING')) {
      _finish('dependency_missing');
    } else if (status.contains('INIT_FAILED') || status.contains('FAILED')) {
      _finish('error');
    } else {
      Timer(timeout, () => _finish('timeout'));
    }
    return c.future;
  }

  static void _finish(String result) {
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete(result);
  }

  static Future<void> _showDialog(Map<String, dynamic> m) async {
    final ctx = _navKey?.currentContext;
    if (ctx == null) return;
    final force = m['force'] == true;
    final url = '${m['url'] ?? ''}'.trim();
    final version = '${m['version'] ?? ''}'.trim();
    final ok = await showCupertinoDialog<bool>(
      context: ctx,
      barrierDismissible: !force,
      builder: (c) => CupertinoAlertDialog(
        title: Text('${m['title'] ?? '发现新版本'}'),
        content: Text('${m['message'] ?? ''}'),
        actions: [
          if (!force)
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(c, false),
              child: Text('${m['cancel'] ?? '稍后'}'),
            ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: Text('${m['confirm'] ?? '更新'}'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (url.isNotEmpty) {
        await _downloadAndInstall(url, version);
      } else {
        // 没拿到 APK 直链 → 退回 SDK 后台下载（无进度条）。
        await _ch.invokeMethod('confirmUpdate');
      }
    } else {
      await _ch.invokeMethod('cancelUpdate');
    }
  }

  /// 下载 APK 到私有目录并安装，弹窗显示进度。已下载过同版本则直接安装（不重复下载）。
  static Future<void> _downloadAndInstall(String url, String version) async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {}
    base ??= await getTemporaryDirectory();
    final dir = Directory('${base.path}/update');
    if (!await dir.exists()) await dir.create(recursive: true);
    final safe = version.isEmpty
        ? 'latest'
        : version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final apk = File('${dir.path}/t1-$safe.apk');

    // 缓存命中：同版本已完整下载 → 直接装，避免二次更新重复下载。
    if (await apk.exists() && await apk.length() > 0) {
      await _install(apk.path);
      return;
    }

    final tmp = File('${apk.path}.tmp');
    final progress = ValueNotifier<double>(0);
    final cancelToken = CancelToken();
    final ctx = _navKey?.currentContext;
    if (ctx == null) return;
    // ctx 来自根导航 GlobalKey（非 State.context），无 mounted 概念。
    // ignore: use_build_context_synchronously
    unawaited(showCupertinoDialog<void>(context: ctx,
        barrierDismissible: false,
        builder: (_) => _DownloadDialog(
            progress: progress,
            onCancel: () => cancelToken.cancel('user'))));
    try {
      await Dio().download(
        url,
        tmp.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) progress.value = (received / total).clamp(0.0, 1.0);
        },
      );
      await tmp.rename(apk.path);
      _closeTopDialog();
      await _install(apk.path);
    } catch (e) {
      _closeTopDialog();
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      // 用户主动取消不提示，其它失败才提示。
      if (!(e is DioException && CancelToken.isCancel(e))) {
        _toast('下载失败，请重试');
      }
    }
  }

  static void _closeTopDialog() {
    final ctx = _navKey?.currentContext;
    if (ctx == null) return;
    final nav = Navigator.of(ctx, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  static Future<void> _install(String path) async {
    try {
      await const MethodChannel('top.linso.t1/app')
          .invokeMethod('installApk', {'path': path});
    } catch (_) {
      _toast('安装失败，请重试');
    }
  }

  static void _toast(String msg) {
    final ctx = _navKey?.currentContext;
    if (ctx != null) showFpToast(ctx, msg);
  }
}

/// 下载进度弹窗（Cupertino 风格，不依赖 Material）。
class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({required this.progress, this.onCancel});
  final ValueNotifier<double> progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('正在下载更新'),
      content: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      const ColoredBox(color: CupertinoColors.systemGrey5),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v.clamp(0.0, 1.0),
                        child: const ColoredBox(color: CupertinoColors.activeBlue),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(v * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (onCancel != null)
          CupertinoDialogAction(
            onPressed: onCancel,
            child: const Text('取消'),
          ),
      ],
    );
  }
}
