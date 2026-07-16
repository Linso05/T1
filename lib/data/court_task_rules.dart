import 'dart:math' as math;

import '../models/court_enums.dart';
import '../models/court_task.dart';
import '../models/court_document.dart';
import '../utils/kotlin_ext.dart';
import 'court_parsers.dart';

/// 排序、去重、审核过滤、队列判断、传票判断等共享业务规则。
/// 逐一对照 Kotlin `data/CourtTaskRules.kt`。
extension CourtTaskRules on CourtTask {
  int priorityRank() {
    if (riskLevel == TaskRiskLevel.critical) return 4;
    if (riskLevel.code >= TaskRiskLevel.important.code) return 3;
    if (important) return 2;
    if (unread) return 1;
    return 0;
  }

  bool shouldAutoResolve() =>
      status != CourtTaskStatus.archived &&
      documents.isEmpty &&
      qdbh.isNotBlank &&
      sdbh.isNotBlank &&
      sdsin.isNotBlank;

  bool shouldAutoDownloadSummons() =>
      status != CourtTaskStatus.archived &&
      status != CourtTaskStatus.failed &&
      summonsParseAttemptedAt <= 0 &&
      documents.any((d) => d.isSummonsDocument);

  CourtTask mergeSms(CourtTask next) => copyWith(
        court: next.court.ifBlank(() => court),
        caseNo: next.caseNo.ifBlank(() => caseNo),
        url: next.url.ifBlank(() => url),
        qdbh: next.qdbh.ifBlank(() => qdbh),
        sdbh: next.sdbh.ifBlank(() => sdbh),
        sdsin: next.sdsin.ifBlank(() => sdsin),
        contact: next.contact.ifBlank(() => contact),
        summary: next.summary.ifBlank(() => summary),
        clientName: next.clientName.ifBlank(() => clientName),
        smsAddress: next.smsAddress.ifBlank(() => smsAddress),
        smsBody: next.smsBody.ifBlank(() => smsBody),
        smsDateMillis: math.max(smsDateMillis, next.smsDateMillis),
        category: next.category,
        important: important || next.important,
        updatedAt: nowMillis(),
      );

  CourtTask normalizedMeta() {
    final inferredCategory = CourtParsers.inferTaskCategory(smsBody, documents);
    final inferredImportant =
        important || CourtParsers.isImportantDocument(documentTitle, documents);
    final inferredRisk =
        CourtParsers.riskLevelFromDocuments(documents, riskLevel);
    final CourtTaskCategory nextCategory;
    if (documents.isNotEmpty) {
      nextCategory = CourtTaskCategory.document;
    } else if (category == CourtTaskCategory.document &&
        inferredCategory != CourtTaskCategory.document) {
      nextCategory = inferredCategory;
    } else {
      nextCategory = category;
    }
    final reviewTitle =
        (nextCategory == CourtTaskCategory.review && clientName.isBlank)
            ? CourtParsers.parseReviewCaseTitle(smsBody)
            : '';
    final TaskSyncState nextSync;
    if (syncState == TaskSyncState.resolving) {
      nextSync = TaskSyncState.queued;
    } else if (syncState == TaskSyncState.idle &&
        (shouldAutoResolve() || shouldAutoDownloadSummons())) {
      nextSync = TaskSyncState.queued;
    } else {
      nextSync = syncState;
    }
    return copyWith(
      category: nextCategory,
      clientName: reviewTitle.isNotBlank ? reviewTitle : clientName,
      important: inferredImportant,
      riskLevel: inferredRisk,
      syncState: nextSync,
    );
  }

  CourtTask markQueued() =>
      (shouldAutoResolve() || shouldAutoDownloadSummons())
          ? copyWith(
              syncState: TaskSyncState.queued,
              retryAt: 0,
              updatedAt: nowMillis())
          : this;

  bool isGenericReviewNotice() =>
      category == CourtTaskCategory.review &&
      (CourtParsers.isGenericReviewNotice(smsBody) ||
          CourtParsers.isOrphanReviewResult(smsBody, summary, clientName));

  CourtTask markResolvedIfDone() {
    if (status == CourtTaskStatus.failed) {
      return withQueueFailure(error.ifBlank(() => '处理失败'));
    } else if (summonsParseAttemptedAt > 0 &&
        documents.any((d) => d.isSummonsDocument) &&
        !shouldAutoResolve()) {
      return copyWith(
        status: status == CourtTaskStatus.fetching
            ? CourtTaskStatus.pdfFound
            : status,
        syncState: TaskSyncState.resolved,
        retryAt: 0,
        retryCount: 0,
        updatedAt: nowMillis(),
      );
    } else if (shouldAutoResolve() || shouldAutoDownloadSummons()) {
      return copyWith(
        status: status == CourtTaskStatus.fetching
            ? CourtTaskStatus.pending
            : status,
        syncState: TaskSyncState.queued,
        updatedAt: nowMillis(),
      );
    } else {
      return copyWith(
        syncState: TaskSyncState.resolved,
        retryAt: 0,
        retryCount: 0,
        updatedAt: nowMillis(),
      );
    }
  }

  CourtTask withQueueFailure(String message) {
    final nextRetryCount = math.min(retryCount + 1, 6);
    final delayMillis =
        math.min(30000 * (1 << (nextRetryCount - 1)), 30 * 60 * 1000);
    return copyWith(
      status: CourtTaskStatus.failed,
      syncState: TaskSyncState.failed,
      retryAt: nowMillis() + delayMillis,
      retryCount: nextRetryCount,
      error: message,
      updatedAt: nowMillis(),
    );
  }

  String deliveryName() => clientName
      .ifBlank(() => caseNo.ifBlank(() => court.ifBlank(() => '法院文书')));

  bool needsSummonsPersonRepair() =>
      summonsPerson.contains('代理') ||
      summonsPerson.contains('及其') ||
      todoTitle.contains('代理') ||
      todoTitle.contains('及其');

  /// 合并后台解析结果（对照 CourtTaskStore.mergeTaskResultFields）。
  CourtTask mergeTaskResultFields(CourtTask next) {
    if (next.updatedAt <= updatedAt) return this;
    if (status == CourtTaskStatus.archived &&
        next.status != CourtTaskStatus.archived) {
      return next.copyWith(status: CourtTaskStatus.archived, unread: false);
    }
    return next;
  }
}

extension CourtTaskListRules on List<CourtTask> {
  List<CourtTask> sortedForDisplay() {
    final copy = [...this];
    copy.sort((a, b) {
      int c = (a.status == CourtTaskStatus.archived ? 1 : 0)
          .compareTo(b.status == CourtTaskStatus.archived ? 1 : 0);
      if (c != 0) return c;
      c = b.priorityRank().compareTo(a.priorityRank());
      if (c != 0) return c;
      c = (b.unread ? 1 : 0).compareTo(a.unread ? 1 : 0);
      if (c != 0) return c;
      c = b.smsDateMillis.compareTo(a.smsDateMillis);
      if (c != 0) return c;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return copy;
  }

  /// 按 id 去重，保留首次出现。
  List<CourtTask> distinctById() {
    final seen = <String>{};
    final result = <CourtTask>[];
    for (final t in this) {
      if (seen.add(t.id)) result.add(t);
    }
    return result;
  }
}

extension CourtDocumentRules on CourtDocument {
  String safeFileName() {
    final base = name
        .ifBlank(() => id)
        .substringAfterLast('/')
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]+'), '_')
        .trim()
        .ifBlank(() => id);
    return base.toLowerCase().endsWith('.pdf') ? base : '$base.pdf';
  }
}

/// 稳定任务 id：SHA-256 前 24 位（对照 stableTaskId）。
String stableTaskId(String value) => stableId(value);
