import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/court_task_sync_service.dart';
import '../../models/court_enums.dart';
import '../../models/court_task.dart';
import '../../state/app_nav.dart';
import '../../state/court_tasks_controller.dart';
import '../../utils/kotlin_ext.dart';
import '../formatters.dart';
import '../fp/fp_icons.dart';
import '../fp/fp_task_view.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';
import '../fp/fp_transitions.dart';
import '../ui_enums.dart';
import 'delivery_detail_page.dart';

/// 送达中心（mockup「送达」屏）。筛选采用 L2「总筛选」：搜索 + 快捷胶囊 + 可展开面板。
class DeliveryPage extends ConsumerStatefulWidget {
  const DeliveryPage({super.key});

  @override
  ConsumerState<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends ConsumerState<DeliveryPage> {
  bool _expanded = false;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtl = TextEditingController();
  final List<String> _recent = [];

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _saveSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    setState(() {
      _recent
        ..removeWhere((x) => x == t)
        ..insert(0, t);
      if (_recent.length > 6) _recent.removeRange(6, _recent.length);
    });
  }

  // 记忆化：后台同步进度每 250ms 触发 rebuild，但 tasks/筛选没变时不重新过滤+排序。
  List<CourtTask>? _memoList;
  List<CourtTask>? _memoTasks;
  TaskFilter? _mFilter;
  DeliveryPageCategory? _mCat;
  AttentionFilter? _mAtt;
  String _mQuery = '';
  String _mCourt = '';

  List<CourtTask> _filtered(CourtTasksState s) {
    if (_memoList != null &&
        identical(s.tasks, _memoTasks) &&
        s.filter == _mFilter &&
        s.category == _mCat &&
        s.attention == _mAtt &&
        s.query == _mQuery &&
        s.courtFilter == _mCourt) {
      return _memoList!;
    }
    final c = s.category.category;
    final list = s.tasks
        .where((t) =>
            t.matchesFilter(s.filter) &&
            (c == null || t.category == c) &&
            t.matchesAttention(s.attention) &&
            t.matchesQuery(s.query) &&
            (s.courtFilter.isEmpty || t.courtNameForFilter() == s.courtFilter))
        .toList();
    // 纯按短信时间倒序，稳定排序——避免点开/已读改了优先级后列表跳动。
    list.sort((a, b) => b.smsDateMillis.compareTo(a.smsDateMillis));
    _memoList = list;
    _memoTasks = s.tasks;
    _mFilter = s.filter;
    _mCat = s.category;
    _mAtt = s.attention;
    _mQuery = s.query;
    _mCourt = s.courtFilter;
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courtTasksProvider);
    final controller = ref.read(courtTasksProvider.notifier);
    final all = state.tasks;
    final statusTasks =
        all.where((t) => t.matchesFilter(state.filter)).toList();
    final courts = all.availableCourts();
    final activeFilterCount = [
      state.filter != TaskFilter.active,
      state.category != DeliveryPageCategory.all,
      state.courtFilter.isNotEmpty,
      state.attention != AttentionFilter.all,
    ].where((b) => b).length;

    // 再次点击「送达」tab → 列表回顶。
    ref.listen(tabReselectProvider, (_, _) {
      if (ref.read(appTabProvider) == 1 && _scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic);
      }
    });

    // 工作台「送达展开」：切到全部分类并展开目标任务，处理完清空。
    final expandTarget = ref.watch(deliveryExpandTargetProvider);
    ref.listen(deliveryExpandTargetProvider, (_, next) {
      if (next != null) {
        controller.setCategory(DeliveryPageCategory.all);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(deliveryExpandTargetProvider.notifier).state = null;
          }
        });
      }
    });

    final list = _filtered(state);
    final summary = filterSummary(state.filter, state.attention, statusTasks, all,
        pageCategory: state.category, courtFilter: state.courtFilter);

    return FpScreen(
      child: Column(
        children: [
          const FpHeader(eyebrow: '送达中心', title: '送达'),
          // 搜索
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: CupertinoSearchTextField(
              controller: _searchCtl,
              placeholder: '案号、法院、当事人…',
              onChanged: controller.setQuery,
              onSubmitted: _saveSearch,
            ),
          ),
          // 搜索历史（空查询时显示，点按回填）
          if (state.query.isEmpty && _recent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FpFilterBar(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final s in _recent)
                    FpFilterChip(
                      text: s,
                      selected: false,
                      onTap: () {
                        _searchCtl.text = s;
                        controller.setQuery(s);
                      },
                    ),
                ],
              ),
            ),
          if (state.backgroundSyncing)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _SyncPill(progress: state.progress),
            ),
          // 总筛选下拉触发
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: FpColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_expanded || activeFilterCount > 0)
                        ? FpColors.ink1
                        : FpColors.border2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FpText.meta.copyWith(color: FpColors.ink1),
                      ),
                    ),
                    if (activeFilterCount > 0 && !_expanded)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FpChip('+$activeFilterCount', style: FpChipStyle.blue),
                      ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: kFpEasing,
                      child: Icon(FpIcons.chevronDown, size: 16, color: FpColors.ink3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 总筛选下拉面板（状态/关注/分类/法院）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: kFpEasing,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _FilterPanel(
                      state: state,
                      controller: controller,
                      allTasks: all,
                      statusTasks: statusTasks,
                      courts: courts,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.loading
                ? const FpSkeletonList()
                : CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                fpRefreshControl(controller.refresh),
                if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: state.syncError.isNotEmpty
                        ? FpErrorState(
                            subtitle: state.syncError,
                            onRetry: controller.refresh,
                          )
                        : const FpEmptyState(
                            title: '暂无任务',
                            subtitle: '下拉刷新会补扫法院短信并解析送达链接',
                          ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                    sliver: SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (_, j) => FpEntrance(
                        index: j,
                        child: _DeliveryCard(
                          key: ValueKey(list[j].id),
                          task: list[j],
                          busy: state.busyTaskIds.contains(list[j].id),
                          controller: controller,
                          expand: list[j].id == expandTarget,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    super.key,
    required this.task,
    required this.busy,
    required this.controller,
    this.expand = false,
  });

  final CourtTask task;
  final bool busy;
  final CourtTasksController controller;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final critical = task.riskLevel == TaskRiskLevel.critical;

    final type = failed
        ? '异常 · 解析失败'
        : critical
            ? '${task.fpTypeLabel()} · 紧急'
            : task.fpTypeLabel();
    final typeColor = failed
        ? FpColors.amber
        : critical
            ? FpColors.red
            : FpColors.ink3;
    // 对齐 L2：主标题用 deliveryTitle（当事人/案号「诉…」），法院作二级标题。
    final court = task.courtNameForFilter();
    final subtitle = court.isNotEmpty ? court : task.deliveryMetaLine();

    return FpExpandableCard(
      type: type,
      typeColor: typeColor,
      title: task.deliveryTitle(),
      subtitle: subtitle,
      trailingText: relativeDayLabel(task.smsDateMillis),
      border: task.fpBorder(),
      showBorder: false, // 列表卡片去边框
      opacity: archived ? 0.5 : 1,
      initiallyExpanded: expand,
      heroTag: 'task-title-${task.id}',
      onExpand: () => controller.markRead(task.id),
      bodyBuilder: (ctx) => _body(ctx),
    );
  }

  Widget _body(BuildContext context) {
    final undl = task.documents.where((d) => d.localPath.isEmpty).length;
    final docStatus = task.documents.isEmpty
        ? null
        : (undl == 0
            ? '${task.documents.length} 份已下载'
            : '$undl 份待下载');
    final timeChip =
        '${relativeDayLabel(task.smsDateMillis)} ${agendaTimeLabel(task.smsDateMillis)}';

    final kvs = <Widget>[];
    if (task.hasSummonsInfo()) {
      final time = task.summonsTimeText.ifBlank(() =>
          task.todoTimeMillis > 0 ? absoluteChinaTimeLabel(task.todoTimeMillis) : '');
      if (time.isNotEmpty) kvs.add(FpKvRow('应到时间', time, hot: true));
      final place = task.summonsPlace.ifBlank(() => task.todoPlace);
      if (place.isNotEmpty) kvs.add(FpKvRow('应到处所', place));
    }
    if (failedError.isNotEmpty) kvs.add(FpKvRow('错误原因', failedError));
    if (docStatus != null) kvs.add(FpKvRow('文书状态', docStatus));
    if (kvs.isNotEmpty) {
      // 最后一行去掉分割线
      kvs[kvs.length - 1] = _stripLast(kvs.last);
    }

    final firstUndownloaded =
        task.documents.firstWhereOrNull((d) => d.localPath.isEmpty);
    final isHttp = task.url.startsWith('http');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...kvs,
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 0,
            runSpacing: 6,
            children: [
              ...task.fpChips(max: 4),
              FpChip(timeChip),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (firstUndownloaded != null)
                FpActionButton(
                  text: '下载文书',
                  icon: FpIcons.download,
                  primary: true,
                  onPressed: busy
                      ? null
                      : () => controller.downloadDocument(
                          task.id, firstUndownloaded.id),
                ),
              if (!archived)
                FpActionButton(
                  text: '解析',
                  icon: FpIcons.refresh,
                  onPressed: busy ? null : () => controller.resolveTask(task.id),
                ),
              FpActionButton(
                text: '详情',
                icon: FpIcons.eye,
                onPressed: () => Navigator.of(context).push(
                  fpSharedAxisRoute(
                    (_) => DeliveryDetailPage(taskId: task.id),
                  ),
                ),
              ),
              FpActionButton(
                text: archived ? '取消归档' : '归档',
                icon: FpIcons.archive,
                onPressed: archived
                    ? () => controller.restoreTask(task.id)
                    : () {
                        HapticFeedback.mediumImpact();
                        controller.archiveTask(task.id);
                        showFpToast(context, '已归档',
                            actionLabel: '撤销',
                            onAction: () => controller.restoreTask(task.id));
                      },
              ),
              if (isHttp)
                FpActionButton(
                  text: '原链接',
                  icon: FpIcons.externalLink,
                  onPressed: () => launchUrl(
                    Uri.parse(task.url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              FpActionButton(
                text: '移除',
                icon: FpIcons.trash,
                destructive: true,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool get failed => task.status == CourtTaskStatus.failed;
  bool get archived => task.status == CourtTaskStatus.archived;
  String get failedError => failed ? task.error : '';

  Widget _stripLast(Widget kv) {
    if (kv is FpKvRow) {
      return FpKvRow(kv.label, kv.value, hot: kv.hot, last: true);
    }
    return kv;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showFpConfirm(
      context,
      title: '移除任务',
      message: '将删除该任务及其本地 PDF，确定移除？',
      confirmText: '移除',
      destructive: true,
    );
    if (ok) controller.deleteTask(task.id);
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.state,
    required this.controller,
    required this.allTasks,
    required this.statusTasks,
    required this.courts,
  });

  final CourtTasksState state;
  final CourtTasksController controller;
  final List<CourtTask> allTasks;
  final List<CourtTask> statusTasks;
  final List<String> courts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FpColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FpColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FpInlineFilterGroup(
            title: '状态',
            children: [
              for (final item in TaskFilter.values)
                FpFilterChip(
                  text: '${item.label} ${allTasks.where((t) => t.matchesFilter(item)).length}',
                  selected: state.filter == item,
                  onTap: () => controller.setFilter(item),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FpInlineFilterGroup(
            title: '关注',
            children: [
              for (final item in AttentionFilter.values)
                () {
                  final count =
                      statusTasks.where((t) => t.matchesAttention(item)).length;
                  final label = (item != AttentionFilter.all && count > 0)
                      ? '${item.label} $count'
                      : item.label;
                  return FpFilterChip(
                    text: label,
                    selected: state.attention == item,
                    onTap: () => controller.setAttention(item),
                  );
                }(),
            ],
          ),
          const SizedBox(height: 10),
          FpInlineFilterGroup(
            title: '分类',
            children: [
              for (final cat in DeliveryPageCategory.values)
                FpFilterChip(
                  text: '${cat.label} ${_catCount(cat)}',
                  selected: state.category == cat,
                  onTap: () => controller.setCategory(cat),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FpInlineFilterGroup(
            title: '法院',
            children: [
              FpFilterChip(
                text: '全部法院',
                selected: state.courtFilter.isEmpty,
                onTap: () => controller.setCourtFilter(''),
              ),
              for (final court in courts)
                FpFilterChip(
                  text: compactCourtName(court),
                  selected: state.courtFilter == court,
                  onTap: () => controller.setCourtFilter(
                      state.courtFilter == court ? '' : court),
                ),
            ],
          ),
        ],
      ),
    );
  }

  int _catCount(DeliveryPageCategory cat) {
    final c = cat.category;
    return allTasks
        .where((t) =>
            t.matchesFilter(state.filter) &&
            (c == null || t.category == c) &&
            t.matchesAttention(state.attention) &&
            t.matchesQuery(state.query) &&
            (state.courtFilter.isEmpty ||
                t.courtNameForFilter() == state.courtFilter))
        .length;
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.progress});
  final CourtSyncProgress progress;

  @override
  Widget build(BuildContext context) {
    final label = progress.total > 0
        ? '正在解析 ${progress.visibleCurrent}/${progress.total}'
        : '正在扫描法院短信';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FpColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FpColors.border),
      ),
      child: Row(
        children: [
          const CupertinoActivityIndicator(radius: 8),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: FpText.meta),
          ),
        ],
      ),
    );
  }
}
