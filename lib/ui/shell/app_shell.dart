import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state_store.dart';
import '../../models/court_enums.dart';
import '../../platform/aliyun_update.dart';
import '../../state/app_nav.dart';
import '../../state/app_services.dart';
import '../../state/court_tasks_controller.dart';
import '../ai/ai_page.dart';
import '../delivery/delivery_page.dart';
import '../fp/fp_icons.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';
import '../tools/tools_page.dart';
import '../workbench/workbench_page.dart';

/// 自定义外壳：4 个主 tab 用 PageView 左右滑（保活），**无嵌套 Navigator**——
/// pushed 页（设置/详情/PDF/AI）走根 Navigator → 全屏盖住底栏、返回干净。
/// 日程内部的日/周/月... 滑动在 WorkbenchPage 里（只滑内容区，头部固定）。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  static const List<Widget> _pages = [
    WorkbenchPage(),
    DeliveryPage(),
    AiPage(),
    ToolsPage(),
  ];

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(courtTasksProvider.notifier).refresh();
      _maybeCheckUpdate();
    });
  }

  /// 冷启动更新检查节流：距上次检查不足 [_updateCheckThrottle] 就跳过，
  /// 避免每次冷启都触发第三方更新 SDK（也降低其后台线程异常拖崩启动的概率）。
  /// 手动「检查更新」不受此限制。
  static const _updateCheckThrottle = Duration(hours: 6);

  Future<void> _maybeCheckUpdate() async {
    final appState = ref.read(appServicesProvider).appState;
    final last = int.tryParse(
            await appState.getString(AppStateKeys.lastUpdateCheckAt, '0')) ??
        0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _updateCheckThrottle.inMilliseconds) return;
    await appState.putString(AppStateKeys.lastUpdateCheckAt, '$now');
    // 有新版本会自动弹窗（结果忽略）。
    AliyunUpdate.checkForResult();
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(courtTasksProvider.notifier).refresh();
    }
  }

  void _animateTo(int page) => _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );

  void _onNavTap(int i) {
    final cur = _pageController.hasClients
        ? (_pageController.page?.round() ?? 0)
        : 0;
    if (i == cur) {
      // 再次点击当前 tab → 滚动到顶。
      ref.read(tabReselectProvider.notifier).state++;
    } else {
      _animateTo(i);
    }
  }

  void _handlePop() {
    final page = _pageController.hasClients
        ? (_pageController.page?.round() ?? 0)
        : 0;
    if (page != 0) {
      _animateTo(0);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅「未读数」这个派生值：同步进度每 250ms 变一次时，未读数不变就不重建外壳，
    // 底栏切换/滑动动画不再被后台同步打断。
    final unread = ref.watch(courtTasksProvider.select((s) => s.tasks
        .where((t) => t.unread && t.status != CourtTaskStatus.archived)
        .length));

    // 外部切 tab（如工作台「送达展开」设 appTabProvider=1）时滑到对应页。
    ref.listen(appTabProvider, (_, t) {
      final cur = _pageController.hasClients
          ? (_pageController.page?.round() ?? 0)
          : 0;
      if (cur != t) _animateTo(t);
    });

    final items = [
      FpTabItem(icon: FpIcons.calendar, label: '日程'),
      FpTabItem(icon: FpIcons.inbox, label: '送达', badge: unread),
      FpTabItem(icon: FpIcons.messageCircle, label: 'AI'),
      FpTabItem(icon: FpIcons.tool, label: '工具'),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: ColoredBox(
        color: FpColors.bg,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) =>
                    ref.read(appTabProvider.notifier).state = i,
                itemBuilder: (_, i) => _KeepAlive(child: _pages[i]),
              ),
            ),
            AnimatedBuilder(
              animation: _pageController,
              builder: (_, _) {
                final page = (_pageController.hasClients &&
                        _pageController.position.haveDimensions)
                    ? (_pageController.page ?? 0)
                    : 0.0;
                return FpTabBar(
                  currentIndex: page.round().clamp(0, _pages.length - 1),
                  position: page,
                  onTap: _onNavTap,
                  items: items,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// PageView 中保活每个 tab（连同其独立 Navigator 返回栈）。
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
