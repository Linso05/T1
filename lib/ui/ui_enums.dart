import '../models/court_enums.dart';

/// 送达主筛选（待办/异常/归档），对照 Kotlin `TaskFilter`。
enum TaskFilter {
  active('待办'),
  failed('异常'),
  archived('归档');

  const TaskFilter(this.label);
  final String label;
}

/// 送达二级分类，对照 Kotlin `DeliveryPageCategory`。
enum DeliveryPageCategory {
  all('全部', null),
  review('审核', CourtTaskCategory.review),
  document('文书', CourtTaskCategory.document),
  other('其他', CourtTaskCategory.other);

  const DeliveryPageCategory(this.label, this.category);
  final String label;
  final CourtTaskCategory? category;
}

/// 关注筛选，对照 Kotlin `AttentionFilter`。
enum AttentionFilter {
  all('全部'),
  important('重点'),
  unread('未读'),
  undownloaded('未下载');

  const AttentionFilter(this.label);
  final String label;
}

/// 底部四区导航，对照 Kotlin `HomeSection`。
enum HomeSection {
  workbench('工作台'),
  delivery('送达'),
  askAi('AI'),
  tools('工具');

  const HomeSection(this.label);
  final String label;
}

/// 工作台日程范围，对照 Kotlin `AgendaRange`。
enum AgendaRange {
  day('日', '今日日程', '今日待办'),
  week('周', '本周日程', '本周待办'),
  month('月', '本月日程', '本月待办'),
  monthOther('月(其他)', '本月其他', '本月其他消息'),
  day90('90天', '近90天日程', '近90天待办'),
  year('年', '今年日程', '今年待办'),
  all('全部', '全部日程', '全部待办');

  const AgendaRange(this.label, this.summaryTitle, this.listTitle);
  final String label;
  final String summaryTitle;
  final String listTitle;
}

/// 工作台日程项打开方式，对照 Kotlin `WorkbenchOpenMode`。
enum WorkbenchOpenMode {
  detail('详情页', '点开任务直接进详情'),
  deliveryExpanded('送达展开', '跳到送达中心并展开该任务');

  const WorkbenchOpenMode(this.label, this.desc);
  final String label;
  final String desc;

  static WorkbenchOpenMode fromCode(String code) =>
      WorkbenchOpenMode.values.firstWhere(
        (e) => e.name == code,
        orElse: () => WorkbenchOpenMode.detail,
      );
}

/// 任务统计，对照 Kotlin `CourtStats`。
class CourtStats {
  const CourtStats({this.active = 0, this.failed = 0, this.archived = 0});
  final int active;
  final int failed;
  final int archived;
}
