import 'dart:convert';

import '../models/court_document.dart';
import '../models/court_task.dart';
import 'court_network_client.dart';
import 'court_parsers.dart';

/// 法院 getWsListBySdbhNew 接口请求和文书 JSON 转换。
/// 逐一对照 Kotlin `data/CourtDeliveryClient.kt`。
class CourtDeliveryClient {
  CourtDeliveryClient({CourtNetworkClient? network})
      : _network = network ?? CourtNetworkClient();

  final CourtNetworkClient _network;

  static const String _courtWsListUrl =
      'https://zxfw.court.gov.cn/yzw/yzw-zxfw-sdfw/api/v1/sdfw/getWsListBySdbhNew';

  Future<List<CourtDocument>> documentsFor(CourtTask task) async {
    final body = jsonEncode({
      'sdbh': task.sdbh,
      'qdbh': task.qdbh,
      'sdsin': task.sdsin,
    });
    final json = await _network.postCourtJson(_courtWsListUrl, body);
    return CourtParsers.parseWsListResponse(json);
  }
}
