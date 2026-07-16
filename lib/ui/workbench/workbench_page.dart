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
  final PageController _agendaPage = PageController();

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
    final agenda = tasks.agendaTasks(_range);
    final subtitle = isMonth
        ? '${agenda.length} 件本月日程'
        : '${_urgentFor(tasks, _range).length} 件紧急 · ${agenda.length} 件待办';

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
    final selected = _selectedDay ?? today;

    final monthTasks = tasks.agendaTasks(AgendaRange.month);
    final byDay = <DateTime, List<CourtTask>>{};
    for (final t in monthTasks) {
      byDay
          .putIfAbsent(chinaDateOnly(t.agendaMillis(AgendaRange.month)), () => [])
          .add(t);
    }
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
            monthTitle: monthTitleLabel(),
            gridDates: _grid(today),
            today: today,
            selected: selected,
            dotsByDay: dotsByDay,
            onSelect: (d) => setState(() => _selectedDay = d),
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
