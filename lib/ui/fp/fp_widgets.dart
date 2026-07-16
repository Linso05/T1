import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ios_widgets.dart' show iosDensityProvider;
import 'fp_icons.dart';
import 'fp_tokens.dart';

// ============================ 页面外壳 ============================

/// 页面外壳：底色 + 显示密度文字缩放（全局 textScaler，无需逐组件乘）+ SafeArea。
class FpScreen extends ConsumerWidget {
  const FpScreen({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = false,
    this.background = FpColors.bg,
  });

  final Widget child;
  final bool top;
  final bool bottom;
  final Color background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(iosDensityProvider).textScale;
    final mq = MediaQuery.of(context);
    return ColoredBox(
      color: background,
      child: MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.linear(scale)),
        child: SafeArea(top: top, bottom: bottom, child: child),
      ),
    );
  }
}

/// 按压回弹（mockup `.uc:active{transform:scale(.985)}`）。
class FpPressable extends StatefulWidget {
  const FpPressable({super.key, required this.child, this.onTap, this.scale = 0.985});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<FpPressable> createState() => _FpPressableState();
}

class _FpPressableState extends State<FpPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 100),
        curve: kFpEasing,
        child: widget.child,
      ),
    );
  }
}

/// 列表项入场动效：首次出现时淡入 + 轻微上滑（滚入视图也会复触发，属预期）。
/// [index] 用于首屏轻微错峰（cascade）：序号越大延迟越久，上限约 110ms，
/// 保证滚动时不会有明显滞后。
class FpEntrance extends StatefulWidget {
  const FpEntrance({
    super.key,
    required this.child,
    this.offsetY = 8,
    this.index = 0,
  });

  final Widget child;
  final double offsetY;
  final int index;

  @override
  State<FpEntrance> createState() => _FpEntranceState();
}

class _FpEntranceState extends State<FpEntrance> {
  // 只给首屏前 [_maxAnimated] 项做入场；靠后的项（滚动时才出现）直接显示，
  // 避免快速滚动中大量卡片反复淡入造成合成卡顿。
  static const _maxAnimated = 12;
  bool _show = false;

  bool get _animate => widget.index <= _maxAnimated;

  @override
  void initState() {
    super.initState();
    if (!_animate) return;
    final ms = widget.index.clamp(0, 5) * 22;
    if (ms == 0) {
      _show = true;
    } else {
      Future.delayed(Duration(milliseconds: ms), () {
        if (mounted) setState(() => _show = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _show ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 260),
      curve: kFpEasing,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0, 1).toDouble(),
        child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offsetY), child: child),
      ),
      child: widget.child,
    );
  }
}

// ============================ 顶部 Header ============================

/// `.tp`：eyebrow + 大标题 + 副标题，右侧可放图标按钮。
class FpHeader extends StatelessWidget {
  const FpHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(22, 4, 18, 0),
    this.titleHeroTag,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final EdgeInsets padding;

  /// 传了就把大标题包成 Hero（做「标题字体 morph」无缝转场到子页返回栏同名标签）。
  final Object? titleHeroTag;

  @override
  Widget build(BuildContext context) {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null)
          Text(eyebrow!.toUpperCase(), style: FpText.eyebrow),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _maybeHero(
            titleHeroTag,
            shuttle: titleHeroTag == null
                ? null
                : fpTitleFlightShuttle(title,
                    from: 28, to: 15, weight: FontWeight.w600),
            Text(title, style: FpText.pageTitle),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(subtitle!, style: FpText.pageSub),
          ),
      ],
    );
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: left),
          if (actions.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }
}

/// Header 右侧图标按钮（`.ti-icons i`）。
class FpIconButton extends StatelessWidget {
  const FpIconButton({super.key, required this.icon, this.onTap, this.color = FpColors.ink2, this.size = 20});

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FpPressable(
      scale: 0.86,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

// ============================ 分段控件 ============================

class FpSegment<T> {
  const FpSegment(this.value, this.label);
  final T value;
  final String label;
}

/// `.seg/.sg`：灰轨 + 选中白块（自绘）。
class FpSegmented<T> extends StatelessWidget {
  const FpSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.margin = const EdgeInsets.fromLTRB(22, 13, 22, 0),
  });

  final List<FpSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final n = segments.length;
    final idx = segments.indexWhere((s) => s.value == value);
    final align = n <= 1 ? 0.0 : -1 + 2 * (idx < 0 ? 0 : idx) / (n - 1);
    return Padding(
      padding: margin,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: FpColors.border,
          borderRadius: BorderRadius.circular(FpRadii.segment),
        ),
        child: SizedBox(
          height: 30,
          child: Stack(
            children: [
              // 横移的白色滑块
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: kFpEmphasized,
                alignment: Alignment(align, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: FpColors.surface,
                      borderRadius:
                          BorderRadius.circular(FpRadii.segmentThumb),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final s in segments)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (s.value != value) HapticFeedback.selectionClick();
                          onChanged(s.value);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: kFpEasing,
                            style: TextStyle(
                              inherit: false,
                              fontFamily: 'CupertinoSystemText',
                              fontSize: 13,
                              fontWeight: s.value == value
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color:
                                  s.value == value ? FpColors.ink1 : FpColors.ink3,
                              decoration: TextDecoration.none,
                            ),
                            child: Text(s.label),
                          ),
                        ),
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

// ============================ Tab 条 ============================

class FpTab<T> {
  const FpTab(this.value, this.label);
  final T value;
  final String label;
}

/// 文字 tab 条（横向可滚动，选中下划线）。
class FpTabStrip<T> extends StatelessWidget {
  const FpTabStrip({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 0),
  });

  final List<FpTab<T>> tabs;
  final T value;
  final ValueChanged<T> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final t in tabs)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (t.value != value) HapticFeedback.selectionClick();
                  onChanged(t.value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: kFpEasing,
                  margin: const EdgeInsets.only(right: 18),
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t.value == value
                            ? FpColors.ink1
                            : const Color(0x00000000),
                        width: 2,
                      ),
                    ),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: kFpEasing,
                    style: TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 15,
                      fontWeight:
                          t.value == value ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.2,
                      color: t.value == value ? FpColors.ink1 : FpColors.ink3,
                      decoration: TextDecoration.none,
                    ),
                    child: Text(t.label),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================ 区段标题 ============================

/// `.lbl`：全大写小标签。
class FpSectionLabel extends StatelessWidget {
  const FpSectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(4, 18, 4, 7)});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text.toUpperCase(), style: FpText.sectionLabel),
    );
  }
}

// ============================ 卡片 ============================

/// `.uc`：紧急红底卡。
class FpUrgentCard extends StatelessWidget {
  const FpUrgentCard({
    super.key,
    required this.type,
    required this.title,
    required this.meta,
    required this.footer,
    this.onTap,
  });

  final String type;
  final String title;
  final String meta;
  final String footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FpPressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        decoration: BoxDecoration(
          color: FpColors.redTint,
          borderRadius: BorderRadius.circular(FpRadii.urgent),
          border: Border.all(color: FpColors.redBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(
                      color: FpColors.red, shape: BoxShape.circle),
                ),
                Text(
                  type.toUpperCase(),
                  style: const TextStyle(
                    inherit: false,
                    fontFamily: 'CupertinoSystemText',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: FpColors.red,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                inherit: false,
                fontFamily: 'CupertinoSystemText',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                height: 1.25,
                color: FpColors.ink1,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                inherit: false,
                fontFamily: 'CupertinoSystemText',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: FpColors.ink2,
                decoration: TextDecoration.none,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: FpColors.redBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      footer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        inherit: false,
                        fontFamily: 'CupertinoSystemText',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: FpColors.red,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        '查看',
                        style: TextStyle(
                          inherit: false,
                          fontFamily: 'CupertinoSystemText',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: FpColors.red,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Icon(FpIcons.chevronRight, size: 13, color: FpColors.red),
                    ],
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

/// `.card`：白底任务卡。
class FpTaskCard extends StatelessWidget {
  const FpTaskCard({
    super.key,
    required this.type,
    this.time,
    required this.title,
    required this.meta,
    this.chips = const [],
    this.cta,
    this.unread = false,
    this.urgent = false,
    this.opacity = 1,
    this.onTap,
    this.heroTag,
  });

  final String type;
  final String? time;
  final String title;
  final String meta;
  final List<Widget> chips;
  final String? cta;
  final bool unread;
  final bool urgent;
  final double opacity;
  final VoidCallback? onTap;

  /// 传了就把标题包成 Hero（做「字体 morph」无缝进入详情）。
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: FpPressable(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: FpColors.surface,
            borderRadius: BorderRadius.circular(FpRadii.card),
            // 日程卡：去边框，改轻投影「浮起」感（区别于送达的平铺无框卡）。
            // 紧急卡带一点红晕，拉开层级。
            boxShadow: [
              BoxShadow(
                color: urgent ? const Color(0x16B91C1C) : const Color(0x0F000000),
                blurRadius: urgent ? 14 : 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(type.toUpperCase(), style: FpText.typeLabel)),
                  if (time != null)
                    Text(time!, style: FpText.micro),
                ],
              ),
              const SizedBox(height: 3),
              _maybeHero(
                heroTag,
                shuttle: heroTag == null ? null : fpTitleFlightShuttle(title),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    inherit: false,
                    fontFamily: 'CupertinoSystemText',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.3,
                    color: FpColors.ink1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FpText.meta,
              ),
              if (chips.isNotEmpty || cta != null) ...[
                Container(
                  margin: const EdgeInsets.only(top: 9),
                  padding: const EdgeInsets.only(top: 9),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: FpColors.border)),
                  ),
                  child: Row(
                    children: [
                      if (unread)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: const BoxDecoration(
                              color: FpColors.red, shape: BoxShape.circle),
                        ),
                      ...chips,
                      const Spacer(),
                      if (cta != null)
                        Row(
                          children: [
                            Text(cta!, style: FpText.micro),
                            Icon(FpIcons.chevronRight,
                                size: 12, color: FpColors.ink3),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
            // 紧急：右上角红色折角角标（卡片本身样式与普通卡一致）
            if (urgent)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(FpRadii.card),
                  child: const CustomPaint(painter: _CornerBadgePainter()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 右上角折角角标（紧急标记），ClipRRect 裁到卡片圆角。
class _CornerBadgePainter extends CustomPainter {
  const _CornerBadgePainter();
  static const double _leg = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FpColors.red
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width - _leg, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, _leg)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerBadgePainter old) => false;
}

// ============================ Chip / 标签 ============================

enum FpChipStyle { normal, solid, red, amber, blue }

/// `.chip` 系列彩色标签。
class FpChip extends StatelessWidget {
  const FpChip(this.text, {super.key, this.style = FpChipStyle.normal});
  final String text;
  final FpChipStyle style;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (style) {
      FpChipStyle.normal => (FpColors.bg, FpColors.ink2, FpColors.border2),
      FpChipStyle.solid => (FpColors.ink1, FpColors.surface, FpColors.ink1),
      FpChipStyle.red => (FpColors.redTint, FpColors.red, FpColors.redBorder),
      FpChipStyle.amber => (FpColors.amberTint, FpColors.amber, FpColors.amberBorder),
      FpChipStyle.blue => (FpColors.blueTint, FpColors.blue, FpColors.blueBorder),
    };
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(FpRadii.chip),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          inherit: false,
          fontFamily: 'CupertinoSystemText',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// `.fc on/off`：横向滑动筛选 chip。
class FpFilterChip extends StatelessWidget {
  const FpFilterChip({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FpPressable(
      scale: 0.94,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: kFpEasing,
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? FpColors.ink1 : FpColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? FpColors.ink1 : FpColors.border2),
        ),
        child: Text(
          text,
          style: TextStyle(
            inherit: false,
            fontFamily: 'CupertinoSystemText',
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: selected ? FpColors.surface : FpColors.ink2,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// 总筛选面板里的一组（标题 + 横滑 chips），端口 L2 `InlineFilterGroup`。
class FpInlineFilterGroup extends StatelessWidget {
  const FpInlineFilterGroup({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(
            title,
            style: const TextStyle(
              inherit: false,
              fontFamily: 'CupertinoSystemText',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FpColors.ink2,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: children),
        ),
      ],
    );
  }
}

/// 横向筛选条容器（`.filter`）。
class FpFilterBar extends StatelessWidget {
  const FpFilterBar({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(14, 11, 14, 2),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      physics: const BouncingScrollPhysics(),
      child: Row(children: children),
    );
  }
}

// ============================ 可展开卡（送达） ============================

enum FpCardBorder { normal, urgent, warn }

/// `.ecard`：可展开送达卡（AnimatedSize 展开 + chevron 旋转）。
/// 标题/类型条等共享元素：传了 heroTag 就包 Hero（列表→详情过渡）。文本用
/// inherit:false 显式样式，无需 Material 包裹即可安全飞行。
Widget _maybeHero(Object? tag, Widget child,
        {HeroFlightShuttleBuilder? shuttle}) =>
    tag == null
        ? child
        : Hero(tag: tag, flightShuttleBuilder: shuttle, child: child);

/// 标题共享元素 flight shuttle：飞行途中按进度**插值字号**（列表 [from] ↔ 详情 [to]），
/// 让标题「字体跟随放大」平滑 morph，而不是像素缩放——无缝转场的高级感来源。
HeroFlightShuttleBuilder fpTitleFlightShuttle(String text,
    {double from = 14, double to = 21, FontWeight weight = FontWeight.w700}) {
  // 关键：用「较大字号渲染一次 + Transform.scale」平滑缩放，
  // 不再逐帧改 fontSize（那会每帧重排文字、看着一格一格跳）。缩放是 GPU 连续变换，丝滑。
  final base = from > to ? from : to;
  return (flightContext, animation, direction, fromContext, toContext) {
    final text0 = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      textDirection: TextDirection.ltr,
      style: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemText',
        fontSize: base,
        fontWeight: weight,
        letterSpacing: -0.4,
        height: 1.15,
        color: FpColors.ink1,
        decoration: TextDecoration.none,
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(animation.value);
        final size = from + (to - from) * t;
        return Transform.scale(
          scale: size / base,
          alignment: Alignment.centerLeft,
          child: child,
        );
      },
      child: text0,
    );
  };
}

class FpExpandableCard extends StatefulWidget {
  const FpExpandableCard({
    super.key,
    required this.type,
    this.typeColor = FpColors.ink3,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.border = FpCardBorder.normal,
    this.showBorder = true,
    this.initiallyExpanded = false,
    this.opacity = 1,
    this.onExpand,
    this.heroTag,
    required this.bodyBuilder,
  });

  final String type;
  final Color typeColor;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final FpCardBorder border;
  final bool showBorder;
  final bool initiallyExpanded;
  final double opacity;
  final VoidCallback? onExpand;
  final Object? heroTag;
  final WidgetBuilder bodyBuilder;

  @override
  State<FpExpandableCard> createState() => _FpExpandableCardState();
}

class _FpExpandableCardState extends State<FpExpandableCard> {
  late bool _open = widget.initiallyExpanded;

  void _toggle() {
    final next = !_open;
    HapticFeedback.selectionClick();
    setState(() => _open = next);
    if (next) widget.onExpand?.call();
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor = switch (widget.border) {
      FpCardBorder.urgent => FpColors.redBorder,
      FpCardBorder.warn => FpColors.amberBorder,
      FpCardBorder.normal => _open ? FpColors.border2 : FpColors.border,
    };
    return Opacity(
      opacity: widget.opacity,
      child: AnimatedContainer(
        duration: FpMotion.base,
        curve: kFpEasing,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: FpColors.surface,
          borderRadius: BorderRadius.circular(FpRadii.card),
          border: widget.showBorder ? Border.all(color: borderColor) : null,
          // 展开态轻微抬升，突出当前聚焦的卡片。
          boxShadow: _open
              ? const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.type.toUpperCase(),
                            style: FpText.typeLabel.copyWith(color: widget.typeColor),
                          ),
                          const SizedBox(height: 2),
                          _maybeHero(
                            widget.heroTag,
                            shuttle: widget.heroTag == null
                                ? null
                                : fpTitleFlightShuttle(widget.title),
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                inherit: false,
                                fontFamily: 'CupertinoSystemText',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                height: 1.3,
                                color: FpColors.ink1,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FpText.meta,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.trailingText != null)
                          Text(widget.trailingText!, style: FpText.micro),
                        const SizedBox(height: 5),
                        AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: kFpEasing,
                          child: Icon(FpIcons.chevronDown,
                              size: 16, color: FpColors.ink3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: kFpEasing,
              alignment: Alignment.topCenter,
              child: _open
                  ? TweenAnimationBuilder<double>(
                      key: const ValueKey('fp-card-body'),
                      tween: Tween(begin: 0, end: 1),
                      duration: FpMotion.base,
                      curve: kFpEasing,
                      builder: (_, t, child) =>
                          Opacity(opacity: t.clamp(0, 1).toDouble(), child: child),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                        decoration: const BoxDecoration(
                          border:
                              Border(top: BorderSide(color: FpColors.border)),
                        ),
                        child: widget.bodyBuilder(context),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.ekv`/`.kv`：键值行。
class FpKvRow extends StatelessWidget {
  const FpKvRow(this.label, this.value, {super.key, this.hot = false, this.last = false});
  final String label;
  final String value;
  final bool hot;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: FpColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FpText.meta.copyWith(color: FpColors.ink3)),
          const Spacer(),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                inherit: false,
                fontFamily: 'CupertinoSystemText',
                fontSize: 12.5,
                fontWeight: hot ? FontWeight.w700 : FontWeight.w500,
                color: hot ? FpColors.red : FpColors.ink1,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ 动作按钮 ============================

/// `.ea`/`.act`：图标 + 文字按钮。
class FpActionButton extends StatelessWidget {
  const FpActionButton({
    super.key,
    required this.text,
    this.icon,
    this.primary = false,
    this.destructive = false,
    this.onPressed,
  });

  final String text;
  final IconData? icon;
  final bool primary;
  final bool destructive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = primary
        ? FpColors.surface
        : destructive
            ? FpColors.red
            : FpColors.ink1;
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: primary ? FpColors.ink1 : FpColors.bg,
            borderRadius: BorderRadius.circular(FpRadii.button),
            border: Border.all(color: primary ? FpColors.ink1 : FpColors.border2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: TextStyle(
                  inherit: false,
                  fontFamily: 'CupertinoSystemText',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ 底部 Tab 栏 ============================

class FpTabItem {
  const FpTabItem({required this.icon, required this.label, this.badge = 0});
  final IconData icon;
  final String label;
  final int badge;
}

/// `.tab`：自绘底栏（图标 22 + 标签 10 + 红 badge）。
class FpTabBar extends StatelessWidget {
  const FpTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.position,
  });

  final List<FpTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// 连续偏移（0..n-1），用于滑动指示器跟随；null 时取 currentIndex。
  final double? position;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final pos = position ?? currentIndex.toDouble();
    return Container(
      decoration: const BoxDecoration(
        color: FpColors.surface,
        border: Border(top: BorderSide(color: FpColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(4, 9, 4, 8 + bottomInset),
      child: LayoutBuilder(
        builder: (ctx, cons) {
          final tabW = cons.maxWidth / items.length;
          const pillW = 52.0;
          return Stack(
            children: [
              // 滑动胶囊高亮：随 pos 横移，落在选中图标背后。
              Positioned(
                top: 2,
                left: pos * tabW + (tabW - pillW) / 2,
                width: pillW,
                height: 30,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x11111110), // ink1 ~6% 透明
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _item(items[i], i == currentIndex, () {
                          HapticFeedback.selectionClick();
                          onTap(i);
                        }),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _item(FpTabItem it, bool on, VoidCallback tap) {
    final color = on ? FpColors.ink1 : FpColors.ink3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: on ? 1.18 : 1,
                duration: const Duration(milliseconds: 320),
                curve: kFpEmphasized,
                child: Icon(it.icon, size: 22, color: color),
              ),
              if (it.badge > 0)
                Positioned(
                  top: -3,
                  right: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 15),
                    height: 15,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: FpColors.red,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: kFpEmphasized,
                      transitionBuilder: (c, a) => ScaleTransition(
                        scale: a,
                        child: FadeTransition(opacity: a, child: c),
                      ),
                      child: Text(
                        it.badge > 99 ? '99+' : '${it.badge}',
                        key: ValueKey(it.badge),
                        style: const TextStyle(
                          inherit: false,
                          fontFamily: 'CupertinoSystemText',
                          fontSize: 9,
                          height: 1,
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
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: kFpEasing,
            style: TextStyle(
              inherit: false,
              fontFamily: 'CupertinoSystemText',
              fontSize: 10,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: color,
              decoration: TextDecoration.none,
            ),
            child: Text(it.label),
          ),
        ],
      ),
    );
  }
}

// ============================ 下拉刷新 ============================

/// 品牌化下拉刷新指示器：拖动时文书刷新图标渐显并旋转，触发后转圈。
Widget _fpRefreshBuilder(
  BuildContext context,
  RefreshIndicatorMode refreshState,
  double pulledExtent,
  double refreshTriggerPullDistance,
  double refreshIndicatorExtent,
) {
  final frac = (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
  final refreshing = refreshState == RefreshIndicatorMode.refresh ||
      refreshState == RefreshIndicatorMode.armed;
  return Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 14),
      child: refreshing
          ? const CupertinoActivityIndicator(radius: 11, color: FpColors.ink2)
          : Opacity(
              opacity: frac,
              child: Transform.rotate(
                angle: frac * 3.14159,
                child: Icon(FpIcons.refresh, size: 20, color: FpColors.ink2),
              ),
            ),
    ),
  );
}

/// 统一的品牌化 `CupertinoSliverRefreshControl`。
CupertinoSliverRefreshControl fpRefreshControl(
        Future<void> Function() onRefresh) =>
    CupertinoSliverRefreshControl(
        onRefresh: onRefresh, builder: _fpRefreshBuilder);

// ============================ 开关 ============================

/// `.tog`：iOS 风格开关。
class FpToggle extends StatelessWidget {
  const FpToggle({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: kFpEasing,
        width: 38,
        height: 22,
        decoration: BoxDecoration(
          color: value ? FpColors.ink1 : FpColors.border2,
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: kFpEasing,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
                color: FpColors.surface, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

// ============================ 设置组 ============================

/// `.set-sec` + `.set-group`：带标题的圆角设置组。
class FpSettingsSection extends StatelessWidget {
  const FpSettingsSection({super.key, this.label, required this.children});
  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
              child: Text(label!.toUpperCase(), style: FpText.sectionLabel),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: FpColors.surface,
              borderRadius: BorderRadius.circular(FpRadii.group),
              border: Border.all(color: FpColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FpRadii.group),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.set-row`：设置行（彩色方图标 + 标题/副标题 + 尾件）。
class FpSettingRow extends StatelessWidget {
  const FpSettingRow({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.destructive = false,
    this.last = false,
    this.opacity = 1,
    this.iconSpinning = false,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool destructive;
  final bool last;
  final double opacity;
  final bool iconSpinning;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: FpColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: iconSpinning
                    ? const CupertinoActivityIndicator(
                        radius: 8, color: FpColors.surface)
                    : Icon(icon, size: 16, color: FpColors.surface),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        inherit: false,
                        fontFamily: 'CupertinoSystemText',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: destructive ? FpColors.red : FpColors.ink1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!, style: FpText.micro),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ 空状态 / 返回栏 ============================

class FpEmptyState extends StatelessWidget {
  const FpEmptyState({super.key, required this.title, this.subtitle, this.icon});
  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: FpMotion.slow,
          curve: kFpEasing,
          builder: (_, t, child) => Opacity(
            opacity: t.clamp(0, 1).toDouble(),
            child: Transform.translate(
                offset: Offset(0, (1 - t) * 10), child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标带一个轻微的缩放弹入。
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: kFpEmphasized,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child:
                    Icon(icon ?? FpIcons.inbox, size: 40, color: FpColors.ink3),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  inherit: false,
                  fontFamily: 'CupertinoSystemText',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FpColors.ink2,
                  decoration: TextDecoration.none,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(subtitle!,
                    textAlign: TextAlign.center, style: FpText.micro),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 错误态：图标 + 文案 + 重试。
class FpErrorState extends StatelessWidget {
  const FpErrorState({
    super.key,
    this.title = '加载遇到问题',
    this.subtitle,
    this.onRetry,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FpIcons.alertTriangle, size: 38, color: FpColors.amber),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                inherit: false,
                fontFamily: 'CupertinoSystemText',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FpColors.ink2,
                decoration: TextDecoration.none,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: FpText.micro),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FpActionButton(text: '重试', icon: FpIcons.refresh, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// 轻量 Markdown 渲染（零依赖，面向大模型对话输出的常见子集）：
/// 支持 `#/##/###` 标题、`- / * / •` 无序列表、`1.` 有序列表、`**加粗**`、
/// 行内 `code`、以及 ```` ``` ```` 代码围栏（整块等宽显示）。其余按普通段落处理。
class FpMarkdown extends StatelessWidget {
  const FpMarkdown(
    this.text, {
    super.key,
    this.color = FpColors.ink1,
    this.fontSize = 13,
  });

  final String text;
  final Color color;
  final double fontSize;

  static const _mono = 'monospace';
  static final _inline = RegExp(r'(\*\*(.+?)\*\*|`([^`]+?)`)');

  TextStyle _base(FontWeight w, double s) => TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemText',
        fontSize: s,
        height: 1.5,
        fontWeight: w,
        color: color,
        decoration: TextDecoration.none,
      );

  /// 解析一行里的 `**加粗**` 与行内 `code`。
  Widget _rich(String s, {FontWeight weight = FontWeight.w500, double? size}) {
    final fs = size ?? fontSize;
    final spans = <TextSpan>[];
    var idx = 0;
    for (final m in _inline.allMatches(s)) {
      if (m.start > idx) spans.add(TextSpan(text: s.substring(idx, m.start)));
      if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(2),
            style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(3),
            style: const TextStyle(
                fontFamily: _mono,
                fontSize: 12,
                backgroundColor: FpColors.bg,
                color: FpColors.amber)));
      }
      idx = m.end;
    }
    if (idx < s.length) spans.add(TextSpan(text: s.substring(idx)));
    return Text.rich(TextSpan(style: _base(weight, fs), children: spans));
  }

  Widget _listItem(String marker, String content) => Padding(
        padding: const EdgeInsets.only(bottom: 2, top: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 18,
                child: Text(marker, style: _base(FontWeight.w700, fontSize))),
            Expanded(child: _rich(content)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final children = <Widget>[];
    final codeBuf = <String>[];
    var inCode = false;

    void flushCode() {
      if (codeBuf.isEmpty) return;
      children.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: FpColors.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: FpColors.border),
        ),
        child: Text(
          codeBuf.join('\n'),
          style: const TextStyle(
            inherit: false,
            fontFamily: _mono,
            fontSize: 12,
            height: 1.45,
            color: FpColors.ink1,
            decoration: TextDecoration.none,
          ),
        ),
      ));
      codeBuf.clear();
    }

    for (final raw in lines) {
      if (raw.trimLeft().startsWith('```')) {
        if (inCode) {
          flushCode();
          inCode = false;
        } else {
          inCode = true;
        }
        continue;
      }
      if (inCode) {
        codeBuf.add(raw);
        continue;
      }
      if (raw.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      final trimmed = raw.trimLeft();
      final h = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
      if (h != null) {
        final level = h.group(1)!.length;
        children.add(Padding(
          padding: EdgeInsets.only(top: children.isEmpty ? 0 : 4, bottom: 2),
          child: _rich(h.group(2)!,
              weight: FontWeight.w700,
              size: fontSize + (level == 1 ? 3 : (level == 2 ? 1.5 : 0.5))),
        ));
        continue;
      }
      final b = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (b != null) {
        children.add(_listItem('•', b.group(1)!));
        continue;
      }
      final n = RegExp(r'^(\d+)[.、)]\s+(.*)$').firstMatch(trimmed);
      if (n != null) {
        children.add(_listItem('${n.group(1)}.', n.group(2)!));
        continue;
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: _rich(raw),
      ));
    }
    if (inCode) flushCode();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// `.det-nav`：详情/PDF 顶部返回栏。
class FpBackBar extends StatelessWidget {
  const FpBackBar({
    super.key,
    required this.label,
    required this.onBack,
    this.color = FpColors.ink1,
    this.actions = const [],
    this.labelHeroTag,
  });

  final String label;
  final VoidCallback onBack;
  final Color color;
  final List<Widget> actions;

  /// 传了就把返回标签包成 Hero（与来源页大标题同 tag，做字体 morph 无缝返回）。
  final Object? labelHeroTag;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FpIcons.chevronLeft, size: 20, color: color),
                const SizedBox(width: 2),
                _maybeHero(
                  labelHeroTag,
                  shuttle: labelHeroTag == null
                      ? null
                      : fpTitleFlightShuttle(label,
                          from: 28, to: 15, weight: FontWeight.w600),
                  Text(
                    label,
                    style: TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: color,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// iOS 确认弹窗（沿用原生 Cupertino 弹窗）。
Future<bool> showFpConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  bool destructive = false,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result == true;
}

// ============================ 轻提示 / 撤销 ============================

/// 底部轻提示，可带「撤销」等操作；3 秒自动消失。
void showFpToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).padding.bottom + 76;
      return Positioned(
        left: 16,
        right: 16,
        bottom: bottom,
        child: _FpToast(
          message: message,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  remove();
                  onAction();
                },
        ),
      );
    },
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), remove);
}

class _FpToast extends StatelessWidget {
  const _FpToast({required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: kFpEasing,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0, 1).toDouble(),
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: FpColors.ink1,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  inherit: false,
                  fontFamily: 'CupertinoSystemText',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: FpColors.surface,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7FB2FF),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================ 骨架屏 ============================

/// 列表加载骨架（替代转圈），带轻微呼吸闪烁。
class FpSkeletonList extends StatefulWidget {
  const FpSkeletonList({super.key, this.count = 6});
  final int count;

  @override
  State<FpSkeletonList> createState() => _FpSkeletonListState();
}

class _FpSkeletonListState extends State<FpSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final op = 0.45 + 0.35 * _c.value;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          itemCount: widget.count,
          itemBuilder: (_, _) => Opacity(
            opacity: op,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FpColors.surface,
                borderRadius: BorderRadius.circular(FpRadii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(70, 10),
                  const SizedBox(height: 10),
                  _bar(double.infinity, 13),
                  const SizedBox(height: 8),
                  _bar(180, 11),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: FpColors.border,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}
