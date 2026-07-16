import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';

import 'fp_tokens.dart';

/// 共享轴转场（Material Motion）：横向滑动 + 淡入淡出，带纵深感。
/// 替代默认 CupertinoPageRoute，让每次页面切换都有一致的“极致”过渡。
/// 注意：换用后失去 iOS 边缘侧滑返回手势——各详情/设置页均有显式返回栏兜底。
Route<T> fpSharedAxisRoute<T>(
  WidgetBuilder builder, {
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: type,
      fillColor: FpColors.bg,
      child: child,
    ),
  );
}

/// Z 轴缩放转场（zoom + fade）：进入详情用，像“放大进入”那张卡片。
Route<T> fpZoomRoute<T>(WidgetBuilder builder) =>
    fpSharedAxisRoute<T>(builder, type: SharedAxisTransitionType.scaled);
