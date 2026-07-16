import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/app_state_store.dart';
import '../../platform/aliyun_update.dart';
import '../../state/app_nav.dart';
import '../../state/app_services.dart';
import '../../state/court_tasks_controller.dart';
import 'advanced_config_page.dart';
import '../fp/fp_icons.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';
import '../fp/fp_transitions.dart';
import '../ios_widgets.dart' show IosDisplayDensity, iosDensityProvider;
import '../legal_dialogs.dart';
import '../ui_enums.dart';

const String kAppDisplayVersion = '2.4.4';

/// 设置（mockup「设置」屏）。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _smsOn = true;
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = ref.read(appServicesProvider).appState;
    _smsOn = await appState.getBoolean(AppStateKeys.smsMonitoringEnabled, true);
    _avatarPath = await appState.getString(AppStateKeys.avatarPath, '');
    if (_avatarPath.isNotEmpty && !File(_avatarPath).existsSync()) {
      _avatarPath = '';
    }
    if (mounted) setState(() {}); // 值到位后就地刷新（无整页 loading 态）
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final destDir = Directory('${dir.path}/avatar');
    if (!destDir.existsSync()) destDir.createSync(recursive: true);
    final dest = '${destDir.path}/avatar.jpg';
    await File(x.path).copy(dest);
    await ref
        .read(appServicesProvider)
        .appState
        .putString(AppStateKeys.avatarPath, dest);
    if (mounted) setState(() => _avatarPath = dest);
  }

  void _pickOpenMode() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('工作台打开方式'),
        actions: [
          for (final m in WorkbenchOpenMode.values)
            CupertinoActionSheetAction(
              onPressed: () {
                ref.read(workbenchOpenModeProvider.notifier).set(m);
                Navigator.pop(ctx);
              },
              child: Text('${m.label} · ${m.desc}'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _toggleSms(bool v) {
    setState(() => _smsOn = v);
    final services = ref.read(appServicesProvider);
    services.appState.putBoolean(AppStateKeys.smsMonitoringEnabled, v);
    services.smsReader.setNativeSmsEnabled(v);
  }

  void _pickDensity() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('文字大小'),
        actions: [
          for (final d in IosDisplayDensity.values)
            CupertinoActionSheetAction(
              onPressed: () {
                ref.read(iosDensityProvider.notifier).setDensity(d);
                Navigator.pop(ctx);
              },
              child: Text(d.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  bool _checking = false;

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      // 左侧图标转圈 → 有更新由 AliyunUpdate 立即弹窗；无更新/异常则 toast。
      final result = await AliyunUpdate.checkForResult();
      if (!mounted) return;
      switch (result) {
        case 'update':
          break; // 弹窗已自动弹出
        case 'latest':
          showFpToast(context, '已是最新版本');
        case 'config_missing':
          showFpToast(context, '更新参数未配置');
        case 'dependency_missing':
          showFpToast(context, '更新依赖缺失');
        case 'timeout':
          showFpToast(context, '检查超时，请稍后重试');
        default:
          showFpToast(context, '检查更新失败');
      }
    } catch (_) {
      if (mounted) showFpToast(context, '检查更新失败');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// 长按「检查更新」→ 展示原生更新 SDK 的当前状态（自查更新链路用）。
  Future<void> _showUpdateDiagnostic() async {
    final status = await AliyunUpdate.status();
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('更新诊断'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            status.isEmpty ? '尚无状态' : status,
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showFpConfirm(
      context,
      title: '清除数据并退出',
      message: '将清空全部任务、文书 PDF 和本地设置，且不可恢复。确定清除？',
      confirmText: '清除',
      destructive: true,
    );
    if (ok) {
      await ref.read(courtTasksProvider.notifier).resetData();
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = ref.watch(iosDensityProvider);
    final openMode = ref.watch(workbenchOpenModeProvider);
    return FpScreen(
      bottom: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FpBackBar(
            label: '日程',
            onBack: () => Navigator.of(context).pop(),
          ),
          // 直接渲染内容（值有默认、加载完就地更新），避免转场中「转圈→内容」闪一下。
          Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Hero(
                      smsOn: _smsOn,
                      avatarPath: _avatarPath,
                      onTapAvatar: _pickAvatar,
                    ),
                    FpSettingsSection(
                      label: '监听来源',
                      children: [
                        FpSettingRow(
                          icon: FpIcons.message,
                          iconBg: FpColors.blue,
                          title: '短信监听',
                          subtitle: '12368 · 各法院送达',
                          trailing: FpToggle(
                            value: _smsOn,
                            onChanged: _toggleSms,
                          ),
                        ),
                        const FpSettingRow(
                          icon: FpIcons.brandWechat,
                          iconBg: Color(0xFF07C160),
                          title: '微信',
                          subtitle: '即将接入',
                          opacity: 0.5,
                          trailing: FpChip('待接入'),
                        ),
                        const FpSettingRow(
                          icon: FpIcons.messageDots,
                          iconBg: Color(0xFFFF6900),
                          title: '钉钉',
                          subtitle: '即将接入',
                          opacity: 0.5,
                          last: true,
                          trailing: FpChip('待接入'),
                        ),
                      ],
                    ),
                    FpSettingsSection(
                      label: '显示设置',
                      children: [
                        FpSettingRow(
                          icon: FpIcons.textSize,
                          iconBg: FpColors.ink2,
                          title: '文字大小',
                          subtitle: density.label,
                          onTap: _pickDensity,
                          trailing: _chev(),
                        ),
                        FpSettingRow(
                          icon: FpIcons.calendarEvent,
                          iconBg: FpColors.ink2,
                          title: '工作台打开方式',
                          subtitle: openMode.label,
                          onTap: _pickOpenMode,
                          last: true,
                          trailing: _chev(),
                        ),
                      ],
                    ),
                    FpSettingsSection(
                      label: '高级',
                      children: [
                        FpSettingRow(
                          icon: FpIcons.settings,
                          iconBg: FpColors.ink2,
                          title: '高级配置',
                          subtitle: 'AI 接口地址 · 模型 · 密钥',
                          last: true,
                          onTap: () => Navigator.of(context).push(
                            fpSharedAxisRoute(
                              (_) => const AdvancedConfigPage(),
                            ),
                          ),
                          trailing: _chev(),
                        ),
                      ],
                    ),
                    FpSettingsSection(
                      label: '关于',
                      children: [
                        FpSettingRow(
                          icon: FpIcons.refresh,
                          iconBg: FpColors.ink1,
                          title: '检查更新',
                          subtitle: 'v$kAppDisplayVersion',
                          iconSpinning: _checking,
                          onTap: _checkUpdate,
                          onLongPress: _showUpdateDiagnostic,
                          trailing: _chev(),
                        ),
                        FpSettingRow(
                          icon: FpIcons.fileText,
                          iconBg: FpColors.ink1,
                          title: '用户协议 · 隐私政策',
                          onTap: () => showLegalDocs(context),
                          trailing: _chev(),
                        ),
                        FpSettingRow(
                          icon: FpIcons.trash,
                          iconBg: FpColors.red,
                          title: '清除数据并退出',
                          destructive: true,
                          last: true,
                          onTap: _confirmReset,
                          trailing: _chev(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chev() => Icon(FpIcons.chevronRight, size: 16, color: FpColors.ink3);
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.smsOn,
    required this.avatarPath,
    required this.onTapAvatar,
  });
  final bool smsOn;
  final String avatarPath;
  final VoidCallback onTapAvatar;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: FpColors.surface,
        border: Border(bottom: BorderSide(color: FpColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTapAvatar,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: FpColors.ink1,
                shape: BoxShape.circle,
                image: hasAvatar
                    ? DecorationImage(
                        image: FileImage(File(avatarPath)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasAvatar
                  ? null
                  : const Text(
                      'T1',
                      style: TextStyle(
                        inherit: false,
                        fontFamily: 'CupertinoSystemText',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: FpColors.surface,
                        decoration: TextDecoration.none,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'T1 律师工作台',
                  style: TextStyle(
                    inherit: false,
                    fontFamily: 'CupertinoSystemText',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: FpColors.ink1,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      FpIcons.circleCheck,
                      size: 13,
                      color: smsOn ? FpColors.green : FpColors.ink3,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${smsOn ? '短信监听已启用' : '短信监听已关闭'} · v$kAppDisplayVersion',
                      style: FpText.micro,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
