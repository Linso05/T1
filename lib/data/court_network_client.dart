import 'dart:math';

import 'package:dio/dio.dart';

/// 法院网络请求：POST 法院接口、下载 PDF，随机桌面 Chrome UA 和 acw_tc cookie。
/// 逐一对照 Kotlin `data/CourtNetworkClient.kt`。
class CourtNetworkClient {
  CourtNetworkClient({Dio? dio, Random? random})
      : _dio = dio ?? Dio(),
        _random = random ?? Random.secure();

  final Dio _dio;
  final Random _random;

  Future<String> postCourtJson(String url, String body) async {
    final resp = await _dio.post<String>(
      url,
      data: body,
      options: Options(
        responseType: ResponseType.plain,
        sendTimeout: const Duration(milliseconds: 12000),
        receiveTimeout: const Duration(milliseconds: 20000),
        validateStatus: (_) => true,
        headers: {
          'Accept': '*/*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Connection': 'keep-alive',
          'Content-Type': 'application/json',
          'Origin': 'https://zxfw.court.gov.cn',
          'Referer': 'https://zxfw.court.gov.cn/zxfw/',
          'Sec-Fetch-Dest': 'empty',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Site': 'same-origin',
          'User-Agent': _randomUserAgent(),
          'Cookie': 'acw_tc=${_randomAcwTc()}',
        },
      ),
    );
    final code = resp.statusCode ?? 0;
    final data = resp.data ?? '';
    if (code < 200 || code > 299) {
      throw Exception('HTTP $code $data');
    }
    return data;
  }

  Future<List<int>> downloadBytes(String url, {required String referer}) async {
    if (url.isEmpty) return const [];
    try {
      final resp = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(milliseconds: 12000),
          receiveTimeout: const Duration(milliseconds: 30000),
          validateStatus: (_) => true,
          headers: {
            'Accept': 'application/pdf,*/*',
            'Accept-Language': 'zh-CN,zh;q=0.9',
            'Referer': referer,
            'User-Agent': _randomUserAgent(),
            'Cookie': 'acw_tc=${_randomAcwTc()}',
          },
        ),
      );
      final code = resp.statusCode ?? 0;
      if (code < 200 || code > 299) return const [];
      return resp.data ?? const [];
    } catch (_) {
      return const [];
    }
  }

  String _randomUserAgent() {
    final chrome = 122 + _random.nextInt(27);
    final build = 6100 + _random.nextInt(1500);
    final patch = 40 + _random.nextInt(140);
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/$chrome.0.$build.$patch Safari/537.36';
  }

  String _randomAcwTc() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
