import 'package:flutter/foundation.dart';

import '../models/court_task.dart';
import '../platform/sms_reader.dart';
import 'court_parsers.dart';
import 'court_task_rules.dart';
import 'court_task_store.dart';

/// 顶层函数：在后台 isolate 里批量解析短信（避免 1200 条正则阻塞 UI）。
List<CourtTask> _parseSmsBatch(List<List<dynamic>> rows) => rows
    .map((r) => CourtParsers.parseCourtSms(
        r[0] as String, r[1] as String, r[2] as int))
    .whereType<CourtTask>()
    .toList();

/// 短信 Provider 导入和单条短信 upsert。
/// 逐一对照 Kotlin `data/SmsImporter.kt`。
class SmsImporter {
  SmsImporter(this._store, this._reader);

  final CourtTaskStore _store;
  final SmsReader _reader;

  Future<List<CourtTask>> importRecentCourtSms({int limit = 1200}) async {
    final rows = await _reader.loadRecentSms(limit);
    // 在后台 isolate 解析，主 isolate 不被正则阻塞。
    final parsed = rows.isEmpty
        ? <CourtTask>[]
        : await compute(
            _parseSmsBatch,
            rows
                .map((s) => <dynamic>[s.address, s.body, s.dateMillis])
                .toList(),
          );
    return _store.updateTasks((tasks) {
      final existing = {for (final t in tasks) t.id: t};
      for (final task in parsed) {
        final prev = existing[task.id];
        existing[task.id] = prev != null ? prev.mergeSms(task) : task.markQueued();
      }
      return existing.values.toList();
    });
  }

  Future<CourtTask?> upsertSms(String address, String body, int dateMillis) async {
    final parsed = CourtParsers.parseCourtSms(address, body, dateMillis);
    if (parsed == null) return null;
    await _store.updateTasks((tasks) {
      final index = tasks.indexWhere((t) => t.id == parsed.id);
      if (index >= 0) {
        tasks[index] = tasks[index].mergeSms(parsed).markQueued();
      } else {
        tasks.add(parsed.markQueued());
      }
      return tasks;
    });
    return parsed;
  }
}
