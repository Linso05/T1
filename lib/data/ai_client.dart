import 'package:dio/dio.dart';

/// AI 调用异常（带可读消息）。
class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// AI 客户端，端口 L2 `AiClient.kt`（OpenAI `responses` 接口形态）。
class AiClient {
  AiClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 15),
            ));

  final Dio _dio;

  Future<String> ask(
    String message, {
    required String endpoint,
    required String model,
    required String apiKey,
  }) async {
    if (message.trim().isEmpty) return '';
    if (apiKey.isEmpty) {
      throw AiException('AI 服务未配置：请在「设置 → 高级配置」填写接口密钥。');
    }
    final prompt = StringBuffer()
      ..writeln('你是 T1 里的 AI 助理。T1 是律师工作台，用于法院短信送达任务、法院文书链接解析、案件材料整理和办案辅助。')
      ..writeln('回答要求：中文、简洁、可执行；涉及法律期限或金额时提示用户核对原文和当地规则。')
      ..writeln('用户问题：')
      ..writeln(message);
    try {
      final resp = await _dio.post<dynamic>(
        endpoint,
        data: {'model': model, 'input': prompt.toString()},
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      );
      final text = _parse(resp.data);
      if (text.isEmpty) throw AiException('AI 未返回内容');
      return text;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      throw AiException('AI 请求失败${code != null ? ' (HTTP $code)' : ''}：${e.message ?? e.type.name}');
    }
  }

  String _parse(dynamic data) {
    final json = data is Map ? data : <String, dynamic>{};
    final output = json['output'];
    if (output is List) {
      final sb = StringBuffer();
      for (final item in output) {
        if (item is! Map) continue;
        switch (item['type']) {
          case 'output_text':
            sb.writeln('${item['text'] ?? ''}');
            break;
          case 'message':
            final content = item['content'];
            if (content is List) {
              for (final part in content) {
                if (part is Map && part['type'] == 'output_text') {
                  sb.writeln('${part['text'] ?? ''}');
                }
              }
            }
            break;
        }
      }
      return sb.toString().trim();
    }
    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty) {
      final msg = (choices.first as Map?)?['message'];
      if (msg is Map) return '${msg['content'] ?? ''}'.trim();
    }
    return '';
  }
}
