import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/court_enums.dart';
import '../../models/court_task.dart';
import '../../state/app_nav.dart';
import '../../state/court_tasks_controller.dart';
import '../delivery/delivery_detail_page.dart';
import '../formatters.dart';
import '../fp/fp_calendar.dart';
import '../fp/fp_icons.dart';
import '../fp/fp_task_view.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';
import '../fp/fp_transitions.dart';
import '../settings/settings_page.dart';
import '../ui_enums.dart';


/// 工作台 / 日程：**头部「日程」+ tab 条固定不动**，只有下面的内容区按
/// 日/周/月/90天/年/全部 左右滑（内层 PageView）。
class WorkbenchPage extends ConsumerStatefulWidget {
  const WorkbenchPage({super.key});

  @override
  ConsumerState<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends ConsumerState<WorkbenchPage> {
  static const List<AgendaRange> _ranges = [
    AgendaRange.day,
    AgendaRange.week,
    AgendaRange.month,
    AgendaRange.day90,
    AgendaRange.year,
    AgendaRange.all,
  ];

  AgendaRange _range = AgendaRange.day;
  DateTime? _selectedDay;
  DateTime? _viewMonth; // 月历当前查看的月份（UTC 该月 1 号）；null=今天所在月
  final PageController _agendaPage = PageController();

  /// 月历正在查看的月份（该月 1 号，UTC）。
  DateTime _currentViewMonth() {
    final today = chinaToday();
    return _viewMonth ?? DateTime.utc(today.year, today.month, 1);
  }

  /// 切换到相邻月份：同时把选中日落到新月份里（本月→今天，否则→1 号），
  /// 这样下方「当日事项」会跟着显示新月份的内容。
  void _shiftMonth(int delta) {
    final today = chinaToday();
    final base = _currentViewMonth();
    final next = DateTime.utc(base.year, base.month + delta, 1);
    setState(() {
      _viewMonth = next;
      _selectedDay = (next.year == today.year && next.month == today.month)
          ? today
          : next;
    });
  }

  /// 回到今天所在月并选中今天。
  void _goToday() {
    final today = chinaToday();
    setState(() {
      _viewMonth = DateTime.utc(today.year, today.month, 1);
      _selectedDay = today;
    });
  }

  /// 所有「月视图可见」的未归档/未失败任务，按日期分组（跨全部月份）。
  Map<DateTime, List<CourtTask>> _monthByDay(List<CourtTask> tasks) {
    final byDay = <DateTime, List<CourtTask>>{};
    for (final t in tasks) {
      if (t.status == CourtTaskStatus.archived ||
          t.status == CourtTaskStatus.failed) {
        continue;
      }
      if (!t.isVisibleInAgendaRange(AgendaRange.month)) continue;
      byDay
          .putIfAbsent(
              chinaDateOnly(t.agendaMillis(AgendaRange.month)), () => [])
          .add(t);
    }
    return byDay;
  }

  @override
  void dispose() {
    _agendaPage.dispose();
    super.dispose();
  }

  void _selectRange(AgendaRange v) {
    final i = _ranges.indexOf(v);
    if (i >= 0) {
      _agendaPage.animateToPage(i,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    }
  }

  String _monthSubtitle(List<CourtTask> tasks) {
    final today = chinaToday();
    final vm = _currentViewMonth();
    var n = 0;
    _monthByDay(tasks).forEach((d, list) {
      if (d.year == vm.year && d.month == vm.month) n += list.length;
    });
    final isCurrent = vm.year == today.year && vm.month == today.month;
    return isCurrent ? '$n 件本月日程' : '${vm.year}年${vm.month}月 · $n 件日程';
  }

  List<CourtTask> _urgentFor(List<CourtTask> tasks, AgendaRange range) {
    return tasks
        .where((t) =>
            t.status != CourtTaskStatus.archived &&
            (t.riskLevel == TaskRiskLevel.critical ||
                t.status == CourtTaskStatus.failed) &&
            isInAgendaRange(chinaDateOnly(t.agendaMillis(range)), range))
        .toList()
      ..sort((a, b) => b.smsDateMillis.compareTo(a.smsDateMillis));
  }

  static double _hour(int ms) {
    final w = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
        .add(const Duration(hours: 8));
    return w.hour + w.minute / 60;
  }

  List<DateTime> _grid(DateTime today) {
    final first = DateTime.utc(today.year, today.month, 1);
    final leading = first.weekday % 7; // Sunday-first
    final start = first.subtract(Duration(days: leading));
    final last = DateTime.utc(today.year, today.month + 1, 0);
    final trailing = 6 - (last.weekday % 7);
    final end = last.add(Duration(days: trailing));
    final out = <DateTime>[];
    var d = start;
    while (!d.isAfter(end)) {
      out.add(d);
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  void _openDetail(String id, {Object? heroTag}) {
    ref.read(courtTasksProvider.notifier).markRead(id);
    if (ref.read(workbenchOpenModeProvider) ==
        WorkbenchOpenMode.deliveryExpanded) {
      // 跳到送达中心并展开该任务。
      ref.read(deliveryExpandTargetProvider.notifier).state = id;
      ref.read(appTabProvider.notifier).state = 1;
    } else {
      Navigator.of(context).push(
        fpZoomRoute((_) => DeliveryDetailPage(taskId: id, heroTag: heroTag)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 只 watch tasks：同步进度/筛选变化不再重建整个日程（含 6 页 + 月历）。
    final tasks = ref.watch(courtTasksProvider.select((s) => s.tasks));
    final controller = ref.read(courtTasksProvider.notifier);
    final isMonth = _range == AgendaRange.month;
    final subtitle = isMonth
        ? _monthSubtitle(tasks)
        : '${_urgentFor(tasks, _range).length} 件紧急 · ${tasks.agendaTasks(_range).length} 件待办';

    return FpScreen(
      child: Column(
        children: [
          // 固定头部
          FpHeader(
            title: '日程',
            subtitle: subtitle,
            actions: [
              // 齿轮→设置：iOS 标准转场，系统级优化、丝滑，且带边缘侧滑返回。
              FpIconButton(
                icon: FpIcons.settings,
                size: 26,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          ),
          // 固定 tab 条
          FpTabStrip<AgendaRange>(
            value: _range,
            onChanged: _selectRange,
            tabs: const [
              FpTab(AgendaRange.day, '日'),
              FpTab(AgendaRange.week, '周'),
              FpTab(AgendaRange.month, '月'),
              FpTab(AgendaRange.day90, '90天'),
              FpTab(AgendaRange.year, '年'),
              FpTab(AgendaRange.all, '全部'),
            ],
          ),
          const SizedBox(height: 6),
          // 只有内容区跟着滑
          Expanded(
            child: PageView.builder(
              controller: _agendaPage,
              itemCount: _ranges.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _range = _ranges[i]),
              itemBuilder: (_, i) => _rangePage(tasks, controller, _ranges[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangePage(List<CourtTask> tasks, CourtTasksController controller,
      AgendaRange range) {
    final slivers = <Widget>[
      fpRefreshControl(controller.refresh),
    ];
    if (range == AgendaRange.month) {
      slivers.addAll(_calendarSlivers(tasks));
    } else {
      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
        sliver: SliverList.list(
          children:
              _feed(_urgentFor(tasks, range), tasks.agendaTasks(range), range),
        ),
      ));
    }
    return CustomScrollView(
      key: PageStorageKey(range),
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: slivers,
    );
  }

  // ---------------- day / week feed ----------------

  List<Widget> _feed(
      List<CourtTask> urgent, List<CourtTask> agenda, AgendaRange range) {
    if (urgent.isEmpty && agenda.isEmpty) {
      return [
        const FpEmptyState(
          title: '暂无待办',
          subtitle: '下拉刷新后，传票、缴费、判决等事项会自动进入日程',
        ),
      ];
    }
    final widgets = <Widget>[];
    var order = 0; // 入场错峰序号（跨紧急/日程段连续）
    if (urgent.isNotEmpty) {
      widgets.add(const FpSectionLabel('紧急',
          padding: EdgeInsets.fromLTRB(4, 10, 4, 7)));
      for (final t in urgent) {
        final failed = t.status == CourtTaskStatus.failed;
        // 紧急项不再用红色卡片，改为与普通卡同款 + 右上角红色角标。
        widgets.add(FpEntrance(
          index: order++,
          child: FpTaskCard(
            type: failed ? '异常 · 解析失败' : t.fpTypeLabel(),
            time: failed ? null : timeLabel(t.agendaMillis(range)),
            title: t.fpCourtTitle(),
            meta: t.caseNo.isNotEmpty ? t.caseNo : t.deliveryMetaLine(),
            chips: t.fpChips(),
            cta: failed ? (t.error.isNotEmpty ? t.error : '需人工处理') : t.focusedCta(),
            unread: t.unread,
            urgent: true,
            onTap: () => _openDetail(t.id),
          ),
        ));
      }
    }

    final groups = <DateTime, List<CourtTask>>{};
    for (final t in agenda) {
      groups.putIfAbsent(chinaDateOnly(t.agendaMillis(range)), () => []).add(t);
    }
    final dates = groups.keys.toList()..sort();
    for (final date in dates) {
      widgets.add(FpSectionLabel(agendaDateLabel(date)));
      for (final t in groups[date]!) {
        widgets.add(FpEntrance(
          index: order++,
          child: FpTaskCard(
            type: t.fpTypeLabel(),
            time: timeLabel(t.agendaMillis(range)),
            title: t.fpCourtTitle(),
            meta: t.caseNo.isNotEmpty ? t.caseNo : t.deliveryMetaLine(),
            chips: t.fpChips(),
            cta: t.focusedCta(),
            unread: t.unread,
            onTap: () => _openDetail(t.id),
          ),
        ));
      }
    }
    return widgets;
  }

  // ---------------- 内嵌月历 ----------------

  List<Widget> _calendarSlivers(List<CourtTask> tasks) {
    final today = chinaToday();
    final viewMonth = _currentViewMonth();
    final selected = _selectedDay ?? today;

    final byDay = _monthByDay(tasks);
    final dotsByDay = {
      for (final e in byDay.entries) e.key: e.value.map((t) => t.fpDot()).toList(),
    };

    final dayTasks = [...(byDay[selected] ?? const <CourtTask>[])]
      ..sort((a, b) => a
          .agendaMillis(AgendaRange.month)
          .compareTo(b.agendaMillis(AgendaRange.month)));
    final events = [
      for (final t in dayTasks)
        FpTimelineEvent(
          hour: _hour(t.agendaMillis(AgendaRange.month)),
          title: t.agendaTitle(AgendaRange.month),
          timeLabel: agendaTimeLabel(t.agendaMillis(AgendaRange.month)),
          style: t.fpDot(),
          onTap: () => _openDetail(t.id),
        ),
    ];

    final now = chinaNowWall();
    final nowHour = selected == today ? now.hour + now.minute / 60 : null;

    return [
      SliverPadding(
        padding: const EdgeInsets.only(top: 10),
        sliver: SliverToBoxAdapter(
          child: FpMonthCalendar(
            monthTitle: '${viewMonth.year}年${viewMonth.month}月',
            gridDates: _grid(viewMonth),
            today: today,
            selected: selected,
            dotsByDay: dotsByDay,
            onPrevMonth: () => _shiftMonth(-1),
            onNextMonth: () => _shiftMonth(1),
            onToday: (viewMonth.year == today.year &&
                    viewMonth.month == today.month)
                ? null
                : _goToday,
            onSelect: (d) => setState(() {
              _selectedDay = d;
              // 点到相邻月份的补位日期时，顺势切到那个月。
              if (d.year != viewMonth.year || d.month != viewMonth.month) {
                _viewMonth = DateTime.utc(d.year, d.month, 1);
              }
            }),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
          child: Row(
            children: [
              Text(
                agendaDateLabel(selected),
                style: const TextStyle(
                  inherit: false,
                  fontFamily: 'CupertinoSystemText',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: FpColors.ink1,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              Text('${dayTasks.length} 件', style: FpText.micro),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        sliver: SliverToBoxAdapter(
          child: dayTasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('当天暂无事项', style: FpText.micro),
                  ),
                )
              : FpDayTimeline(events: events, nowHour: nowHour),
        ),
      ),
    ];
  }
}
