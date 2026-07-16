import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state_store.dart';
import '../../state/app_services.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';

/// 高级配置：AI 接口与凭据，仅存本地 app_state。
class AdvancedConfigPage extends ConsumerStatefulWidget {
  const AdvancedConfigPage({super.key});

  @override
  ConsumerState<AdvancedConfigPage> createState() => _AdvancedConfigPageState();
}

class _AdvancedConfigPageState extends ConsumerState<AdvancedConfigPage> {
  final _fields = <String, TextEditingController>{};
  bool _loaded = false;

  // (key, 标题, 占位, 默认, 是否密码)
  static const _spec = <(String, String, String, String, bool)>[
    (AppStateKeys.aiEndpoint, 'AI 接口地址', AppConfigDefaults.aiEndpoint, AppConfigDefaults.aiEndpoint, false),
    (AppStateKeys.aiModel, 'AI 模型', AppConfigDefaults.aiModel, AppConfigDefaults.aiModel, false),
    (AppStateKeys.aiApiKey, 'AI 密钥', 'sk-…', '', true),
  ];

  // 暂时整页只读：输入框禁用，标「待实现」。
  static const _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = ref.read(appServicesProvider).appState;
    for (final s in _spec) {
      final v = await appState.getString(s.$1, s.$4);
      _fields[s.$1] = TextEditingController(text: v);
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  // 待实现：重新启用编辑时恢复保存逻辑。
  // ignore: unused_element
  Future<void> _save() async {
    final appState = ref.read(appServicesProvider).appState;
    for (final s in _spec) {
      await appState.putString(s.$1, _fields[s.$1]!.text.trim());
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FpScreen(
      bottom: true,
      child: Column(
        children: [
          FpBackBar(label: '设置', onBack: () => Navigator.of(context).pop()),
          if (!_loaded)
            const Expanded(child: Center(child: CupertinoActivityIndicator()))
          else
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                children: [
                  const Text(
                    '高级配置',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: FpColors.ink1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('功能待实现，暂不可配置。接口地址与凭据仅保存在本机。',
                      style: FpText.meta),
                  const SizedBox(height: 16),
                  for (final s in _spec) ...[
                    Text(s.$2, style: FpText.sectionLabel),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: 0.45,
                      child: CupertinoTextField(
                        controller: _fields[s.$1],
                        placeholder: s.$3,
                        obscureText: s.$5,
                        enabled: _enabled, // 待实现：禁用编辑
                        padding: const EdgeInsets.all(12),
                        style: const TextStyle(
                            fontSize: 13.5, color: FpColors.ink1),
                        decoration: BoxDecoration(
                          color: FpColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: FpColors.border2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FpColors.ink3,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '待实现',
                      style: TextStyle(
                        inherit: false,
                        fontFamily: 'CupertinoSystemText',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: FpColors.surface,
                        decoration: TextDecoration.none,
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
