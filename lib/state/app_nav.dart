import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_state_store.dart';
import '../ui/ui_enums.dart';
import 'app_services.dart';

/// 当前底栏 tab（提供给跨页切换，如工作台「送达展开」）。
final appTabProvider = StateProvider<int>((_) => 0);

/// 送达页需要自动展开的任务 id（工作台「送达展开」模式用）。
final deliveryExpandTargetProvider = StateProvider<String?>((_) => null);

/// 再次点击当前 tab 的信号（计数器自增）→ 当前页滚动到顶。
final tabReselectProvider = StateProvider<int>((_) => 0);

/// 工作台日程项打开方式（详情 / 送达展开），持久化到 app_state。
class WorkbenchOpenModeController extends Notifier<WorkbenchOpenMode> {
  @override
  WorkbenchOpenMode build() {
    Future.microtask(_load);
    return WorkbenchOpenMode.detail;
  }

  Future<void> _load() async {
    final code = await ref.read(appServicesProvider).appState.getString(
          AppStateKeys.workbenchOpenMode,
          WorkbenchOpenMode.detail.name,
        );
    state = WorkbenchOpenMode.fromCode(code);
  }

  Future<void> set(WorkbenchOpenMode mode) async {
    state = mode;
    await ref
        .read(appServicesProvider)
        .appState
        .putString(AppStateKeys.workbenchOpenMode, mode.name);
  }
}

final workbenchOpenModeProvider =
    NotifierProvider<WorkbenchOpenModeController, WorkbenchOpenMode>(
        WorkbenchOpenModeController.new);
