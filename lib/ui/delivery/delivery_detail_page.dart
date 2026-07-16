import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/court_document.dart';
import '../../models/court_enums.dart';
import '../../models/court_task.dart';
import '../../state/court_tasks_controller.dart';
import '../../utils/kotlin_ext.dart';
import '../ai/ai_page.dart';
import '../formatters.dart';
import '../fp/fp_icons.dart';
import '../fp/fp_task_view.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';
import '../fp/fp_transitions.dart';
import '../pdf/pdf_viewer_page.dart';

/// 送达详情（mockup「详情」屏）。
class DeliveryDetailPage extends ConsumerWidget {
  const DeliveryDetailPage({super.key, required this.taskId, this.heroTag});
  final String taskId;

  /// 来源卡片的 Hero 标签（做「标题字体 morph」无缝转场）；null 时用默认 tag。
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(courtTasksProvider.notifier);
    // 只订阅这一条任务与它的忙碌态：后台同步刷新其它任务/进度时，本页不重建。
    // （缓存对未改动的任务保留同一实例，故 select 出的任务对象在同步期是稳定的。）
    final task = ref.watch(courtTasksProvider
        .select((s) => s.tasks.firstWhereOrNull((t) => t.id == taskId)));
    final busy = ref.watch(
        courtTasksProvider.select((s) => s.busyTaskIds.contains(taskId)));

    if (task == null) {
      return FpScreen(
        bottom: true,
        child: Column(
          children: [
            FpBackBar(label: '送达', onBack: () => Navigator.of(context).pop()),
            const Expanded(child: FpEmptyState(title: '任务已不存在')),
          ],
        ),
      );
    }

    final critical = task.riskLevel == TaskRiskLevel.critical;
    final failed = task.status == CourtTaskStatus.failed;
    final flagColor = (critical || failed) ? FpColors.red : FpColors.blue;
    final flagText = failed
        ? '异常 · 解析失败'
        : critical
            ? '紧急 · ${task.fpTypeLabel()}'
            : task.fpTypeLabel();

    return FpScreen(
      bottom: true,
      child: Column(
        children: [
          FpBackBar(label: '送达', onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // hero
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: FpColors.border)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                  color: flagColor, shape: BoxShape.circle),
                            ),
                            Text(
                              flagText.toUpperCase(),
                              style: TextStyle(
                                inherit: false,
                                fontFamily: 'CupertinoSystemText',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: flagColor,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Hero(
                          tag: heroTag ?? 'task-title-${task.id}',
                          flightShuttleBuilder:
                              fpTitleFlightShuttle(task.deliveryTitle()),
                          child: Text(
                            task.deliveryTitle(),
                            style: const TextStyle(
                              inherit: false,
                              fontFamily: 'CupertinoSystemText',
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              height: 1.2,
                              color: FpColors.ink1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          children: [
                            if (task.caseNo.isNotEmpty) FpChip(task.caseNo),
                            ...task.fpChips(max: 2),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 动作条
                  _ActionBar(task: task, busy: busy, controller: controller),
                  // 传票信息
                  if (task.hasSummonsInfo())
                    _Block('传票信息', [
                      _kv('传票案号', task.summonsCaseNo),
                      _kv('被传唤人', task.summonsPerson),
                      _kv(
                        '应到时间',
                        task.summonsTimeText.ifBlank(() => task.todoTimeMillis > 0
                            ? absoluteChinaTimeLabel(task.todoTimeMillis)
                            : ''),
                        hot: true,
                      ),
                      _kv('应到处所', task.summonsPlace.ifBlank(() => task.todoPlace)),
                    ]),
                  // 案件信息
                  _Block('案件信息', [
                    _kv('法院', task.court),
                    _kv('案号', task.caseNo),
                    _kv('客户/当事人', task.clientName),
                    _kv('收到时间', absoluteChinaTimeLabel(task.smsDateMillis)),
                    _kv('状态', task.status.label),
                    _kv('风险', task.riskLevel.label, hot: critical),
                    if (task.error.isNotEmpty) _kv('错误', task.error, hot: true),
                  ]),
                  // 文书列表
                  if (task.documents.isNotEmpty)
                    _Block('文书 · ${task.documents.length} 份', [
                      for (final d in task.documents)
                        _DocRow(task: task, doc: d, busy: busy, controller: controller),
                    ]),
                  // 短信原文
                  _Block('短信原文', [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                      decoration: BoxDecoration(
                        color: FpColors.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        task.smsBody.isEmpty ? '（无）' : task.smsBody,
                        style: const TextStyle(
                          inherit: false,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.75,
                          color: FpColors.ink2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 仅在 value 非空时渲染的 KV 行（最后一行的分割线由 _Block 处理）。
Widget? _kv(String label, String value, {bool hot = false}) {
  if (value.isEmpty) return null;
  return FpKvRow(label, value, hot: hot);
}

class _Block extends StatelessWidget {
  const _Block(this.label, this.children);
  final String label;
  final List<Widget?> children;

  @override
  Widget build(BuildContext context) {
    final rows = children.whereType<Widget>().toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FpColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label.toUpperCase(), style: FpText.sectionLabel),
          ),
          ...rows,
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.task, required this.busy, required this.controller});

  final CourtTask task;
  final bool busy;
  final CourtTasksController controller;

  @override
  Widget build(BuildContext context) {
    final archived = task.status == CourtTaskStatus.archived;
    final firstUndownloaded =
        task.documents.firstWhereOrNull((d) => d.localPath.isEmpty);
    final isHttp = task.url.startsWith('http');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FpColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            if (firstUndownloaded != null) ...[
              FpActionButton(
                text: '下载文书',
                icon: FpIcons.download,
                primary: true,
                onPressed: busy
                    ? null
                    : () =>
                        controller.downloadDocument(task.id, firstUndownloaded.id),
              ),
              const SizedBox(width: 6),
            ],
            if (!archived) ...[
              FpActionButton(
                text: '解析',
                icon: FpIcons.refresh,
                onPressed: busy ? null : () => controller.resolveTask(task.id),
              ),
              const SizedBox(width: 6),
            ],
            FpActionButton(
              text: '问 AI',
              icon: FpIcons.robot,
              onPressed: () => Navigator.of(context).push(
                fpSharedAxisRoute(
                  (_) => AiPage(
                    initialPrompt: _askAiPrompt(),
                    showBack: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
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
            if (isHttp) ...[
              const SizedBox(width: 6),
              FpActionButton(
                text: '原链接',
                icon: FpIcons.externalLink,
                onPressed: () => launchUrl(
                  Uri.parse(task.url),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
            const SizedBox(width: 6),
            FpActionButton(
              text: '移除',
              icon: FpIcons.trash,
              destructive: true,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  String _askAiPrompt() {
    final b = StringBuffer()..writeln('请基于以下法院送达任务，给出要点梳理与待办建议：');
    if (task.caseNo.isNotEmpty) b.writeln('案号：${task.caseNo}');
    if (task.court.isNotEmpty) b.writeln('法院：${task.court}');
    if (task.clientName.isNotEmpty) b.writeln('当事人：${task.clientName}');
    if (task.hasSummonsInfo()) {
      final time = task.summonsTimeText.ifBlank(() => task.todoTimeMillis > 0
          ? absoluteChinaTimeLabel(task.todoTimeMillis)
          : '');
      if (time.isNotEmpty) b.writeln('应到时间：$time');
      final place = task.summonsPlace.ifBlank(() => task.todoPlace);
      if (place.isNotEmpty) b.writeln('应到处所：$place');
    }
    if (task.documents.isNotEmpty) {
      b.writeln('文书：${task.documents.map((d) => d.name).join('、')}');
    }
    if (task.smsBody.isNotEmpty) b.writeln('短信原文：${task.smsBody}');
    return b.toString();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showFpConfirm(
      context,
      title: '移除任务',
      message: '将删除该任务及其本地 PDF，确定移除？',
      confirmText: '移除',
      destructive: true,
    );
    if (ok && context.mounted) {
      await controller.deleteTask(task.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.task,
    required this.doc,
    required this.busy,
    required this.controller,
  });

  final CourtTask task;
  final CourtDocument doc;
  final bool busy;
  final CourtTasksController controller;

  @override
  Widget build(BuildContext context) {
    final downloaded =
        doc.localPath.isNotEmpty && File(doc.localPath).existsSync();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FpColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    inherit: false,
                    fontFamily: 'CupertinoSystemText',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: FpColors.ink1,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (doc.important)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: FpColors.redTint,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '重要',
                          style: TextStyle(
                            inherit: false,
                            fontFamily: 'CupertinoSystemText',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: FpColors.red,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        [doc.type.label, doc.createdAt]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FpText.micro,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FpActionButton(
            text: downloaded ? '查看' : '下载',
            icon: downloaded ? FpIcons.eye : FpIcons.download,
            primary: !downloaded,
            onPressed: () {
              if (downloaded) {
                Navigator.of(context).push(
                  fpSharedAxisRoute(
                    (_) =>
                        PdfViewerPage(title: doc.name, path: doc.localPath),
                  ),
                );
              } else if (!busy) {
                controller.downloadDocument(task.id, doc.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
