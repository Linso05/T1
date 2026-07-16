import 'package:flutter/widgets.dart';

/// Tabler 图标常量（内置 TablerIcons 字体，codepoints 取自
/// @tabler/icons-webfont@3.31.0）。页面只引用 FpIcons.*，与字体来源解耦。
/// 全部 const，便于在 const widget 构造中使用。
class FpIcons {
  FpIcons._();

  static const String _f = 'TablerIcons';

  // 导航 / 箭头
  static const IconData chevronRight = IconData(0xea61, fontFamily: _f);
  static const IconData chevronDown = IconData(0xea5f, fontFamily: _f);
  static const IconData chevronUp = IconData(0xea62, fontFamily: _f);
  static const IconData chevronLeft = IconData(0xea60, fontFamily: _f);
  static const IconData arrowLeft = IconData(0xea19, fontFamily: _f);
  static const IconData arrowUp = IconData(0xea25, fontFamily: _f);
  static const IconData arrowRight = IconData(0xea1f, fontFamily: _f);

  // 底栏 / 功能
  static const IconData calendar = IconData(0xea53, fontFamily: _f);
  static const IconData calendarEvent = IconData(0xea52, fontFamily: _f);
  static const IconData inbox = IconData(0xeac4, fontFamily: _f);
  static const IconData messageCircle = IconData(0xeaed, fontFamily: _f);
  static const IconData tool = IconData(0xeb40, fontFamily: _f);
  static const IconData settings = IconData(0xeb20, fontFamily: _f);

  // 动作
  static const IconData download = IconData(0xea96, fontFamily: _f);
  static const IconData robot = IconData(0xf00b, fontFamily: _f);
  static const IconData archive = IconData(0xea0b, fontFamily: _f);
  static const IconData externalLink = IconData(0xea99, fontFamily: _f);
  static const IconData eye = IconData(0xea9a, fontFamily: _f);
  static const IconData search = IconData(0xeb1c, fontFamily: _f);
  static const IconData plus = IconData(0xeb0b, fontFamily: _f);
  static const IconData layoutColumns = IconData(0xead4, fontFamily: _f);
  static const IconData refresh = IconData(0xeb13, fontFamily: _f);
  static const IconData trash = IconData(0xeb41, fontFamily: _f);
  static const IconData link = IconData(0xeade, fontFamily: _f);

  // 信息 / 杂项
  static const IconData infoCircle = IconData(0xeac5, fontFamily: _f);
  static const IconData clock = IconData(0xea70, fontFamily: _f);
  static const IconData fileText = IconData(0xeaa2, fontFamily: _f);
  static const IconData circleCheck = IconData(0xea67, fontFamily: _f);
  static const IconData alertTriangle = IconData(0xea06, fontFamily: _f);
  static const IconData textSize = IconData(0xf2b1, fontFamily: _f);
  static const IconData moon = IconData(0xeaf8, fontFamily: _f);
  static const IconData message = IconData(0xeaef, fontFamily: _f);
  static const IconData messageDots = IconData(0xeaee, fontFamily: _f);
  static const IconData brandWechat = IconData(0xf5f3, fontFamily: _f);
  static const IconData scale = IconData(0xebc2, fontFamily: _f);
  static const IconData gavel = IconData(0xef90, fontFamily: _f);
}
