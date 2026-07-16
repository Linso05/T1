import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/app_state_store.dart';
import '../data/court_task_sync_service.dart';
import '../models/court_enums.dart';
import '../models/court_task.dart';
import '../platform/sms_reader.dart';
import '../ui/ui_enums.dart';
import '../utils/kotlin_ext.dart';
import 'app_services.dart';

/// 送达中心 + 工作台共享的任务状态。
class CourtTasksState {
  const CourtTasksState({
    this.tasks = const [],
    this.loading = true,
    this.backgroundSyncing = false,
    this.busyTaskIds = const {},
    this.progress = const CourtSyncProgress(),
    this.filter = TaskFilter.active,
    this.category = DeliveryPageCategory.all,
    this.attention = AttentionFilter.all,
    this.query = '',
    this.courtFilter = '',
    this.syncError = '',
  });

  final List<CourtTask> tasks;
  final bool loading;
  final bool backgroundSyncing;
  final Set<String> busyTaskIds;
  final CourtSyncProgress progress;
  final TaskFilter filter;
  final DeliveryPageCategory category;
  final AttentionFilter attention;
  final String query;
  final String courtFilter;
  final String syncError;

  CourtTasksState copyWith({
    List<CourtTask>? tasks,
    bool? loading,
    bool? backgroundSyncing,
    Set<String>? busyTaskIds,
    CourtSyncProgress? progress,
    TaskFilter? filter,
    DeliveryPageCategory? category,
    AttentionFilter? attention,
    String? query,
    String? courtFilter,
    String? syncError,
  }) {
    return CourtTasksState(
      tasks: tasks ?? this.tasks,
      loading: loading ?? this.loading,
      backgroundSyncing: backgroundSyncing ?? this.backgroundSyncing,
      busyTaskIds: busyTaskIds ?? this.busyTaskIds,
      progress: progress ?? this.progress,
      filter: filter ?? this.filter,
      category: category ?? this.category,
      attention: attention ?? this.attention,
      query: query ?? this.query,
      courtFilter: courtFilter ?? this.courtFilter,
      syncError: syncError ?? this.syncError,
    );
  }
}

class CourtTasksController extends Notifier<CourtTasksState> {
  late AppServices _s;
  DateTime _lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  CourtTasksState build() {
    _s = ref.read(appServicesProvider);
    final sub = _s.smsReader.newSmsStream().listen(_onNewSms);
    ref.onDispose(sub.cancel);
    Future.microtask(load);
    return const CourtTasksState();
  }

  Future<String> _lawyer() => _s.appState.getString(AppStateKeys.lawyerName);

  Future<bool> _ensureSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) return true;
    return (await Permission.sms.request()).isGranted;
  }

  CourtTask? taskById(String id) =>
      state.tasks.firstWhereOrNull((t) => t.id == id);

  Future<void> load() async {
    final tasks = await _s.store.loadTasks();
    state = state.copyWith(tasks: tasks, loading: false);
    _syncNotification();
  }

  Future<void> _onNewSms(SmsRow row) async {
    final smsOn =
        await _s.appState.getBoolean(AppStateKeys.smsMonitoringEnabled, true);
    if (!smsOn) return;
    final parsed =
        await _s.smsImporter.upsertSms(row.address, row.body, row.dateMillis);
    if (parsed != null) {
      final lawyer = await _lawyer();
      try {
        await _s.sync.resolveTaskById(parsed.id, lawyer);
      } catch (_) {}
    }
    final tasks = await _s.store.loadTasks();
    state = state.copyWith(tasks: tasks);
    _syncNotification();
  }

  void _syncNotification() {
    final pending = state.tasks
        .where((t) =>
            t.status != CourtTaskStatus.archived &&
            t.status != CourtTaskStatus.failed)
        .length;
    _s.notifications.sync(pending, '点按查看未处理的法院送达任务');
  }

  /// 取出原生侧"被杀时收到"的法院短信队列并解析入库（对照 app 内实时流）。
  Future<void> _drainPending(String lawyer) async {
    try {
      final rows = await _s.smsReader.drainPendingSms();
      for (final row in rows) {
        final parsed = await _s.smsImporter
            .upsertSms(row.address, row.body, row.dateMillis);
        if (parsed != null) {
          try {
            await _s.sync.resolveTaskById(parsed.id, lawyer);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (state.backgroundSyncing) return;
    state = state.copyWith(backgroundSyncing: true, syncError: '');
    final lawyer = await _lawyer();
    final smsOn =
        await _s.appState.getBoolean(AppStateKeys.smsMonitoringEnabled, true);
    await _s.smsReader.setNativeSmsEnabled(smsOn);
    var err = '';
    try {
      if (smsOn) {
        await _drainPending(lawyer);
        if (await _ensureSmsPermission()) {
          await _s.sync.importAndResolveRecentCourtSmsIncremental(
            lawyer,
            onProgress: (tasks, busy, prog) async {
              // 节流 250ms：后台同步每条任务前后都回调，全量刷会让列表频繁重建卡顿。
              final now = DateTime.now();
              if (now.difference(_lastProgressAt).inMilliseconds < 250) return;
              _lastProgressAt = now;
              state = state.copyWith(
                  tasks: tasks, busyTaskIds: busy, progress: prog);
            },
          );
        }
      }
    } catch (e) {
      err = '同步失败：$e';
    }
    final tasks = await _s.store.loadTasks();
    state = state.copyWith(
      tasks: tasks,
      backgroundSyncing: false,
      busyTaskIds: const {},
      progress: const CourtSyncProgress(),
      syncError: err,
    );
    _syncNotification();
  }

  Future<void> resolveTask(String id) async {
    final lawyer = await _lawyer();
    state = state.copyWith(busyTaskIds: {...state.busyTaskIds, id});
    try {
      await _s.sync.resolveTaskById(id, lawyer, force: true);
    } catch (_) {}
    final tasks = await _s.store.loadTasks();
    state = state.copyWith(
        tasks: tasks, busyTaskIds: state.busyTaskIds.difference({id}));
  }

  Future<void> downloadDocument(String taskId, String docId) async {
    final lawyer = await _lawyer();
    final task = taskById(taskId);
    if (task == null) return;
    state = state.copyWith(busyTaskIds: {...state.busyTaskIds, taskId});
    try {
      final updated =
          await _s.downloader.downloadDocument(task, docId, lawyer);
      await _s.store.updateTask(updated);
    } catch (_) {}
    final tasks = await _s.store.loadTasks();
    state = state.copyWith(
        tasks: tasks, busyTaskIds: state.busyTaskIds.difference({taskId}));
  }

  Future<void> markRead(String id) async {
    final task = taskById(id);
    if (task == null || !task.unread) return;
    await _s.store.updateTaskById(id, (t) => t.markRead());
    state = state.copyWith(tasks: await _s.store.loadTasks());
    _syncNotification();
  }

  Future<void> archiveTask(String id) async {
    await _s.store.archiveTasks([id]);
    state = state.copyWith(tasks: await _s.store.loadTasks());
    _syncNotification();
  }

  Future<void> restoreTask(String id) async {
    await _s.store.updateTaskById(
        id,
        (t) => t.copyWith(
            status: CourtTaskStatus.pending, updatedAt: nowMillis()));
    state = state.copyWith(tasks: await _s.store.loadTasks());
    _syncNotification();
  }

  Future<void> archiveCategory(CourtTaskCategory category) async {
    await _s.store.archiveCategory(category);
    state = state.copyWith(tasks: await _s.store.loadTasks());
    _syncNotification();
  }

  Future<void> deleteTask(String id) async {
    await _s.store.deleteTask(id);
    state = state.copyWith(tasks: await _s.store.loadTasks());
    _syncNotification();
  }

  /// 工具页：手动解析法院文书链接，返回任务 id（失败为 null）。
  Future<String?> resolveCourtLink(String link) async {
    final lawyer = await _lawyer();
    final task = await _s.sync.resolveCourtLink(link, lawyer);
    state = state.copyWith(tasks: await _s.store.loadTasks());
    return task?.id;
  }

  Future<void> resetData() async {
    await _s.store.clearAll();
    state = const CourtTasksState(loading: false);
    _syncNotification();
  }

  void setFilter(TaskFilter f) => state = state.copyWith(filter: f);
  void setCategory(DeliveryPageCategory c) => state = state.copyWith(category: c);
  void setAttention(AttentionFilter a) => state = state.copyWith(attention: a);
  void setQuery(String q) => state = state.copyWith(query: q);
  void setCourtFilter(String c) => state = state.copyWith(courtFilter: c);
}

final courtTasksProvider =
    NotifierProvider<CourtTasksController, CourtTasksState>(
        CourtTasksController.new);
