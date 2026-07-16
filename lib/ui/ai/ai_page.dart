import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/ai_controller.dart';
import '../fp/fp_icons.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';

/// AI 助手（接真大模型，端口 L2 AiScreen）。
class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key, this.initialPrompt, this.showBack = false});

  final String? initialPrompt;
  final bool showBack;

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final prompt = widget.initialPrompt;
    if (prompt != null && prompt.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(aiControllerProvider.notifier).send(prompt);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    ref.read(aiControllerProvider.notifier).send(text);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: kFpEasing);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiControllerProvider);
    // 只在消息数或输入状态变化时滚到底，而不是每次 build（键盘弹起等无关重建不再触发滚动）。
    ref.listen(aiControllerProvider, (prev, next) {
      if (prev == null ||
          prev.messages.length != next.messages.length ||
          prev.typing != next.typing) {
        _scrollToEnd();
      }
    });
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return FpScreen(
      child: Column(
        children: [
          if (widget.showBack)
            FpBackBar(label: '返回', onBack: () => Navigator.of(context).pop())
          else
            const FpHeader(eyebrow: '办案辅助', title: 'AI 助手'),
          const _Disclaimer(),
          Expanded(
            child: ai.messages.isEmpty && !ai.typing
                ? const FpEmptyState(
                    title: '问点什么？',
                    subtitle: '总结案件、梳理待办、解释法律文书…\n（需先在「设置 → 高级配置」填写 AI 密钥）',
                  )
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    children: [
                      // 按索引 key：已有气泡的 State 被复用（不重播入场），
                      // 末尾新增的气泡带唯一 key → 触发 FpEntrance 淡入。
                      // typing 用独立 key，避免回复复用它的动画 State 而不淡入。
                      for (final (i, m) in ai.messages.indexed)
                        FpEntrance(
                          key: ValueKey('msg_$i'),
                          child: m.fromUser
                              ? _UserBubble(m.text)
                              : _AiBubble(m.text, error: m.error),
                        ),
                      if (ai.typing)
                        const FpEntrance(
                            key: ValueKey('typing'), child: _TypingDots()),
                    ],
                  ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.only(bottom: viewInsets),
            child: _InputBar(controller: _input, onSend: _send),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: FpColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FpColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(FpIcons.infoCircle, size: 14, color: FpColors.ink3),
          const SizedBox(width: 7),
          const Expanded(
            child: Text(
              '仅用于材料整理与办案辅助，不构成法律意见。',
              style: TextStyle(
                inherit: false,
                fontFamily: 'CupertinoSystemText',
                fontSize: 12,
                height: 1.5,
                color: FpColors.ink3,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 8, left: 50),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: const BoxDecoration(
          color: FpColors.ink1,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(17),
            topRight: Radius.circular(17),
            bottomLeft: Radius.circular(17),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            inherit: false,
            fontFamily: 'CupertinoSystemText',
            fontSize: 13.5,
            height: 1.5,
            color: FpColors.surface,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble(this.text, {this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8, right: 50),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: FpColors.surface,
          border: Border.all(color: error ? FpColors.redBorder : FpColors.border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(17),
            topRight: Radius.circular(17),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(17),
          ),
        ),
        // 正常回复走轻量 Markdown（标题/列表/加粗/代码）；错误消息保持纯红字。
        child: error
            ? Text(
                text,
                style: const TextStyle(
                  inherit: false,
                  fontFamily: 'CupertinoSystemText',
                  fontSize: 13,
                  height: 1.5,
                  color: FpColors.red,
                  decoration: TextDecoration.none,
                ),
              )
            : FpMarkdown(text, color: FpColors.ink1, fontSize: 13),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: FpColors.surface,
          border: Border.all(color: FpColors.border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(17),
            topRight: Radius.circular(17),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(17),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: _c,
                builder: (_, _) {
                  final t = (_c.value - i * 0.16) % 1.0;
                  final dy = (t < 0.3) ? -5.0 * (1 - (t / 0.3 - 1).abs()) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Transform.translate(
                      offset: Offset(0, dy),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: FpColors.ink3, shape: BoxShape.circle),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: const BoxDecoration(
        color: FpColors.surface,
        border: Border(top: BorderSide(color: FpColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: '输入问题…',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              style: const TextStyle(fontSize: 13.5, color: FpColors.ink1),
              decoration: BoxDecoration(
                color: FpColors.bg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: FpColors.border2),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 7),
          // 输入为空时按钮置灰禁用；有内容时可点、带触感与按压回弹。
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              final enabled = value.text.trim().isNotEmpty;
              return FpPressable(
                scale: 0.9,
                onTap: enabled
                    ? () {
                        HapticFeedback.selectionClick();
                        onSend();
                      }
                    : null,
                child: AnimatedContainer(
                  duration: FpMotion.fast,
                  curve: kFpEasing,
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enabled ? FpColors.ink1 : FpColors.border2,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(FpIcons.arrowUp,
                      size: 15, color: FpColors.surface),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
