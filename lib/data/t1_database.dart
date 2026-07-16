import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/court_task.dart';
import 'court_task_rules.dart';

/// SQLite 数据库，对照 Kotlin `data/T1Database.kt`。
/// 沿用 t1.db 的两张表（tasks + app_state）和明文 JSON 存储，DB_VERSION=1 为兼容基线。
class T1Database {
  T1Database._(this._db);

  final Database _db;
  static T1Database? _instance;
  static const String dbName = 't1.db';
  static const int dbVersion = 1;

  static Future<T1Database> instance() async {
    final cached = _instance;
    if (cached != null) return cached;
    final path = p.join(await getDatabasesPath(), dbName);
    final db = await openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, _) => _createSchema(db),
      onUpgrade: _onUpgrade,
    );
    return _instance ??= T1Database._(db);
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // top.linso.t1 从 DB_VERSION=1 作为新基线，后续升级逻辑从这里追加。
    if (oldV < newV) {
      // 当前仅 v1，无迁移分支。
    }
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY NOT NULL,
        json TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        category INTEGER NOT NULL DEFAULT 1,
        sms_date_millis INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_status ON tasks(status)');
    await db.execute('CREATE INDEX idx_tasks_category ON tasks(category)');
    await db.execute('CREATE INDEX idx_tasks_sms_date ON tasks(sms_date_millis)');
    await db.execute('CREATE INDEX idx_tasks_updated_at ON tasks(updated_at)');
    await db.execute('''
      CREATE TABLE app_state (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'string',
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<List<CourtTask>> loadTasks() async {
    final rows = await _db.query(
      'tasks',
      columns: ['json'],
      orderBy: 'sms_date_millis DESC, updated_at DESC',
    );
    final tasks = <CourtTask>[];
    for (final row in rows) {
      try {
        final task = CourtTask.fromJson(
            jsonDecode(row['json'] as String) as Map<String, dynamic>);
        if (task.id.isNotEmpty && task.url.isNotEmpty) tasks.add(task);
      } catch (_) {}
    }
    // 读取路径不再跑 normalizedMeta/isGenericReviewNotice（写入时已规整），
    // 否则每次读都对全表跑正则，初始加载会阻塞 UI isolate。
    return tasks.distinctById().sortedForDisplay();
  }

  /// 单条查询（按 id），用于增量更新时避免全表 decode。
  Future<CourtTask?> loadTaskById(String id) async {
    final rows = await _db.query('tasks',
        columns: ['json'], where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    try {
      return CourtTask.fromJson(
          jsonDecode(rows.first['json'] as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteTaskRow(String id) async {
    await _db.delete('tasks', where: 'id=?', whereArgs: [id]);
  }

  Future<void> replaceTasks(List<CourtTask> tasks) async {
    await _db.transaction((txn) async {
      await txn.delete('tasks');
      final list = tasks.distinctById().sortedForDisplay();
      for (final task in list) {
        await _upsertTask(txn, task);
      }
    });
  }

  /// 增量落盘：对比 [previous] 与 [next]，只写内容变化的行、删除被移除的行，
  /// 避免单条操作（已读/归档/删除）每次都「清空全表 + 全量重插」。
  Future<void> syncTasks(
      List<CourtTask> previous, List<CourtTask> next) async {
    final prevJson = <String, String>{
      for (final t in previous) t.id: jsonEncode(t.toJson()),
    };
    final nextIds = <String>{for (final t in next) t.id};
    await _db.transaction((txn) async {
      for (final task in next) {
        final encoded = jsonEncode(task.toJson());
        if (prevJson[task.id] == encoded) continue; // 内容未变，跳过写盘
        await txn.insert(
          'tasks',
          {
            'id': task.id,
            'json': encoded,
            'status': task.status.code,
            'category': task.category.code,
            'sms_date_millis': task.smsDateMillis,
            'updated_at': task.updatedAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final id in prevJson.keys) {
        if (!nextIds.contains(id)) {
          await txn.delete('tasks', where: 'id=?', whereArgs: [id]);
        }
      }
    });
  }

  Future<void> upsertTask(CourtTask task) => _upsertTask(_db, task);

  Future<void> _upsertTask(DatabaseExecutor db, CourtTask task) async {
    // 不再在每行插入时跑 normalizedMeta（调用方 CourtTaskStore.updateTasks 已统一规整）。
    await db.insert(
      'tasks',
      {
        'id': task.id,
        'json': jsonEncode(task.toJson()),
        'status': task.status.code,
        'category': task.category.code,
        'sms_date_millis': task.smsDateMillis,
        'updated_at': task.updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> getString(String key, String defaultValue) async {
    final rows = await _db.query('app_state',
        columns: ['value'], where: 'key=?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return defaultValue;
    return rows.first['value'] as String;
  }

  Future<void> putString(String key, String value) =>
      _putState(key, value, 'string');

  Future<bool> getBoolean(String key, bool defaultValue) async {
    final rows = await _db.query('app_state',
        columns: ['type', 'value'],
        where: 'key=?',
        whereArgs: [key],
        limit: 1);
    if (rows.isEmpty) return defaultValue;
    return rows.first['value'] == 'true';
  }

  Future<void> putBoolean(String key, bool value) =>
      _putState(key, value.toString(), 'boolean');

  Future<void> _putState(String key, String value, String type) async {
    await _db.insert(
      'app_state',
      {
        'key': key,
        'value': value,
        'type': type,
        'updated_at': nowMillis(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAppState() async {
    await _db.delete('app_state');
  }

  Future<void> clearAllData() async {
    await _db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('app_state');
    });
  }
}
