// 任务/文书相关枚举，逐一对照 Kotlin 版 `model/CourtModels.kt`。
// 每个枚举都带 code（持久化用的整型码）和 label（中文展示文案），
// 并提供 fromCode 做兜底解析，保证旧 JSON 缺字段时不崩。

enum CourtTaskStatus {
  pending(0, '待处理'),
  fetching(1, '解析中'),
  pdfFound(2, '已下载'),
  parsed(3, '已解析'),
  failed(4, '需人工处理'),
  archived(5, '已归档');

  const CourtTaskStatus(this.code, this.label);
  final int code;
  final String label;

  static CourtTaskStatus fromCode(int code) =>
      CourtTaskStatus.values.firstWhere((e) => e.code == code,
          orElse: () => CourtTaskStatus.pending);
}

enum CourtTaskCategory {
  review(0, '审核'),
  document(1, '文书'),
  other(2, '其他');

  const CourtTaskCategory(this.code, this.label);
  final int code;
  final String label;

  static CourtTaskCategory fromCode(int code) =>
      CourtTaskCategory.values.firstWhere((e) => e.code == code,
          orElse: () => CourtTaskCategory.document);
}

enum MonitorSourceType {
  sms(0, '短信'),
  enterpriseWechat(1, '企微'),
  dingTalk(2, '钉钉'),
  wechat(3, '微信');

  const MonitorSourceType(this.code, this.label);
  final int code;
  final String label;

  static MonitorSourceType fromCode(int code) =>
      MonitorSourceType.values.firstWhere((e) => e.code == code,
          orElse: () => MonitorSourceType.sms);
}

enum TaskSyncState {
  idle(0, '待同步'),
  queued(1, '等待处理'),
  resolving(2, '处理中'),
  resolved(3, '已完成'),
  failed(4, '处理失败');

  const TaskSyncState(this.code, this.label);
  final int code;
  final String label;

  static TaskSyncState fromCode(int code) =>
      TaskSyncState.values.firstWhere((e) => e.code == code,
          orElse: () => TaskSyncState.idle);
}

enum TaskRiskLevel {
  normal(0, '普通'),
  notice(1, '提醒'),
  important(2, '重点'),
  critical(3, '紧急');

  const TaskRiskLevel(this.code, this.label);
  final int code;
  final String label;

  static TaskRiskLevel fromCode(int code) =>
      TaskRiskLevel.values.firstWhere((e) => e.code == code,
          orElse: () => TaskRiskLevel.normal);
}

enum CourtDocumentType {
  summons(0, '传票'),
  judgment(1, '判决书'),
  ruling(2, '裁定书'),
  evidenceNotice(3, '举证通知'),
  acceptanceNotice(4, '受理通知'),
  paymentNotice(5, '缴费通知'),
  mediation(6, '调解'),
  other(99, '其他');

  const CourtDocumentType(this.code, this.label);
  final int code;
  final String label;

  static CourtDocumentType fromCode(int code) =>
      CourtDocumentType.values.firstWhere((e) => e.code == code,
          orElse: () => CourtDocumentType.other);
}

enum SummonsParseStatus {
  notAttempted(0, '未解析'),
  success(1, '已识别'),
  unrecognized(2, '未识别'),
  downloadFailed(3, '下载失败');

  const SummonsParseStatus(this.code, this.label);
  final int code;
  final String label;

  static SummonsParseStatus fromCode(int code) =>
      SummonsParseStatus.values.firstWhere((e) => e.code == code,
          orElse: () => SummonsParseStatus.notAttempted);
}
