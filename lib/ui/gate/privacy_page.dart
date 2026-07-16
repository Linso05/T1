import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state_store.dart';
import '../../state/app_services.dart';
import '../fp/fp_tokens.dart';
import '../fp/fp_widgets.dart';
import '../legal_dialogs.dart';

const String kPrivacyVersion = '2026-06-23';

/// 首次启动隐私门槛：未同意当前版本隐私政策前不进入主功能、不读取短信。
class PrivacyGate extends ConsumerStatefulWidget {
  const PrivacyGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends ConsumerState<PrivacyGate> {
  bool? _accepted;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final appState = ref.read(appServicesProvider).appState;
    final accepted =
        await appState.getBoolean(AppStateKeys.privacyAccepted, false);
    final version = await appState.getString(AppStateKeys.privacyVersion);
    if (mounted) {
      setState(() => _accepted = accepted && version == kPrivacyVersion);
    }
  }

  Future<void> _accept() async {
    final appState = ref.read(appServicesProvider).appState;
    await appState.putBoolean(AppStateKeys.privacyAccepted, true);
    await appState.putString(AppStateKeys.privacyVersion, kPrivacyVersion);
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted == null) {
      return const ColoredBox(
        color: FpColors.bg,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_accepted!) return widget.child;

    return FpScreen(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '欢迎使用 T1',
              style: TextStyle(
                inherit: false,
                fontFamily: 'CupertinoSystemText',
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: FpColors.ink1,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text('律师法院送达工作台', style: FpText.pageSub),
            const SizedBox(height: 22),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FpColors.surface,
                  borderRadius: BorderRadius.circular(FpRadii.card),
                  border: Border.all(color: FpColors.border),
                ),
                child: const SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    kPrivacyPolicyText,
                    style: TextStyle(
                      inherit: false,
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 13.5,
                      height: 1.65,
                      color: FpColors.ink1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _accept,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FpColors.ink1,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Text(
                  '同意并进入',
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
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => SystemNavigator.pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text('不同意并退出', style: FpText.pageSub),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
