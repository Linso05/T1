import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 一组对照 Kotlin 标准库语义的 String 扩展，让从 Kotlin 移植的解析/规则代码
/// 能近乎逐行对照，避免手工改写引入差异。
extension KotlinString on String {
  bool get isBlank => trim().isEmpty;
  bool get isNotBlank => trim().isNotEmpty;

  /// Kotlin String.take(n)：取前 n 个字符，不足返回全部。
  String take(int n) => length <= n ? this : substring(0, n);

  /// Kotlin ifBlank { ... }
  String ifBlank(String Function() fallback) => isBlank ? fallback() : this;

  /// Kotlin substringAfter(delimiter, missingDelimiterValue=this)
  String substringAfter(String delimiter, [String? missing]) {
    final i = indexOf(delimiter);
    if (i < 0) return missing ?? this;
    return substring(i + delimiter.length);
  }

  String substringBefore(String delimiter, [String? missing]) {
    final i = indexOf(delimiter);
    if (i < 0) return missing ?? this;
    return substring(0, i);
  }

  String substringAfterLast(String delimiter, [String? missing]) {
    final i = lastIndexOf(delimiter);
    if (i < 0) return missing ?? this;
    return substring(i + delimiter.length);
  }

  /// Kotlin removeSuffix(suffix, ignoreCase)
  String removeSuffix(String suffix, {bool ignoreCase = false}) {
    final endsIt = ignoreCase
        ? toLowerCase().endsWith(suffix.toLowerCase())
        : endsWith(suffix);
    return endsIt ? substring(0, length - suffix.length) : this;
  }

  /// Kotlin trim(vararg chars)：去掉首尾在 chars 集合内的字符。
  String trimChars(List<String> chars) {
    final set = chars.toSet();
    var start = 0;
    var end = length;
    while (start < end && set.contains(this[start])) {
      start++;
    }
    while (end > start && set.contains(this[end - 1])) {
      end--;
    }
    return substring(start, end);
  }

  /// 仿 java.net.URLDecoder.decode(s, "UTF-8")：+ 转空格 + 百分号解码。
  String urlDecode() {
    try {
      return Uri.decodeQueryComponent(this);
    } catch (_) {
      return this;
    }
  }

  /// 仿 android.net.Uri.decode：百分号解码（不把 + 转空格）。
  String uriDecode() {
    try {
      return Uri.decodeComponent(this);
    } catch (_) {
      return this;
    }
  }
}

extension KotlinIterable<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }

  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

/// 把 UTF-16BE 的十六进制串解码为字符串，失败返回 null（对照 hexUtf16Be）。
String? hexUtf16Be(String hex) {
  try {
    final byteCount = hex.length ~/ 2;
    if (byteCount < 2) return null;
    final bytes = List<int>.generate(
        byteCount, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
    }
    if (codeUnits.isEmpty) return null;
    return String.fromCharCodes(codeUnits);
  } catch (_) {
    return null;
  }
}

/// SHA-256 十六进制（小写）。
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// 任意字符串的稳定 id：SHA-256 前 24 位十六进制（对照 stableId）。
String stableId(String value) =>
    sha256Hex(utf8.encode(value)).substring(0, 24);
