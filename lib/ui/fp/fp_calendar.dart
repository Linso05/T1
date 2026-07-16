import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'fp_icons.dart';
import 'fp_tokens.dart';

const List<String> _dow = ['日', '一', '二', '三', '四', '五', '六'];

/// 事件圆点颜色。
enum FpDot { red, amber, blue }

Color _dotColor(FpDot d) => switch (d) {
      FpDot.red => FpColors.red,
      FpDot.amber => FpColors.amber,
      FpDot.blue => FpColors.blue,
    };

/// 时间轴单个事件。
class FpTimelineEvent {
  const FpTimelineEvent({
    required this.hour,
    required this.title,
    required this.timeLabel,
    this.style = FpDot.amber,
    this.onTap,
  });

  final double hour; // 8.0 ~ 21.0
  final String title;
  final String timeLabel;
  final FpDot style;
  final VoidCallback? onTap;
}

// ============================ 月历（可展开/收起） ============================

/// `.cal-wrap`：整月网格 ↔ 单周行，280ms 动画切换。
class FpMonthCalendar extends StatefulWidget {
  const FpMonthCalendar({
    super.key,
    required this.monthTitle,
    required this.gridDates,
    required this.today,
    required this.selected,
    required this.dotsByDay,
    required this.onSelect,
    this.actions = const [],
  });

  final String monthTitle;
  final List<DateTime> gridDates; // 整周补齐的日期（UTC date-only），Sunday-first
  final DateTime today;
  final DateTime selected;
  final Map<DateTime, List<FpDot>> dotsByDay;
  final ValueChanged<DateTime> onSelect;
  final List<Widget> actions;

  @override
  State<FpMonthCalendar> createState() => _FpMonthCalendarState();
}

class _FpMonthCalendarState extends State<FpMonthCalendar> {
  bool _expanded = true;

  int get _selMonth => widget.selected.month;

  List<DateTime> get _selectedWeek {
    final i = widget.gridDates.indexWhere((d) => d == widget.selected);
    final base = i < 0 ? 0 : (i ~/ 7) * 7;
    return widget.gridDates.sublist(base, base + 7);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FpColors.surface,
        border: Border(bottom: BorderSide(color: FpColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  widget.monthTitle,
                  style: const TextStyle(
                    inherit: false,
                    fontFamily: 'CupertinoSystemText',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: FpColors.ink1,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
                ...widget.actions,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        _dow[i],
                        style: TextStyle(
                          inherit: false,
                          fontFamily: 'CupertinoSystemText',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: i == 5
                              ? FpColors.red
                              : i == 4
                                  ? FpColors.blue
                                  : FpColors.ink3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: kFpEasing,
            alignment: Alignment.topCenter,
            child: _expanded ? _fullGrid() : _miniRow(),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = !_expanded);
            },
            child: SizedBox(
              height: 18,
              child: Center(
                child: AnimatedRotation(
                  turns: _expanded ? 0 : 0.5,
                  duration: const Duration(milliseconds: 260),
                  curve: kFpEasing,
                  child: Icon(FpIcons.chevronUp, size: 15, color: FpColors.ink3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fullGrid() {
    final rows = <Widget>[];
    for (var i = 0; i < widget.gridDates.length; i += 7) {
      rows.add(Row(
        children: [
          for (var j = 0; j < 7; j++)
            Expanded(child: _cell(widget.gridDates[i + j], mini: false)),
        ],
      ));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Column(children: rows),
    );
  }

  Widget _miniRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Row(
        children: [
          for (final d in _selectedWeek) Expanded(child: _cell(d, mini: true)),
        ],
      ),
    );
  }

  Widget _cell(DateTime date, {required bool mini}) {
    final isToday = date == widget.today;
    final isSel = date == widget.selected;
    final inMonth = date.month == _selMonth;
    final dots = widget.dotsByDay[date] ?? const <FpDot>[];

    final Color numBg = isSel
        ? FpColors.blue
        : isToday
            ? FpColors.ink1
            : const Color(0x00000000);
    final Color numFg = (isSel || isToday)
        ? FpColors.surface
        : inMonth
            ? FpColors.ink2
            : FpColors.ink3;
    final double sz = mini ? 22 : 26;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isSel) HapticFeedback.selectionClick();
        widget.onSelect(date);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mini ? 2 : 3, horizontal: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选中日轻微放大弹一下，比纯变色更灵动。
            AnimatedScale(
              scale: isSel ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: kFpEmphasized,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                curve: kFpEasing,
                width: sz,
                height: sz,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: numBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    inherit: false,
                    fontFamily: 'CupertinoSystemText',
                    fontSize: mini ? 11 : 12.5,
                    fontWeight:
                        (isToday || isSel) ? FontWeight.w700 : FontWeight.w500,
                    color: numFg,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final d in dots.take(mini ? 2 : 3))
                    Container(
                      width: mini ? 3 : 4,
                      height: mini ? 3 : 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSel ? FpColors.surface : _dotColor(d),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ 当日时间轴 ============================

/// `.tl`：8:00–21:00 小时刻度 + 绝对定位事件块 + 今日 now-line。
class FpDayTimeline extends StatelessWidget {
  const FpDayTimeline({
    super.key,
    required this.events,
    this.nowHour,
  });

  final List<FpTimelineEvent> events;
  final double? nowHour; // 非空且在范围内时画红线

  static const int _start = 8;
  static const int _end = 21;
  static const double _rowH = 52;

  @override
  Widget build(BuildContext context) {
    final height = (_end - _start + 1) * _rowH + 16;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          for (var h = _start; h <= _end; h++)
            Positioned(
              left: 0,
              right: 0,
              top: (h - _start) * _rowH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      h == _start ? '' : '$h:00',
                      textAlign: TextAlign.right,
                      style: FpText.micro.copyWith(fontSize: 10.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: ColoredBox(
                      color: FpColors.border,
                      child: SizedBox(height: 0.5, width: double.infinity),
                    ),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < events.length; i++) _event(events[i], i),
          if (nowHour != null && nowHour! >= _start && nowHour! <= _end)
            Positioned(
              left: 40,
              right: 4,
              top: (nowHour! - _start) * _rowH,
              child: const Row(
                children: [
                  _NowDot(),
                  Expanded(
                    child: ColoredBox(
                      color: FpColors.red,
                      child: SizedBox(height: 1),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _event(FpTimelineEvent ev, int index) {
    final hour = ev.hour.clamp(_start.toDouble(), _end - 0.5);
    final top = (hour - _start) * _rowH + 4 + index * 2;
    final (Color bg, Color line, Color fg) = switch (ev.style) {
      FpDot.red => (FpColors.redTint, FpColors.red, FpColors.red),
      FpDot.amber => (FpColors.amberTint, FpColors.amber, FpColors.amber),
      FpDot.blue => (FpColors.blueTint, FpColors.blue, FpColors.blue),
    };
    return Positioned(
      left: 48,
      right: 4,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ev.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                ev.onTap!();
              },
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(color: line, width: 2.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ev.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  inherit: false,
                  fontFamily: 'CupertinoSystemText',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: fg,
                  decoration: TextDecoration.none,
                ),
              ),
              Row(
                children: [
                  Icon(FpIcons.clock, size: 11, color: fg.withValues(alpha: 0.75)),
                  const SizedBox(width: 2),
                  Text(
                    ev.timeLabel,
                    style: TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: fg.withValues(alpha: 0.75),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 当前时刻红点：带一圈呼吸光环。
class _NowDot extends StatefulWidget {
  const _NowDot();

  @override
  State<_NowDot> createState() => _NowDotState();
}

class _NowDotState extends State<_NowDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final t = _c.value;
              return Container(
                width: 7 + t * 7,
                height: 7 + t * 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FpColors.red.withValues(alpha: (1 - t) * 0.35),
                ),
              );
            },
          ),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: FpColors.red, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
