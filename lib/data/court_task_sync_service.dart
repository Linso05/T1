import '../models/court_enums.dart';
import '../models/court_task.dart';
import '../utils/kotlin_ext.dart';
import 'court_delivery_client.dart';
import 'court_document_downloader.dart';
import 'court_parsers.dart';
import 'court_task_rules.dart';
import 'court_task_store.dart';
import 'sms_importer.dart';

/// 后台同步进度，对照 Kotlin `CourtSyncProgress`。
class CourtSyncProgress {
  const CourtSyncProgress({
    this.total = 0,
    this.completed = 0,
    this.running = 0,
    this.failed = 0,
  });

  final int total;
  final int completed;
  final int running;
  final int failed;

  int get visibleCurrent =>
      (completed + running) > total ? total : (completed + running);
  bool get active => total > 0 && completed < total;
}

typedef SyncProgressCallback = Future<void> Function(
    List<CourtTask> tasks, Set<String> busyTaskIds, CourtSyncProgress progress);

/// 后台解析队列、3 路并发、进度回调、法院文书解析编排。
/// 逐一对照 Kotlin `data/CourtTaskSyncService.kt`。
class CourtTaskSyncService {
  CourtTaskSyncService({
    required this.store,
    required this.smsImporter,
    required this.deliveryClient,
    required this.downloader,
  });

  final CourtTaskStore store;
  final SmsImporter smsImporter;
  final CourtDeliveryClient deliveryClient;
  final CourtDocumentDownloader downloader;

  static const int _backgroundSyncConcurrency = 3;

  Future<List<CourtTask>> importAndResolveRecentCourtSms(String lawyerName,
      {int limit = 1200}) async {
    await smsImporter.importRecentCourtSms(limit: limit);
    return resolvePendingTasks(lawyerName);
  }

  Future<List<CourtTask>> importAndResolveRecentCourtSmsIncremental(
    String lawyerName, {
    int limit = 1200,
    required SyncProgressCallback onProgress,
  }) async {
    var latest = await smsImporter.importRecentCourtSms(limit: limit);
    final pendingTasks = await _backgroundPendingTasks();
    final total = pendingTasks.length;
    await onProgress(latest, <String>{}, CourtSyncProgress(total: total));
    if (pendingTasks.isEmpty) return latest.sortedForDisplay();

    var completed = 0;
    var failed = 0;
    final runningIds = <String>{};

    Future<void> emitProgress() async {
      final current = await store.loadTasks();
      await onProgress(
        current,
        {...runningIds},
        CourtSyncProgress(
          total: total,
          completed: completed,
          running: runningIds.length,
          failed: failed,
        ),
      );
    }

    await _runWithConcurrency(pendingTasks, _backgroundSyncConcurrency,
        (task) async {
      runningIds.add(task.id);
      final resolving = task.copyWith(
        syncState: TaskSyncState.resolving,
        status: task.status == CourtTaskStatus.archived
            ? task.status
            : CourtTaskStatus.fetching,
        updatedAt: nowMillis(),
      );
      await store.mergeTaskResult(resolving);
      await emitProgress();

      CourtTask next;
      try {
        next = (await _resolveQueuedTask(resolving, lawyerName))
            .markResolvedIfDone();
      } catch (e) {
        next = resolving.withQueueFailure(_msg(e, '后台处理失败'));
      }
      if (next.status == CourtTaskStatus.failed ||
          next.syncState == TaskSyncState.failed) {
        failed++;
      }
      await store.mergeTaskResult(next);
      completed++;
      runningIds.remove(task.id);
      await emitProgress();
    });

    latest = await store.loadTasks();
    return latest.sortedForDisplay();
  }

  Future<List<CourtTask>> resolvePendingTasks(String lawyerName) async {
    final tasks = await store.loadTasks();
    for (final task in tasks) {
      CourtTask next;
      if (task.shouldAutoResolve()) {
        next = (await _resolveCourtDocuments(
                task.copyWith(syncState: TaskSyncState.resolving), lawyerName))
            .markResolvedIfDone();
      } else if (task.shouldAutoDownloadSummons()) {
        next = (await downloader.autoDownloadSummons(
                task.copyWith(syncState: TaskSyncState.resolving), lawyerName))
            .markResolvedIfDone();
      } else {
        next = task;
      }
      if (!identical(next, task)) await store.mergeTaskResult(next);
    }
    return (await store.loadTasks()).sortedForDisplay();
  }

  Future<CourtTask?> resolveTaskById(String taskId, String lawyerName,
      {bool force = false}) async {
    final current =
        (await store.loadTasks()).firstWhereOrNull((t) => t.id == taskId);
    if (current == null) return null;
    if (!force && current.documents.isNotEmpty) {
      return store.updateTaskById(taskId, (t) => t.markResolvedIfDone());
    }
    final resolving = current
        .withStatus(CourtTaskStatus.fetching)
        .copyWith(syncState: TaskSyncState.resolving);
    await store.mergeTaskResult(resolving);
    CourtTask next;
    try {
      next = (await _resolveCourtDocuments(resolving, lawyerName))
          .markResolvedIfDone();
    } catch (e) {
      next = resolving.withQueueFailure(_msg(e, '解析失败'));
    }
    return store.updateTaskById(taskId, (latest) {
      if (latest.updatedAt > resolving.updatedAt &&
          latest.documents.isNotEmpty &&
          !force) {
        return latest.markResolvedIfDone();
      }
      return next;
    });
  }

  Future<CourtTask?> resolveCourtLink(String link, String lawyerName) async {
    final params = CourtParsers.deliveryParams(link);
    if (params.qdbh.isBlank || params.sdbh.isBlank || params.sdsin.isBlank) {
      return null;
    }
    final existing = (await store.loadTasks())
        .firstWhereOrNull((t) => t.sdbh == params.sdbh && t.sdbh.isNotEmpty);
    if (existing != null && existing.documents.isNotEmpty) return existing;

    final parsed = existing?.copyWith(
          url: link,
          qdbh: params.qdbh,
          sdbh: params.sdbh,
          sdsin: params.sdsin,
          updatedAt: nowMillis(),
        ) ??
        CourtTask(
          id: stableTaskId('manual|${params.sdbh}'),
          court: '',
          caseNo: '',
          url: link,
          qdbh: params.qdbh,
          sdbh: params.sdbh,
          sdsin: params.sdsin,
          contact: '',
          summary: '手动解析法院文书链接',
          smsAddress: '',
          smsBody: link,
          smsDateMillis: nowMillis(),
        );
    await store.updateTask(parsed);
    return resolveTaskById(parsed.id, lawyerName, force: true);
  }

  Future<List<CourtTask>> _backgroundPendingTasks() async {
    final now = nowMillis();
    return (await store.loadTasks())
        .where((t) =>
            t.status != CourtTaskStatus.archived &&
            t.retryAt <= now &&
            (t.shouldAutoResolve() || t.shouldAutoDownloadSummons()))
        .toList();
  }

  Future<CourtTask> _resolveQueuedTask(CourtTask task, String lawyerName) async {
    if (task.shouldAutoResolve()) {
      return _resolveCourtDocuments(task, lawyerName);
    }
    if (task.shouldAutoDownloadSummons()) {
      return downloader.autoDownloadSummons(task, lawyerName);
    }
    return task;
  }

  Future<CourtTask> _resolveCourtDocuments(
      CourtTask task, String lawyerName) async {
    if (task.qdbh.isBlank || task.sdbh.isBlank || task.sdsin.isBlank) {
      return task.withStatus(CourtTaskStatus.failed, '短信链接缺少送达参数');
    }
    try {
      final documents = await deliveryClient.documentsFor(task);
      if (documents.isEmpty) {
        return task.withStatus(CourtTaskStatus.failed, '接口未返回文书');
      }
      final title = CourtParsers.titleFromDocuments(documents);
      final resolved = task.copyWith(
        court: task.court.ifBlank(() =>
            documents.firstWhereOrNull((d) => d.court.isNotEmpty)?.court ?? ''),
        clientName: CourtParsers.clientNameFromDocuments(documents, lawyerName),
        documentTitle: title,
        documents: documents,
        category: CourtTaskCategory.document,
        important: task.important ||
            CourtParsers.isImportantDocument(title, documents),
        riskLevel:
            CourtParsers.riskLevelFromDocuments(documents, task.riskLevel),
        status: CourtTaskStatus.pending,
        error: '',
        updatedAt: nowMillis(),
      );
      return downloader.autoDownloadSummons(resolved, lawyerName);
    } catch (e) {
      return task.withStatus(CourtTaskStatus.failed, _msg(e, '接口解析失败'));
    }
  }

  /// 并发执行：最多 n 个任务同时进行（替代 Kotlin Semaphore + awaitAll）。
  Future<void> _runWithConcurrency<T>(
      List<T> items, int n, Future<void> Function(T) fn) async {
    final iterator = items.iterator;
    final workers = <Future<void>>[];
    for (var i = 0; i < n; i++) {
      workers.add(Future(() async {
        while (iterator.moveNext()) {
          final item = iterator.current;
          await fn(item);
        }
      }));
    }
    await Future.wait(workers);
  }

  String _msg(Object e, String fallback) {
    final s = e.toString();
    return s.isEmpty ? fallback : s;
  }
}
