import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/court_tasks_controller.dart';
import '../delivery/delivery_detail_page.dart';
import '../formatters.dart';
import '../fp/fp_icons.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';
import '../fp/fp_transitions.dart';

/// 工具（法院文书链接解析）。
class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  final _controller = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final link = _controller.text.trim();
    setState(() => _error = '');
    if (!hasDeliveryParams(link)) {
      setState(() => _error = '链接缺少 qdbh / sdbh / sdsin 送达参数');
      return;
    }
    setState(() => _busy = true);
    final id =
        await ref.read(courtTasksProvider.notifier).resolveCourtLink(link);
    if (!mounted) return;
    setState(() => _busy = false);
    if (id == null) {
      setState(() => _error = '解析失败，请检查链接或稍后重试');
      return;
    }
    Navigator.of(context).push(
      fpZoomRoute((_) => DeliveryDetailPage(taskId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FpScreen(
      child: ListView(
        children: [
          const FpHeader(eyebrow: '实用工具', title: '工具'),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 16, 14, 0),
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            decoration: BoxDecoration(
              color: FpColors.surface,
              borderRadius: BorderRadius.circular(FpRadii.card),
              border: Border.all(color: FpColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '法院文书链接解析',
                  style: TextStyle(
                    inherit: false,
                    fontFamily: 'CupertinoSystemText',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FpColors.ink1,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '粘贴含 qdbh / sdbh / sdsin 参数的法院送达链接，直接解析文书。',
                  style: FpText.meta,
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 3,
                  padding: const EdgeInsets.all(12),
                  placeholder:
                      'https://zxfw.court.gov.cn/...?qdbh=...&sdbh=...&sdsin=...',
                  style: const TextStyle(fontSize: 13, color: FpColors.ink1),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(FpIcons.link, size: 16, color: FpColors.ink3),
                  ),
                  decoration: BoxDecoration(
                    color: FpColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _error.isEmpty ? FpColors.border2 : FpColors.red,
                    ),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error,
                    style: const TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 12.5,
                      color: FpColors.red,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    FpActionButton(
                      text: _busy ? '解析中…' : '解析',
                      icon: FpIcons.search,
                      primary: true,
                      onPressed: _busy ? null : _parse,
                    ),
                    if (_controller.text.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      FpActionButton(
                        text: '清空',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _error = '');
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
