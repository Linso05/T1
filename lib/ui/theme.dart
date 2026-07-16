import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'fp/fp_tokens.dart';

/// 全 App 唯一调色源，色值 1:1 对齐 L2 的 `T1Palette`（docs/T1_v5_elegant.html）。
/// FocusedXxx 在 L2 里都是 T1Palette 的别名，这里直接用 T1Palette.*。
/// 锁定浅色，不做深色模式。
class T1Palette {
  T1Palette._();
  static const bg = Color(0xFFF8F8F6);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFEDEDE9); // FocusedLine
  static const border2 = Color(0xFFD6D6D0); // FocusedLine2
  static const ink1 = Color(0xFF111110); // FocusedInk
  static const ink2 = Color(0xFF737370); // FocusedInk2
  static const ink3 = Color(0xFFB8B8B4); // FocusedInk3
  static const red = Color(0xFFB91C1C); // FocusedRed
  static const redTint = Color(0xFFFEF2F2); // FocusedRedBg
  static const redBorder = Color(0xFFFFCCCC); // FocusedRedBorder
  static const amber = Color(0xFFA16207); // FocusedAmber
  static const amberTint = Color(0xFFFEFCE8); // FocusedAmberBg
  static const amberBorder = Color(0xFFFDE68A); // FocusedAmberBorder
  static const separator = border;
}

/// L2 统一缓动曲线 CubicBezier(0.4, 0, 0.2, 1)。
const Cubic kFocusedEasing = Cubic(0.4, 0.0, 0.2, 1.0);

ThemeData buildT1Theme() {
  const scheme = ColorScheme.light(
    primary: T1Palette.ink1,
    onPrimary: T1Palette.surface,
    primaryContainer: T1Palette.border,
    onPrimaryContainer: T1Palette.ink1,
    secondary: T1Palette.ink1,
    onSecondary: T1Palette.surface,
    secondaryContainer: T1Palette.redTint,
    onSecondaryContainer: T1Palette.ink1,
    surface: T1Palette.surface,
    onSurface: T1Palette.ink1,
    surfaceContainerHighest: T1Palette.border,
    onSurfaceVariant: T1Palette.ink2,
    outline: T1Palette.border2,
    outlineVariant: T1Palette.border,
    error: T1Palette.red,
    onError: T1Palette.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: T1Palette.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: T1Palette.bg,
      foregroundColor: T1Palette.ink1,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: T1Palette.border,
      thickness: 1,
      space: 1,
    ),
  );
}

CupertinoThemeData buildT1CupertinoTheme() {
  return const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: FpColors.blue,
    scaffoldBackgroundColor: FpColors.bg,
    barBackgroundColor: FpColors.surface,
  );
}
