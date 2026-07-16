import 'package:flutter/cupertino.dart';

import '../settings/settings_page.dart' show kAppDisplayVersion;

/// 启动页：盖在真正的首页之上，做一段品牌淡入，约 1s 后淡出露出 [child]。
/// 下层的 child 在启动页期间已开始构建/加载，过渡更顺。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child});
  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _slateTop = Color(0xFF172033);
  static const _slateBottom = Color(0xFF28374F);

  // 拉长到 1.3s，让「逐笔画出 Logo」的过程完整呈现。
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  bool _fadeOut = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    // 画完 + 停留后再淡出。
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _fadeOut = true);
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_gone)
          AnimatedOpacity(
            opacity: _fadeOut ? 0 : 1,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            onEnd: () {
              if (_fadeOut && mounted) setState(() => _gone = true);
            },
            child: IgnorePointer(child: _splash()),
          ),
      ],
    );
  }

  Widget _splash() {
    // 文案在 Logo 画完后半段淡入上浮。
    final textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
    );
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_slateTop, _slateBottom],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo 自绘（逐笔画出）。
                _LogoMark(progress: _intro),
                const SizedBox(height: 24),
                // 文案：Logo 画完后淡入 + 轻微上浮。
                FadeTransition(
                  opacity: textFade,
                  child: AnimatedBuilder(
                    animation: textFade,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, (1 - textFade.value) * 10),
                      child: child,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'T1',
                          style: TextStyle(
                            inherit: false,
                            fontFamily: 'CupertinoSystemText',
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: Color(0xFFFFFFFF),
                            decoration: TextDecoration.none,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          '法院送达 · 工作台',
                          style: TextStyle(
                            inherit: false,
                            fontFamily: 'CupertinoSystemText',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            color: Color(0xFF94A3B8),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: FadeTransition(
                  opacity: fade,
                  child: const Text(
                    'v$kAppDisplayVersion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: Color(0xFF64748B),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 品牌标记：逐笔画出——文书淡入 → 三行文字逐条「写入」→ 绿徽标弹入 → 对勾描边。
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.progress});
  final Animation<double> progress;

  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (_, _) {
        final t = progress.value;
        final docT = Curves.easeOutCubic.transform(_seg(t, 0.0, 0.4));
        final bar1 = Curves.easeOut.transform(_seg(t, 0.28, 0.50));
        final bar2 = Curves.easeOut.transform(_seg(t, 0.36, 0.58));
        final bar3 = Curves.easeOut.transform(_seg(t, 0.44, 0.66));
        final badgeT = Curves.easeOutBack.transform(_seg(t, 0.55, 0.82));
        final checkT = _seg(t, 0.72, 1.0);
        return SizedBox(
          width: 96,
          height: 108,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 文书：淡入 + 轻微放大
              Positioned(
                left: 8,
                top: 0,
                child: Opacity(
                  opacity: docT,
                  child: Transform.scale(
                    scale: 0.88 + 0.12 * docT,
                    child: Container(
                      width: 68,
                      height: 92,
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.25 * docT),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(28 * bar1),
                          const SizedBox(height: 8),
                          _bar(40 * bar2),
                          const SizedBox(height: 8),
                          _bar(22 * bar3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 送达完成绿色徽标：弹入 + 对勾描边
              Positioned(
                right: 0,
                bottom: 0,
                child: Transform.scale(
                  scale: badgeT.clamp(0.0, 1.2),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF1B2737), width: 3.5),
                    ),
                    child: CustomPaint(painter: _CheckPainter(checkT)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(double w) => Container(
        width: w,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(2.5),
        ),
      );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.44, h * 0.66)
      ..lineTo(w * 0.70, h * 0.36);
    // 按进度描边画出（PathMetric 截取部分路径）。
    final metric = path.computeMetrics().first;
    canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)), paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
