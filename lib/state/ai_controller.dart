import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_client.dart';
import '../data/app_state_store.dart';
import 'app_services.dart';

class AiMessage {
  const AiMessage(this.fromUser, this.text, {this.error = false});
  final bool fromUser;
  final String text;
  final bool error;
}

class AiState {
  const AiState({this.messages = const [], this.typing = false});
  final List<AiMessage> messages;
  final bool typing;

  AiState copyWith({List<AiMessage>? messages, bool? typing}) =>
      AiState(messages: messages ?? this.messages, typing: typing ?? this.typing);
}

/// AI 会话状态（单会话，全局共享）。
class AiController extends Notifier<AiState> {
  final AiClient _client = AiClient();

  @override
  AiState build() => const AiState();

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.typing) return;
    state = state.copyWith(
      messages: [...state.messages, AiMessage(true, t)],
      typing: true,
    );
    final appState = ref.read(appServicesProvider).appState;
    try {
      final endpoint = await appState.getString(
          AppStateKeys.aiEndpoint, AppConfigDefaults.aiEndpoint);
      final model =
          await appState.getString(AppStateKeys.aiModel, AppConfigDefaults.aiModel);
      final key = await appState.getString(AppStateKeys.aiApiKey, '');
      final reply = await _client.ask(t,
          endpoint: endpoint, model: model, apiKey: key);
      state = state.copyWith(
        messages: [...state.messages, AiMessage(false, reply)],
        typing: false,
      );
    } catch (e) {
      state = state.copyWith(
        messages: [...state.messages, AiMessage(false, '$e', error: true)],
        typing: false,
      );
    }
  }

  void clear() => state = const AiState();
}

final aiControllerProvider =
    NotifierProvider<AiController, AiState>(AiController.new);
