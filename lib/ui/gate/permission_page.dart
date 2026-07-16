import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/app_state_store.dart';
import '../../state/app_services.dart';
import '../fp/fp_icons.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';

class _PermItem {
  const _PermItem(this.title, this.desc, this.permission, this.icon, this.iconBg);
  final String title;
  final String desc;
  final Permission permission;
  final IconData icon;
  final Color iconBg;
}

/// 首启权限校验清单：隐私同意后逐项授权，全部完成才能进入。
class PermissionGate extends ConsumerStatefulWidget {
  const PermissionGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends ConsumerState<PermissionGate>
    with WidgetsBindingObserver {
  static const _items = <_PermItem>[
    _PermItem('短信权限', '读取并接收 12368 / 法院送达短信，自动生成待办',
        Permission.sms, FpIcons.message, FpColors.blue),
    _PermItem('通知权限', '未处理任务与新法院短信的提醒',
        Permission.notification, FpIcons.infoCircle, FpColors.amber),
  ];

  bool? _onboarded; // null=加载中
  final Map<Permission, bool> _granted = {};
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _onboarded == false) {
      _refreshStatuses();
    }
  }

  Future<void> _load() async {
    final done = await ref
        .read(appServicesProvider)
        .appState
        .getBoolean(AppStateKeys.permissionsOnboarded, false);
    if (done) {
      if (mounted) setState(() => _onboarded = true);
      return;
    }
    await _refreshStatuses();
    if (mounted) setState(() => _onboarded = false);
  }

  Future<void> _refreshStatuses() async {
    for (final item in _items) {
      _granted[item.permission] = await item.permission.isGranted;
    }
    if (mounted) setState(() {});
  }

  Future<void> _request(_PermItem item) async {
    if (_requesting) return;
    _requesting = true;
    try {
      final status = await item.permission.request();
      // 被永久拒绝（勾了「不再询问」或第二次拒绝后）时，系统不再弹授权框，
      // request() 会立即返回——表现为「点了没反应」。此时跳转应用设置页手动开，
      // 返回 app 时 didChangeAppLifecycleState 会自动刷新状态。
      if (status.isPermanentlyDenied || status.isRestricted) {
        await openAppSettings();
        return;
      }
      _granted[item.permission] = status.isGranted;
    } finally {
      // 无论成功、拒绝还是抛异常，都要释放锁，否则后续点击会全部失效。
      _requesting = false;
      if (mounted) setState(() {});
    }
  }

  bool get _allGranted =>
      _items.every((i) => _granted[i.permission] == true);

  Future<void> _finish() async {
    await ref
        .read(appServicesProvider)
        .appState
        .putBoolean(AppStateKeys.permissionsOnboarded, true);
    if (mounted) setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded == null) {
      return const ColoredBox(
        color: FpColors.bg,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_onboarded!) return widget.child;

    return FpScreen(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '授权权限',
              style: TextStyle(
                inherit: false,
                fontFamily: 'CupertinoSystemText',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: FpColors.ink1,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 6),
            Text('为正常使用核心功能，请逐项授权（需全部授权后方可进入）。授权后会自动打勾。',
                style: FpText.pageSub),
            const SizedBox(height: 20),
            for (final item in _items) ...[
              _row(item),
              const SizedBox(height: 10),
            ],
            const Spacer(),
            GestureDetector(
              onTap: _allGranted ? _finish : null,
              child: Opacity(
                opacity: _allGranted ? 1 : 0.4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FpColors.ink1,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Text(
                    '下一步',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: FpColors.surface,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(_PermItem item) {
    final granted = _granted[item.permission] == true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: granted ? null : () => _request(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FpColors.surface,
          borderRadius: BorderRadius.circular(FpRadii.card),
          border: Border.all(
              color: granted ? FpColors.green : FpColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, size: 18, color: FpColors.surface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: FpColors.ink1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(item.desc, style: FpText.micro),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (granted)
              Icon(FpIcons.circleCheck, size: 24, color: FpColors.green)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: FpColors.ink1,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '授权',
                  style: TextStyle(
                    inherit: false,
                    fontFamily: 'CupertinoSystemText',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: FpColors.surface,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
