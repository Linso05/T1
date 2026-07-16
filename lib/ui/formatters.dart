import '../models/court_enums.dart';
import '../models/court_task.dart';
import '../data/court_parsers.dart';
import '../data/court_task_rules.dart';
import '../utils/kotlin_ext.dart';
import 'ui_enums.dart';

// ---------------- 时间（按 Asia/Shanghai +8 处理）----------------

DateTime _chinaWall(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
        .add(const Duration(hours: 8));
DateTime chinaDateOnly(int ms) {
  final d = _chinaWall(ms);
  return DateTime.utc(d.year, d.month, d.day);
}

DateTime chinaNowWall() => DateTime.now().toUtc().add(const Duration(hours: 8));
DateTime chinaToday() {
  final d = chinaNowWall();
  return DateTime.utc(d.year, d.month, d.day);
}

String _pad2(int n) => n.toString().padLeft(2, '0');
const List<String> _weekdayCn = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String absoluteChinaTimeLabel(int ms) {
  final d = _chinaWall(ms);
  return '${d.year}-${_pad2(d.month)}-${_pad2(d.day)} ${_pad2(d.hour)}:${_pad2(d.minute)}';
}

String agendaTimeLabel(int ms) {
  final d = _chinaWall(ms);
  return '${_pad2(d.hour)}:${_pad2(d.minute)}';
}

String timeLabel(int ms) {
  final day = chinaDateOnly(ms);
  final today = chinaToday();
  final diff = day.difference(today).inDays;
  final d = _chinaWall(ms);
  final hm = '${_pad2(d.hour)}:${_pad2(d.minute)}';
  if (diff == 0) return hm;
  if (diff == -1) return '昨天 $hm';
  return '${_pad2(d.month)}-${_pad2(d.day)} $hm';
}

String relativeDayLabel(int ms) {
  final diff = chinaDateOnly(ms).difference(chinaToday()).inDays;
  switch (diff) {
    case 0:
      return '今天';
    case -1:
      return '昨天';
    case 1:
      return '明天';
    default:
      final d = _chinaWall(ms);
      return '${d.month}/${d.day}';
  }
}

String agendaDateLabel(DateTime dateUtc) {
  final today = chinaToday();
  final diff = dateUtc.difference(today).inDays;
  final String prefix;
  if (diff == 0) {
    prefix = '今天';
  } else if (diff == 1) {
    prefix = '明天';
  } else if (diff == -1) {
    prefix = '昨天';
  } else {
    prefix = '${_pad2(dateUtc.month)}月${_pad2(dateUtc.day)}日';
  }
  return '$prefix · ${_weekdayCn[dateUtc.weekday - 1]}';
}

// ---------------- 送达展示 ----------------

extension CourtTaskStatusFmt on CourtTaskStatus {
  String shortLabel() {
    switch (this) {
      case CourtTaskStatus.pending:
        return '待办';
      case CourtTaskStatus.fetching:
        return '解析中';
      case CourtTaskStatus.pdfFound:
        return '已下载';
      case CourtTaskStatus.parsed:
        return '已解析';
      case CourtTaskStatus.failed:
        return '异常';
      case CourtTaskStatus.archived:
        return '归档';
    }
  }
}

extension CourtTaskFmt on CourtTask {
  bool hasSummonsInfo() =>
      summonsCaseNo.isNotEmpty ||
      summonsPerson.isNotEmpty ||
      summonsTimeText.isNotEmpty ||
      summonsPlace.isNotEmpty ||
      todoTimeMillis > 0 ||
      todoPlace.isNotEmpty;

  bool matchesFilter(TaskFilter filter) {
    switch (filter) {
      case TaskFilter.active:
        return status != CourtTaskStatus.archived &&
            status != CourtTaskStatus.failed;
      case TaskFilter.failed:
        return status == CourtTaskStatus.failed;
      case TaskFilter.archived:
        return status == CourtTaskStatus.archived;
    }
  }

  bool matchesAttention(AttentionFilter filter) {
    switch (filter) {
      case AttentionFilter.all:
        return true;
      case AttentionFilter.important:
        return important || riskLevel.code >= TaskRiskLevel.important.code;
      case AttentionFilter.unread:
        return unread;
      case AttentionFilter.undownloaded:
        return category == CourtTaskCategory.document &&
            documents.any((d) => d.localPath.isEmpty);
    }
  }

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final fields = <String>[
      caseNo, court, clientName, documentTitle, contact, summary,
      smsAddress, smsBody, todoTitle, todoPlace,
      summonsCaseNo, summonsPerson, summonsTimeText, summonsPlace,
      for (final d in documents) ...[d.name, d.court, d.createdAt],
    ];
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  String courtNameForFilter() {
    var name = court;
    if (name.isEmpty) {
      name = documents.firstWhereOrNull((d) => d.court.isNotEmpty)?.court ?? '';
    }
    if (name.isEmpty) {
      name = RegExp(r'【([^】]*法院)】').firstMatch(smsBody)?.group(1) ?? '';
    }
    return name;
  }

  String deliveryTitle() {
    if (category == CourtTaskCategory.document &&
        clientName.isNotEmpty &&
        caseNo.isNotEmpty) {
      return '$clientName $caseNo';
    }
    if (clientName.isNotEmpty) return clientName;
    if (category == CourtTaskCategory.document && caseNo.isNotEmpty) {
      return caseNo;
    }
    if (category == CourtTaskCategory.review) {
      return CourtParsers.parseReviewCaseTitle(smsBody).ifBlank(() => '审核消息');
    }
    if (category == CourtTaskCategory.other) return '其他消息';
    return '未识别送达';
  }

  String deliveryMetaLine() {
    final parts = <String>[];
    parts.add(court.ifBlank(() => category.label));
    if (category == CourtTaskCategory.document && caseNo.isNotEmpty) {
      parts.add(caseNo);
    }
    if (category == CourtTaskCategory.document && documents.isNotEmpty) {
      parts.add('${documents.length}份');
    }
    if (category != CourtTaskCategory.document && smsAddress.isNotEmpty) {
      parts.add(smsAddress);
    }
    if (status == CourtTaskStatus.archived ||
        status == CourtTaskStatus.failed) {
      parts.add(status.label);
    }
    return parts.toSet().join(' · ');
  }

  String compactLine() {
    if (contact.isNotEmpty) return contact;
    if (documentTitle.isNotEmpty) return documentTitle;
    if (summary.isNotEmpty) return summary;
    if (smsBody.isNotEmpty) {
      return smsBody.replaceAll(RegExp(r'\s+'), ' ').take(80);
    }
    return category.label;
  }

  String summonsSummaryLine() {
    final parts = <String>[];
    final time = summonsTimeText.ifBlank(
        () => todoTimeMillis > 0 ? absoluteChinaTimeLabel(todoTimeMillis) : '');
    final place = summonsPlace.ifBlank(() => todoPlace);
    if (time.isNotEmpty) parts.add(time);
    if (place.isNotEmpty) parts.add(place);
    final joined = parts.join(' · ').ifBlank(() => '传票信息待核对');
    return '应到：$joined';
  }

  String businessSummaryLine() {
    if (hasSummonsInfo()) return summonsSummaryLine();
    if (category == CourtTaskCategory.document && documentTitle.isNotEmpty) {
      return documentTitle;
    }
    if (category == CourtTaskCategory.document && documents.isNotEmpty) {
      return documents.first.name;
    }
    if (category == CourtTaskCategory.review) {
      return summary.ifBlank(() => '审核结果待查看');
    }
    return summary.ifBlank(() => compactLine());
  }

  String backgroundBusyLine() {
    if (shouldAutoResolve()) return '后台解析法院文书链接中';
    if (shouldAutoDownloadSummons()) return '后台下载传票并解析中';
    if (summonsParseAttemptedAt <= 0 &&
        documents.any((d) => d.isSummonsDocument)) {
      return '后台解析传票信息中';
    }
    return '处理中';
  }

  String statusPillText(bool backgroundBusy) {
    if (backgroundBusy) return '处理中';
    if (riskLevel == TaskRiskLevel.critical) return '紧急';
    if (riskLevel.code >= TaskRiskLevel.important.code) return '重点';
    if (unread) return '未读';
    return status.shortLabel();
  }

  String focusedCta() {
    if (status == CourtTaskStatus.failed) return '处理';
    if (documents.any((d) => d.localPath.isEmpty)) return '下载';
    if (documents.any((d) => d.localPath.isNotEmpty)) return '查看';
    if (status == CourtTaskStatus.archived) return '查看';
    return '详情';
  }

  // ---------------- 工作台日程 ----------------

  int agendaMillis(AgendaRange range) {
    if (range == AgendaRange.month &&
        isActionableMonthAgendaTask() &&
        todoTimeMillis > 0) {
      return todoTimeMillis;
    }
    return smsDateMillis;
  }

  bool isVisibleInAgendaRange(AgendaRange range) {
    switch (range) {
      case AgendaRange.day:
      case AgendaRange.week:
      case AgendaRange.day90:
      case AgendaRange.year:
      case AgendaRange.all:
        return true;
      case AgendaRange.month:
        return isActionableMonthAgendaTask();
      case AgendaRange.monthOther:
        return !isActionableMonthAgendaTask();
    }
  }

  bool isActionableMonthAgendaTask() {
    if (manualTodo ||
        todoTimeMillis > 0 ||
        todoTitle.isNotEmpty ||
        todoPlace.isNotEmpty) {
      return true;
    }
    if (documents.any((d) => _actionableMonthDocType(d.type))) return true;
    final text = StringBuffer()
      ..write(documentTitle)
      ..write(' ')
      ..write(summary)
      ..write(' ')
      ..write(smsBody);
    for (final d in documents) {
      text..write(' ')..write(d.name);
    }
    const keys = [
      '诉讼费', '诉讼费用', '缴费', '交纳', '开庭', '庭审', '在线庭审', '线上庭审',
      '互联网在线', '互联网庭审', '会议号', '传票', '判决', '裁决', '裁定', '调解', '调节',
    ];
    final s = text.toString();
    return keys.any((k) => s.contains(k));
  }

  String agendaTitle(AgendaRange range) {
    String fallback() =>
        summonsPerson.ifBlank(() => clientName.ifBlank(() => deliveryTitle()));
    if (range == AgendaRange.month && _isOnlineHearing()) {
      return todoTitle.ifBlank(() => '在线庭审：${fallback()}');
    }
    if (range == AgendaRange.month && hasSummonsInfo()) {
      return todoTitle.ifBlank(() => '开庭：${fallback()}');
    }
    if (range == AgendaRange.month &&
        documents.any((d) => d.type == CourtDocumentType.paymentNotice)) {
      return '诉讼费缴纳：${clientName.ifBlank(() => deliveryTitle())}';
    }
    if (range == AgendaRange.month &&
        documents.any((d) => d.type == CourtDocumentType.judgment)) {
      return '判决：${clientName.ifBlank(() => deliveryTitle())}';
    }
    if (range == AgendaRange.month &&
        documents.any((d) => d.type == CourtDocumentType.ruling)) {
      return '裁定：${clientName.ifBlank(() => deliveryTitle())}';
    }
    if (range == AgendaRange.month &&
        documents.any((d) => d.type == CourtDocumentType.mediation)) {
      return '调解：${clientName.ifBlank(() => deliveryTitle())}';
    }
    return todoTitle.ifBlank(() => deliveryTitle());
  }

  String agendaDetail(AgendaRange range) {
    if (range == AgendaRange.month && hasSummonsInfo()) {
      final time = (todoTimeMillis > 0
              ? absoluteChinaTimeLabel(todoTimeMillis)
              : '')
          .ifBlank(() => summonsTimeText);
      final place = todoPlace.ifBlank(() => summonsPlace);
      final parts = <String>[];
      if (time.isNotEmpty) parts.add(time);
      if (place.isNotEmpty) parts.add(place);
      return parts.join(' · ').ifBlank(() => businessSummaryLine());
    }
    return todoPlace.isNotEmpty ? todoPlace : compactLine();
  }

  bool _isOnlineHearing() {
    final text = StringBuffer()
      ..write(todoTitle)
      ..write(todoPlace)
      ..write(summonsPlace)
      ..write(summonsTimeText)
      ..write(documentTitle)
      ..write(summary)
      ..write(smsBody);
    for (final d in documents) {
      text.write(d.name);
    }
    final s = text.toString();
    return ['在线庭审', '线上庭审', '互联网在线', '互联网庭审', '会议号']
        .any((k) => s.contains(k));
  }
}

bool _actionableMonthDocType(CourtDocumentType type) {
  switch (type) {
    case CourtDocumentType.summons:
    case CourtDocumentType.judgment:
    case CourtDocumentType.ruling:
    case CourtDocumentType.paymentNotice:
    case CourtDocumentType.mediation:
      return true;
    case CourtDocumentType.evidenceNotice:
    case CourtDocumentType.acceptanceNotice:
    case CourtDocumentType.other:
      return false;
  }
}

extension CourtTaskListFmt on List<CourtTask> {
  CourtStats stats() => CourtStats(
        active: where((t) =>
            t.status != CourtTaskStatus.archived &&
            t.status != CourtTaskStatus.failed).length,
        failed: where((t) => t.status == CourtTaskStatus.failed).length,
        archived: where((t) => t.status == CourtTaskStatus.archived).length,
      );

  List<String> availableCourts() {
    final set = <String>{};
    for (final t in this) {
      final name = t.courtNameForFilter();
      if (name.isNotEmpty) set.add(name);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<CourtTask> agendaTasks(AgendaRange range) {
    final today = chinaToday();
    final filtered = where((task) =>
        task.status != CourtTaskStatus.archived &&
        task.status != CourtTaskStatus.failed &&
        task.isVisibleInAgendaRange(range) &&
        _isInRange(chinaDateOnly(task.agendaMillis(range)), today, range)).toList();
    filtered.sort((a, b) {
      int c = chinaDateOnly(a.agendaMillis(range))
          .compareTo(chinaDateOnly(b.agendaMillis(range)));
      if (c != 0) return c;
      c = b.priorityRank().compareTo(a.priorityRank());
      if (c != 0) return c;
      c = (b.unread ? 1 : 0).compareTo(a.unread ? 1 : 0);
      if (c != 0) return c;
      return b.agendaMillis(range).compareTo(a.agendaMillis(range));
    });
    return filtered;
  }
}

/// 判断某日期（中国时区 date-only）是否落在当前日程范围内（今日/本周/本月）。
bool isInAgendaRange(DateTime date, AgendaRange range) =>
    _isInRange(date, chinaToday(), range);

bool _isInRange(DateTime date, DateTime today, AgendaRange range) {
  switch (range) {
    case AgendaRange.day:
      return date == today;
    case AgendaRange.week:
      final start = today.subtract(Duration(days: today.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return !date.isBefore(start) && !date.isAfter(end);
    case AgendaRange.month:
    case AgendaRange.monthOther:
      return date.year == today.year && date.month == today.month;
    case AgendaRange.day90:
      final start = today.subtract(const Duration(days: 90));
      final end = today.add(const Duration(days: 90));
      return !date.isBefore(start) && !date.isAfter(end);
    case AgendaRange.year:
      return date.year == today.year;
    case AgendaRange.all:
      return true;
  }
}

String compactCourtName(String name) =>
    name.replaceAll('上海市', '').replaceAll('人民法院', '法院').ifBlank(() => name);

/// 总筛选汇总文案（端口 L2 `filterSummary`）：例如「待办 42 · 上海金融法院 · 当前 12」。
String filterSummary(
  TaskFilter filter,
  AttentionFilter attentionFilter,
  List<CourtTask> statusTasks,
  List<CourtTask> allTasks, {
  DeliveryPageCategory? pageCategory,
  String courtFilter = '',
}) {
  final parts = <String>[];
  parts.add('${filter.label} ${allTasks.where((t) => t.matchesFilter(filter)).length}');
  if (pageCategory != null) parts.add(pageCategory.label);
  if (courtFilter.isNotEmpty) parts.add(compactCourtName(courtFilter));
  if (attentionFilter != AttentionFilter.all) parts.add(attentionFilter.label);
  final current = statusTasks.where((t) =>
      t.matchesAttention(attentionFilter) &&
      (pageCategory?.category == null || t.category == pageCategory!.category) &&
      (courtFilter.isEmpty || t.courtNameForFilter() == courtFilter)).length;
  parts.add('当前 $current');
  return parts.join(' · ');
}

bool hasDeliveryParams(String url) {
  final p = CourtParsers.deliveryParams(url);
  return p.qdbh.isNotEmpty && p.sdbh.isNotEmpty && p.sdsin.isNotEmpty;
}

/// 生成日历网格日期（补齐到整周），对照 Kotlin calendarDatesForRange。
List<DateTime> calendarDatesForRange(AgendaRange range) {
  final today = chinaToday();
  final DateTime start;
  final DateTime end;
  if (range == AgendaRange.day || range == AgendaRange.week) {
    start = today.subtract(Duration(days: today.weekday - 1));
    end = start.add(const Duration(days: 6));
  } else {
    final first = DateTime.utc(today.year, today.month, 1);
    start = first.subtract(Duration(days: first.weekday - 1));
    final last = DateTime.utc(today.year, today.month + 1, 0);
    end = last.add(Duration(days: 7 - last.weekday));
  }
  final result = <DateTime>[];
  var d = start;
  while (!d.isAfter(end)) {
    result.add(d);
    d = d.add(const Duration(days: 1));
  }
  return result;
}

String monthTitleLabel() {
  final t = chinaNowWall();
  return '${t.year}年${t.month}月';
}

bool isChinaToday(DateTime dateUtc) {
  final today = chinaToday();
  return dateUtc == today;
}

// ---------------- 任务标签（对照 FocusedTaskTag / focusedTags）----------------

enum FocusedTagStyle { normal, solid, danger, amber, muted }

class TaskTag {
  const TaskTag(this.label, this.style);
  final String label;
  final FocusedTagStyle style;
}

extension CourtTaskTagsFmt on CourtTask {
  List<TaskTag> focusedTags() {
    final tags = <TaskTag>[];
    if (status == CourtTaskStatus.failed) {
      tags.add(const TaskTag('异常', FocusedTagStyle.amber));
    } else if (status == CourtTaskStatus.archived) {
      tags.add(const TaskTag('已归档', FocusedTagStyle.muted));
    } else if (riskLevel == TaskRiskLevel.critical) {
      tags.add(const TaskTag('紧急', FocusedTagStyle.danger));
    } else if (riskLevel.code >= TaskRiskLevel.important.code) {
      tags.add(const TaskTag('重点', FocusedTagStyle.danger));
    }
    final undownloaded = documents.where((d) => d.localPath.isEmpty).length;
    if (undownloaded > 0) {
      tags.add(TaskTag(
          undownloaded == documents.length ? '未下载' : '未下 $undownloaded',
          FocusedTagStyle.danger));
    } else if (documents.any((d) => d.localPath.isNotEmpty)) {
      tags.add(const TaskTag('已下载', FocusedTagStyle.solid));
    } else if (status == CourtTaskStatus.pending) {
      tags.add(const TaskTag('待处理', FocusedTagStyle.normal));
    }
    return tags;
  }
}
