import '../../models/court_enums.dart';
import '../../models/court_task.dart';
import '../formatters.dart';
import 'fp_calendar.dart';
import 'fp_widgets.dart';

/// CourtTask → FocusPoint 视图映射（chip 样式、类型标签、卡片边框、日历圆点）。
/// 仅做展示映射，不含业务逻辑。

FpChipStyle fpChipStyle(FocusedTagStyle s) => switch (s) {
      FocusedTagStyle.solid => FpChipStyle.solid,
      FocusedTagStyle.danger => FpChipStyle.red,
      FocusedTagStyle.amber => FpChipStyle.amber,
      FocusedTagStyle.muted => FpChipStyle.normal,
      FocusedTagStyle.normal => FpChipStyle.normal,
    };

extension FpTaskView on CourtTask {
  /// 小标签类型（传票/举证通知/裁定书/异常…）。
  String fpTypeLabel() {
    if (status == CourtTaskStatus.failed) return '异常';
    if (documents.isNotEmpty) return documents.first.type.label;
    if (hasSummonsInfo()) return '传票';
    return category.label;
  }

  /// 任务卡底部 chips（取前 3 个 focusedTags）。
  List<FpChip> fpChips({int max = 3}) =>
      focusedTags().take(max).map((t) => FpChip(t.label, style: fpChipStyle(t.style))).toList();

  /// 可展开卡边框态。
  FpCardBorder fpBorder() {
    if (status == CourtTaskStatus.failed) return FpCardBorder.warn;
    if (riskLevel == TaskRiskLevel.critical) return FpCardBorder.urgent;
    return FpCardBorder.normal;
  }

  /// 日历/时间轴圆点颜色。
  FpDot fpDot() {
    if (riskLevel == TaskRiskLevel.critical || status == CourtTaskStatus.failed) {
      return FpDot.red;
    }
    if (unread) return FpDot.blue;
    return FpDot.amber;
  }

  /// 卡片主标题（法院名，回退 deliveryTitle）。
  String fpCourtTitle() {
    final c = courtNameForFilter();
    return c.isNotEmpty ? c : deliveryTitle();
  }
}
