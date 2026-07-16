import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/court_enums.dart';
import '../models/court_task.dart';
import '../utils/kotlin_ext.dart';
import 'court_task_rules.dart';
import 't1_database.dart';

/// 串行互斥锁：替代 Kotlin 的 synchronized(storageLock)，
/// 保证 load→transform→replace 的读改写不交错。
class _AsyncLock {
  Future<void> _last = Future.value();

  Future<T> synchronized<T>(Future<T> Function() fn) {
    final completer = Completer<void>();
    final prev = _last;
    _last = completer.future;
    return prev.then((_) async {
      try {
        return await fn();
      } finally {
        completer.complete();
      }
    });
  }
}

/// 任务数据库读写、归档、删除和 PDF 文件清理。
/// 逐一对照 Kotlin `data/CourtTaskStore.kt`。
class CourtTaskStore {
  CourtTaskStore(this._db, this._pdfDir);

  final T1Database _db;
  final Directory _pdfDir;
  static final _AsyncLock _lock = _AsyncLock();
  static final Set<String> _deletedTaskIds = {};

  /// 内存缓存（与 DB 同步的权威列表）。读路径直接返回它，避免每次全表 decode；
  /// 写路径增量更新它。单例 store，全 app 共用一份。
  List<CourtTask>? _cache;

  Future<List<CourtTask>> _ensureCache() async =>
      _cache ??= await _db.loadTasks();

  static Future<CourtTaskStore> create() async {
    final db = await T1Database.instance();
    final docs = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(p.join(docs.path, 'pdf'));
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return CourtTaskStore(db, pdfDir);
  }

  Directory get pdfDir => _pdfDir;

  /// 清空全部任务、设置与本地 PDF（重置软件数据）。
  Future<void> clearAll() async {
    await _db.clearAllData();
    _cache = <CourtTask>[];
    _deletedTaskIds.clear();
    try {
      if (await _pdfDir.exists()) {
        await for (final f in _pdfDir.list()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<List<CourtTask>> loadTasks() => _lock.synchronized(_ensureCache);

  /// 全量导入兼容路径；增量写入应走 updateTasks/mergeTaskResult。
  Future<void> saveTasks(List<CourtTask> tasks) =>
      _lock.synchronized(() async {
        final list = tasks.distinctById().sortedForDisplay();
        await _db.replaceTasks(list);
        _cache = list;
      });

  /// 单条结果合并：只规整+写这一行，并就地更新内存缓存（不再全表 decode/重写）。
  Future<List<CourtTask>> mergeTaskResult(CourtTask task) {
    return _lock.synchronized(() async {
      final cache = await _ensureCache();
      if (_deletedTaskIds.contains(task.id)) return cache;
      final existing = cache.firstWhereOrNull((t) => t.id == task.id);
      final merged =
          existing != null ? existing.mergeTaskResultFields(task) : task;
      final normalized = merged.normalizedMeta();
      if (normalized.isGenericReviewNotice()) {
        await _db.deleteTaskRow(task.id);
        _cache = cache.where((t) => t.id != task.id).toList();
      } else {
        await _db.upsertTask(normalized);
        _cache = (cache.where((t) => t.id != task.id).toList()
              ..add(normalized))
            .sortedForDisplay();
      }
      return _cache!;
    });
  }

  Future<List<CourtTask>> updateTasks(
      List<CourtTask> Function(List<CourtTask>) transform) {
    return _lock.synchronized(() async {
      final previous = await _ensureCache();
      final normalized = transform([...previous])
          .map((t) => t.normalizedMeta())
          .where((t) => !t.isGenericReviewNotice())
          .toList()
          .distinctById()
          .sortedForDisplay();
      // 只写变更行、删除被移除行，避免每次单条操作全表重写。
      await _db.syncTasks(previous, normalized);
      _cache = normalized;
      return normalized;
    });
  }

  Future<List<CourtTask>> updateTask(CourtTask task) {
    return updateTasks((tasks) {
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        tasks[index] = task;
      } else {
        tasks.add(task);
      }
      return tasks;
    });
  }

  Future<List<CourtTask>> deleteTask(String taskId) {
    return updateTasks((tasks) {
      final index = tasks.indexWhere((t) => t.id == taskId);
      if (index < 0) return tasks;
      final task = tasks[index];
      _deletedTaskIds.add(taskId);
      final paths = [
        ...task.documents.map((d) => d.localPath),
        task.pdfPath,
      ].where((path) => path.isNotEmpty);
      for (final path in paths) {
        try {
          final file = File(path);
          if (file.existsSync() &&
              p.canonicalize(file.parent.path) ==
                  p.canonicalize(_pdfDir.path)) {
            file.deleteSync();
          }
        } catch (_) {}
      }
      return tasks.where((t) => t.id != taskId).toList();
    });
  }

  Future<CourtTask?> updateTaskById(
      String taskId, CourtTask Function(CourtTask) transform) async {
    CourtTask? updated;
    await updateTasks((tasks) {
      final index = tasks.indexWhere((t) => t.id == taskId);
      if (index >= 0) {
        final next = transform(tasks[index]);
        tasks[index] = next;
        updated = next;
      }
      return tasks;
    });
    return updated;
  }

  Future<List<CourtTask>> archiveTasks(Iterable<String> taskIds) async {
    final idSet = taskIds.toSet();
    if (idSet.isEmpty) return loadTasks();
    return updateTasks((tasks) => tasks.map((task) {
          if (idSet.contains(task.id) &&
              task.status != CourtTaskStatus.archived) {
            return task.copyWith(
                status: CourtTaskStatus.archived,
                unread: false,
                updatedAt: nowMillis());
          }
          return task;
        }).toList());
  }

  Future<List<CourtTask>> archiveCategory(CourtTaskCategory category) {
    return updateTasks((tasks) => tasks.map((task) {
          if (task.category == category &&
              task.status != CourtTaskStatus.archived) {
            return task.copyWith(
                status: CourtTaskStatus.archived,
                unread: false,
                updatedAt: nowMillis());
          }
          return task;
        }).toList());
  }
}
