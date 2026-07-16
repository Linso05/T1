import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ios_widgets.dart' show iosDensityProvider;

/// FocusPoint 设计系统调色板。色值 1:1 对照 uimd/T1_flutter_full_ui.html 的
/// CSS `:root` 变量，独立于旧的 T1Palette/IosPalette，避免混色。锁定浅色。
class FpColors {
  FpColors._();

  static const bg = Color(0xFFF7F7F5); // --bg 页面底
  static const surface = Color(0xFFFFFFFF); // --s 卡片白底
  static const border = Color(0xFFEDEDE9); // --b 边框/0.5px 分割线
  static const border2 = Color(0xFFD4D4CE); // --b2 次级边框/未选 chip

  static const ink1 = Color(0xFF111110); // --t1 主文字/实心按钮底
  static const ink2 = Color(0xFF6B6B69); // --t2 次级文字/tab 未选
  static const ink3 = Color(0xFFADADAB); // --t3 eyebrow/提示

  static const red = Color(0xFFB91C1C); // --r 紧急
  static const redTint = Color(0xFFFEF2F2); // --rt 紧急底
  static const redBorder = Color(0xFFFECACA); // --rb 紧急边

  static const amber = Color(0xFFA16207); // --am 异常
  static const amberTint = Color(0xFFFEFCE8); // --at 异常底
  static const amberBorder = Color(0xFFFDE68A); // --ab 异常边

  static const blue = Color(0xFF1D4ED8); // --bl 日历选中/蓝事件
  static const blueTint = Color(0xFFEFF6FF); // --blt 蓝底
  static const blueBorder = Color(0xFFBFDBFE); // chip-b 边

  static const green = Color(0xFF16A34A); // 状态正常（短信监听已启用）
}

/// uimd 统一缓动 CubicBezier(.4,0,.2,1)。
const Cubic kFpEasing = Cubic(0.4, 0.0, 0.2, 1.0);

/// 回弹缓动（滑块/选中态轻微过冲，更有弹性）。
const Cubic kFpEmphasized = Cubic(0.2, 0.9, 0.25, 1.0);

/// 统一动效时长令牌：按压/选中用 fast，容器过渡用 base，展开/入场用 slow。
class FpMotion {
  FpMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);
}

const String _fp = 'CupertinoSystemText';

/// FocusPoint 文字样式。全部 `inherit:false` + 显式 fontFamily，避免
/// TextStyle.lerp 在导航/转场时因 inherit 不一致而崩溃。
/// 字号通过 [fpFont] 乘显示密度，这里给基准值。
class FpText {
  FpText._();

  static const TextStyle eyebrow = TextStyle(
    inherit: false,
    fontFamily: _fp,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    color: FpColors.ink3,
    decoration: TextDecoration.none,
  );

  static const TextStyle pageTitle = TextStyle(
    inherit: false,
    fontFamily: _fp,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.75,
    height: 1.1,
    color: FpColors.ink1,
    decoration: TextDecoration.none,
  );

  static const TextStyle pageSub = TextStyle(
    inherit: false,
    fontFamily: _fp,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: FpColors.ink2,
    decoration: TextDecoration.none,
  );

  static const TextStyle sectionLabel = TextStyle(
    inherit: false,
    fontFamily: _fp,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: FpColors.ink3,
    decoration: TextDecoration.none,
  );

  static const TextStyle cardTitle = TextStyle(
    inherit: false,
    fontFamily: _fp,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
    color: FpColors.ink1,
    decoration: TextDecoration.none,
  );

  static const TextStyle meta = TextStyle(
    inherit: false,
    fontFamily: _fp,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: FpColors.ink2,
    decoration: TextDecoration.none,
  );

  static const TextStyle micro = TextStyle(
    inherit: false,
    fontFamily: _fp,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: FpColors.ink3,
    decoration: TextDecoration.none,
  );

  /// 大写小标签（uppercase eyebrow type）。
  static const TextStyle typeLabel = TextStyle(
    inherit: false,
    fontFamily: _fp,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: FpColors.ink3,
    decoration: TextDecoration.none,
  );
}

/// 圆角令牌。
class FpRadii {
  FpRadii._();
  static const card = 14.0;
  static const urgent = 16.0;
  static const group = 14.0;
  static const button = 9.0;
  static const chip = 4.0;
  static const segment = 10.0;
  static const segmentThumb = 8.0;
}

/// 字号乘显示密度（复用既有 iosDensityProvider 的 textScale）。
double fpFont(WidgetRef ref, double size) =>
    size * ref.watch(iosDensityProvider).textScale;

/// 间距乘显示密度（复用既有 spaceScale）。
double fpSpace(WidgetRef ref, double size) =>
    size * ref.watch(iosDensityProvider).spaceScale;
