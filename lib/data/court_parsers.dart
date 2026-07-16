import 'dart:convert';
import 'dart:io';

import '../models/court_enums.dart';
import '../models/court_task.dart';
import '../models/court_document.dart';
import '../utils/kotlin_ext.dart';

/// 传票/法院 PDF 解析结果，对照 Kotlin `CourtPdfInfo`。
class CourtPdfInfo {
  const CourtPdfInfo({
    this.clientName = '',
    this.documentTitle = '',
    this.hearingTimeMillis = 0,
    this.hearingPlace = '',
    this.summonsCaseNo = '',
    this.summonsPerson = '',
    this.summonsTimeText = '',
    this.summonsPlace = '',
    this.sha256 = '',
  });

  final String clientName;
  final String documentTitle;
  final int hearingTimeMillis;
  final String hearingPlace;
  final String summonsCaseNo;
  final String summonsPerson;
  final String summonsTimeText;
  final String summonsPlace;
  final String sha256;
}

class DeliveryParams {
  const DeliveryParams(this.qdbh, this.sdbh, this.sdsin);
  final String qdbh;
  final String sdbh;
  final String sdsin;
}

class _HearingInfo {
  const _HearingInfo({this.timeMillis = 0, this.place = '', this.timeText = ''});
  final int timeMillis;
  final String place;
  final String timeText;
}

/// 短信、法院送达链接、法院接口返回、PDF 文本与传票字段解析。
/// 逐一对照 Kotlin `parser/CourtParsers.kt`。
class CourtParsers {
  CourtParsers._();

  static final RegExp _courtPattern = RegExp(r'【([^】]*法院)】');
  static final RegExp _casePattern =
      RegExp(r'[（(]\d{4}[）)][^，。；\s]{2,40}?号');
  static final RegExp _urlPattern = RegExp(r'https?://[^\s，。；]+');
  static final RegExp _contactPattern =
      RegExp(r'(负责[^，。；\s]{0,12}?[一-龥]{2,4})');
  static const List<String> _personRoles = [
    '受送达人', '当事人', '原告', '被告', '缴款者', '申请人',
    '被申请人', '上诉人', '被上诉人', '申请执行人', '被执行人',
  ];
  static const List<String> _titleWords = [
    '民事调解书', '民事裁定书', '民事判决书', '诉讼费用缴纳通知', '交纳诉讼费用通知书',
    '调解书', '调节', '传票', '举证通知书', '受理案件通知书', '应诉通知书', '送达回证',
  ];

  static CourtTask? parseCourtSms(String address, String body, int dateMillis) {
    final nonDelivery = _parseNonDeliveryCourtSms(address, body, dateMillis);
    if (nonDelivery != null) return nonDelivery;
    if (!body.contains('法院') || !body.contains('http')) return null;
    final urlMatch = _urlPattern.firstMatch(body);
    if (urlMatch == null) return null;
    final url = urlMatch.group(0)!.replaceFirst(RegExp(r'[，。;；]+$'), '');
    final params = deliveryParams(url);
    final court = _courtPattern.firstMatch(body)?.group(1) ?? '';
    final caseNo = _casePattern.firstMatch(body)?.group(0) ?? '';
    if (court.isBlank && caseNo.isBlank && params.sdbh.isBlank) return null;
    final contact = _contactPattern.firstMatch(body)?.group(0) ?? '';
    final summary = body
        .replaceAll(url, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .take(120);
    final id = stableId('$court|$caseNo|${params.sdbh.ifBlank(() => url)}');
    return CourtTask(
      id: id,
      court: court,
      caseNo: caseNo,
      url: url,
      qdbh: params.qdbh,
      sdbh: params.sdbh,
      sdsin: params.sdsin,
      contact: contact,
      summary: summary,
      smsAddress: address,
      smsBody: body,
      smsDateMillis: dateMillis,
      category: CourtTaskCategory.document,
    );
  }

  static List<CourtDocument> parseWsListResponse(String json) {
    try {
      final root = jsonDecode(json);
      final data = (root is Map) ? root['data'] : null;
      if (data is! List) return const [];
      final result = <CourtDocument>[];
      for (final item in data) {
        if (item is! Map) continue;
        final url = _optStr(item['wjlj']);
        if (url.isBlank) continue;
        final name = _optStr(item['c_wsmc'])
            .ifBlank(() => _optStr(item['c_stbh']).substringAfterLast('/'));
        result.add(CourtDocument(
          id: _optStr(item['c_wsbh']).ifBlank(() => stableId(url)),
          name: name,
          url: url,
          format: _optStr(item['c_wjgs']),
          court: _optStr(item['c_fymc']),
          createdAt: _optStr(item['dt_cjsj']),
          important: isImportantDocument(name, const []),
          type: documentTypeFromName(name),
        ));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  static CourtDocumentType documentTypeFromName(String name) {
    final text = name.urlDecode();
    if (text.contains('传票')) return CourtDocumentType.summons;
    if (text.contains('判决')) return CourtDocumentType.judgment;
    if (text.contains('裁定') || text.contains('裁决')) {
      return CourtDocumentType.ruling;
    }
    if (text.contains('举证')) return CourtDocumentType.evidenceNotice;
    if (text.contains('受理')) return CourtDocumentType.acceptanceNotice;
    if (text.contains('诉讼费用') || text.contains('缴费') || text.contains('交纳')) {
      return CourtDocumentType.paymentNotice;
    }
    if (text.contains('调解') || text.contains('调节')) {
      return CourtDocumentType.mediation;
    }
    return CourtDocumentType.other;
  }

  static String clientNameFromDocuments(
      List<CourtDocument> documents, String lawyerName) {
    for (final doc in documents) {
      for (final candidate in [doc.name, doc.name.urlDecode()]) {
        final name = _extractClientNameFromTitle(candidate, lawyerName);
        if (name != null) return name;
      }
    }
    return '';
  }

  static String titleFromDocuments(List<CourtDocument> documents) {
    if (documents.isEmpty) return '';
    return documents.first.name.removeSuffix('.pdf').removeSuffix('.PDF');
  }

  static CourtTaskCategory inferTaskCategory(
      String body, List<CourtDocument> documents) {
    if (documents.isNotEmpty ||
        body.contains('送达文书') ||
        (body.contains('查收') && body.contains('点击链接'))) {
      return CourtTaskCategory.document;
    }
    if (body.contains('审核') ||
        body.contains('已收悉') ||
        body.contains('审前准备')) {
      return CourtTaskCategory.review;
    }
    return CourtTaskCategory.other;
  }

  static bool isImportantDocument(String title, List<CourtDocument> documents) {
    final buffer = StringBuffer(title);
    for (final d in documents) {
      buffer.write(' ');
      buffer.write(d.name);
    }
    final text = buffer.toString();
    return ['传票', '判决', '判决书'].any((w) => text.contains(w));
  }

  static TaskRiskLevel riskLevelFromDocuments(
    List<CourtDocument> documents, [
    TaskRiskLevel current = TaskRiskLevel.normal,
  ]) {
    final text = documents.map((e) => e.name).join(' ');
    final TaskRiskLevel inferred;
    if (text.contains('传票')) {
      inferred = TaskRiskLevel.critical;
    } else if (text.contains('判决') || text.contains('判决书')) {
      inferred = TaskRiskLevel.important;
    } else if (documents.any((d) => d.important)) {
      inferred = TaskRiskLevel.important;
    } else if (documents.isNotEmpty) {
      inferred = TaskRiskLevel.notice;
    } else {
      inferred = TaskRiskLevel.normal;
    }
    return inferred.code > current.code ? inferred : current;
  }

  static DeliveryParams deliveryParams(String url) {
    final query = url.substringAfter('?', '');
    final values = <String, String>{};
    for (final part in query.split('&')) {
      final key = part.substringBefore('=', '');
      if (key.isBlank) continue;
      values[key] = part.substringAfter('=', '').uriDecode();
    }
    return DeliveryParams(
      values['qdbh'] ?? '',
      values['sdbh'] ?? '',
      values['sdsin'] ?? '',
    );
  }

  static CourtPdfInfo extractCourtPdfInfo(List<int> pdf, String lawyerName,
      [String documentName = '']) {
    final text = _extractPdfLikeText(pdf);
    final title = _firstContaining(_titleWords, text);
    final titleClient =
        _extractClientNameFromTitle(documentName, lawyerName) ?? '';
    final client = _extractClientName(text, lawyerName);
    final hearing = _extractHearingInfo(text);
    final normalized = _normalizePdfText(text);
    var summonsPerson = titleClient.ifBlank(() {
      final between = _extractBetweenLabels(
        normalized,
        ['被传唤人', '被人唤人', '被传唤单位'],
        ['工作单位', '住所', '传唤事由', '人唤事由', '应到时间', '庭审时间'],
      );
      return _isPlausibleClient(between, lawyerName) ? between : '';
    });
    if (summonsPerson.isBlank) summonsPerson = client;
    return CourtPdfInfo(
      clientName: titleClient.ifBlank(() => client),
      documentTitle: title,
      hearingTimeMillis: hearing.timeMillis,
      hearingPlace: hearing.place,
      summonsCaseNo: _casePattern.firstMatch(normalized)?.group(0) ?? '',
      summonsPerson: summonsPerson,
      summonsTimeText: _extractBetweenLabels(
        normalized,
        ['应到时间', '到庭时间', '开庭时间', '庭审时间'],
        ['应到处所', '应到地点', '开庭地点', '到庭地点', '注意事项'],
      ).ifBlank(() => hearing.timeText),
      summonsPlace: _extractBetweenLabels(
        normalized,
        ['应到处所', '应到地点', '开庭地点', '到庭地点'],
        ['注意事项', '联系人', '审判员', '书记员'],
      )
          .ifBlank(() => _extractOnlineHearingPlace(normalized))
          .ifBlank(() => hearing.place),
      sha256: sha256Hex(pdf),
    );
  }

  static String extractPdfTextForAi(List<int> pdf, {int maxChars = 18000}) {
    final lines = _extractPdfLikeText(pdf)
        // 控制字符（0x00-0x1F）除 \t(09)/\n(0A) 外替换为空格
        .replaceAll(RegExp(r'[ --]+'), ' ')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return lines.join('\n').take(maxChars);
  }

  // ---------------- 私有解析逻辑 ----------------

  static String _extractClientName(String text, String lawyerName) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '').replaceAll('：', ':');
    for (final role in _personRoles) {
      final m =
          RegExp('$role[:：]?([\\u4e00-\\u9fa5]{2,4})').firstMatch(normalized);
      final name = m?.group(1);
      if (name != null && _isPlausibleClient(name, lawyerName)) return name;
    }
    return '';
  }

  static _HearingInfo _extractHearingInfo(String text) {
    final normalized = _normalizePdfText(text);
    final time = _parseHearingTime(normalized);
    final place = _parseHearingPlace(normalized);
    final timeText = _extractLabeledValue(
        normalized, ['应到时间', '到庭时间', '开庭时间', '庭审时间']);
    return _HearingInfo(timeMillis: time, place: place, timeText: timeText);
  }

  static String _normalizePdfText(String text) =>
      text.replaceAll(RegExp(r'[\s　]+'), '').replaceAll('：', ':');

  static String _extractLabeledValue(String text, List<String> labels) {
    for (final label in labels) {
      final m = RegExp('$label[:：]?([^。；;，,]{2,80})').firstMatch(text);
      final v = m?.group(1)?.trimChars(['。', '；', ';', '，', ',', ' ']) ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static String _extractBetweenLabels(
      String text, List<String> labels, List<String> stopLabels) {
    for (final label in labels) {
      final start = text.indexOf(label);
      if (start < 0) continue;
      var valueStart = start + label.length;
      if (valueStart < text.length && text[valueStart] == ':') valueStart++;
      final ends = stopLabels
          .map((s) => text.indexOf(s, valueStart))
          .where((i) => i >= 0)
          .toList();
      final valueEnd =
          ends.isEmpty ? text.length : ends.reduce((a, b) => a < b ? a : b);
      return text
          .substring(valueStart, valueEnd)
          .trimChars(['。', '；', ';', '，', ',', ' '])
          .take(100);
    }
    return '';
  }

  static int _parseHearingTime(String text) {
    final m1 = RegExp(
            r'(\d{4})年(\d{1,2})月(\d{1,2})日(上午|下午|晚上|夜间)?(\d{1,2}):(\d{1,2})')
        .firstMatch(text);
    if (m1 != null) {
      final year = int.tryParse(m1.group(1)!);
      final month = int.tryParse(m1.group(2)!);
      final day = int.tryParse(m1.group(3)!);
      final hour = int.tryParse(m1.group(5)!);
      final minute = int.tryParse(m1.group(6)!) ?? 0;
      if (year == null || month == null || day == null || hour == null) {
        return 0;
      }
      return _toChinaMillis(year, month, day,
          _normalizeChineseHour(hour, m1.group(4) ?? ''), minute);
    }
    final m2 = RegExp(
            r'(\d{4})年(\d{1,2})月(\d{1,2})日(上午|下午|晚上|夜间)?(\d{1,2})[时点](\d{1,2})?分?')
        .firstMatch(text);
    if (m2 != null) {
      final year = int.tryParse(m2.group(1)!);
      final month = int.tryParse(m2.group(2)!);
      final day = int.tryParse(m2.group(3)!);
      final hour = int.tryParse(m2.group(5)!);
      final minute = int.tryParse(m2.group(6) ?? '') ?? 0;
      if (year == null || month == null || day == null || hour == null) {
        return 0;
      }
      return _toChinaMillis(year, month, day,
          _normalizeChineseHour(hour, m2.group(4) ?? ''), minute);
    }
    final m3 = RegExp(
            r'(\d{1,2})月(\d{1,2})日(上午|下午|晚上|夜间)?(\d{1,2})[时点](\d{1,2})?分?')
        .firstMatch(text);
    if (m3 != null) {
      final year = _chinaNow().year;
      final month = int.tryParse(m3.group(1)!);
      final day = int.tryParse(m3.group(2)!);
      final hour = int.tryParse(m3.group(4)!);
      final minute = int.tryParse(m3.group(5) ?? '') ?? 0;
      if (month == null || day == null || hour == null) return 0;
      return _toChinaMillis(year, month, day,
          _normalizeChineseHour(hour, m3.group(3) ?? ''), minute);
    }
    return 0;
  }

  static int _normalizeChineseHour(int hour, String marker) {
    var h = hour;
    if (['下午', '晚上', '夜间'].contains(marker) && hour >= 1 && hour <= 11) {
      h = hour + 12;
    }
    return h.clamp(0, 23);
  }

  static int _toChinaMillis(int year, int month, int day, int hour, int minute) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return 0;
    try {
      final m = minute.clamp(0, 59);
      final utc = DateTime.utc(year, month, day, hour, m);
      return utc.millisecondsSinceEpoch - 8 * 3600 * 1000;
    } catch (_) {
      return 0;
    }
  }

  static DateTime _chinaNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  static String _parseHearingPlace(String text) {
    final online = _extractOnlineHearingPlace(text);
    if (online.isNotEmpty) return online;
    final patterns = [
      RegExp(r'(?:开庭地点|开庭地址|地点|法庭)[:：]?([^。；;，,]{4,60})'),
      RegExp(r'在([^。；;，,]{2,40}(?:法庭|审判庭|法院|调解室))'),
    ];
    for (final p in patterns) {
      final v = p
          .firstMatch(text)
          ?.group(1)
          ?.trimChars(['。', '；', ';', '，', ',', ' ']);
      if (v != null && v.length >= 2) return v;
    }
    return '';
  }

  static String _extractOnlineHearingPlace(String text) {
    const keywords = ['在线庭审', '线上庭审', '互联网在线', '互联网庭审', '会议号'];
    if (!keywords.any((k) => text.contains(k))) return '';
    final meeting =
        RegExp(r'会议号[:：]?(\d{4,20})').firstMatch(text)?.group(1) ?? '';
    return meeting.isBlank ? '在线庭审' : '在线庭审（会议号$meeting）';
  }

  static CourtTask? _parseNonDeliveryCourtSms(
      String address, String body, int dateMillis) {
    if (!address.contains('12368') &&
        !body.contains('12368') &&
        !body.contains('法院')) {
      return null;
    }
    if (body.contains('http') && body.contains('送达文书')) return null;
    final category = inferTaskCategory(body, const []);
    if (category == CourtTaskCategory.document) return null;
    final court = _courtPattern.firstMatch(body)?.group(1) ?? '';
    final caseNo = _casePattern.firstMatch(body)?.group(0) ?? '';
    final workOrder =
        RegExp(r'\d{4}沪[一-龥\d]{4,24}号').firstMatch(body)?.group(0) ?? '';
    final reviewTitle =
        category == CourtTaskCategory.review ? parseReviewCaseTitle(body) : '';
    final summary = _parseNonDeliverySummary(body, category);
    if (category == CourtTaskCategory.review &&
        isOrphanReviewResult(body, summary, reviewTitle)) {
      return null;
    }
    if (category == CourtTaskCategory.review &&
        court.isBlank &&
        caseNo.isBlank &&
        workOrder.isBlank &&
        reviewTitle.isBlank) {
      return null;
    }
    final idSeed = [
      category.name,
      court,
      caseNo,
      workOrder,
      summary,
      (dateMillis ~/ 60000).toString(),
    ].join('|');
    return CourtTask(
      id: stableId(idSeed),
      court: court,
      caseNo: caseNo.ifBlank(() => workOrder),
      url: 'sms://${stableId(idSeed)}',
      contact: '',
      summary: summary,
      smsAddress: address,
      smsBody: body,
      smsDateMillis: dateMillis,
      category: category,
      clientName: reviewTitle,
    );
  }

  static String parseReviewCaseTitle(String body) {
    final afterCourt = body.substringAfter('】', body);
    final caseText = RegExp(r'([一-龥A-Za-z0-9（）()、，,\s]{2,80}?)一案')
            .firstMatch(afterCourt)
            ?.group(1)
            ?.trimChars(['，', ',', '。', ' ']) ??
        '';
    if (caseText.isBlank) return '';
    const causeWords = [
      '民间借贷纠纷', '买卖合同纠纷', '金融借款合同纠纷', '借款合同纠纷', '离婚纠纷',
      '劳动争议', '机动车交通事故责任纠纷', '房屋租赁合同纠纷', '物业服务合同纠纷',
      '合同纠纷', '侵权责任纠纷', '继承纠纷', '抚养费纠纷',
    ];
    var stripped = caseText;
    for (final w in causeWords) {
      stripped = stripped.substringBefore(w, stripped);
    }
    stripped = stripped.trimChars(['，', ',', '。', ' ']);
    return stripped.ifBlank(() => caseText).take(24);
  }

  static bool isGenericReviewNotice(String body) {
    final category = inferTaskCategory(body, const []);
    if (category != CourtTaskCategory.review) return false;
    final court = _courtPattern.firstMatch(body)?.group(1) ?? '';
    final caseNo = _casePattern.firstMatch(body)?.group(0) ?? '';
    final workOrder =
        RegExp(r'\d{4}沪[一-龥\d]{4,24}号').firstMatch(body)?.group(0) ?? '';
    final reviewTitle = parseReviewCaseTitle(body);
    return court.isBlank &&
        caseNo.isBlank &&
        workOrder.isBlank &&
        reviewTitle.isBlank;
  }

  static bool isOrphanReviewResult(String body,
      [String summary = '', String? reviewTitle]) {
    final title = reviewTitle ?? parseReviewCaseTitle(body);
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isNotBlank) return false;
    final hasCourtPrefix = _courtPattern.hasMatch(normalized);
    final hasCaseAnchor =
        normalized.contains('一案') || _casePattern.hasMatch(normalized);
    final looksLikeResultOnly =
        RegExp(r'^审核结果[:：].{1,60}$').hasMatch(normalized) ||
            RegExp(r'^(退回补充材料|审核通过|审核不通过|驳回|不予受理)$')
                .hasMatch(normalized) ||
            RegExp(r'^审核结果[:：].{1,60}$').hasMatch(summary) ||
            RegExp(r'^(退回补充材料|审核通过|审核不通过|驳回|不予受理)$')
                .hasMatch(summary);
    return looksLikeResultOnly && !hasCourtPrefix && !hasCaseAnchor;
  }

  static String _parseNonDeliverySummary(
      String body, CourtTaskCategory category) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (category == CourtTaskCategory.review) {
      final m1 =
          RegExp(r'审核结果为[:：]?([^。；;]{2,40})').firstMatch(normalized);
      if (m1 != null) return '审核结果：${m1.group(1)!.trim()}';
      final m2 = RegExp(r'(退回补充材料|审核通过|审核不通过|驳回|不予受理)')
          .firstMatch(normalized);
      if (m2 != null) return m2.group(0)!;
    }
    return normalized.take(140);
  }

  static String? _extractClientNameFromTitle(String title, String lawyerName) {
    final normalized = title
        .substringAfterLast('/')
        .removeSuffix('.pdf')
        .removeSuffix('.PDF');
    final candidates = <String?>[
      RegExp(r'^([一-龥]{2,4})[_-]').firstMatch(normalized)?.group(1),
      RegExp(r'[（(]([一-龥]{2,4})[，,）)]').firstMatch(normalized)?.group(1),
      RegExp(r'（([一-龥]{2,4})）').firstMatch(normalized)?.group(1),
      RegExp(r'\(([一-龥]{2,4})\)').firstMatch(normalized)?.group(1),
      RegExp(r'号([一-龥]{2,4})$').firstMatch(normalized)?.group(1),
    ];
    for (final c in candidates) {
      if (c != null && _isPlausibleClient(c, lawyerName)) return c;
    }
    return null;
  }

  static bool _isPlausibleClient(String value, String lawyerName) {
    if (value.isBlank || value == lawyerName) return false;
    const deny = [
      '人民法院', '调解员', '书记员', '审判员', '法官', '老师', '律师', '代理', '及其', '苏奕雯',
    ];
    return deny.every((d) => !value.contains(d));
  }

  // ---------------- PDF 文本/CMap 解码 ----------------

  static String _extractPdfLikeText(List<int> pdf) {
    final raw = latin1.decode(pdf);
    final utf8Text = _utf8OrEmpty(pdf);
    final streams = _extractPdfStreams(pdf);
    final cmapDecoded = _extractToUnicodeText(pdf);
    final combined = [raw, streams].join('\n');
    final literal = RegExp(r'\(([^()]{0,200})\)')
        .allMatches(combined)
        .map((m) => m.group(1) ?? '')
        .join('\n');
    final utf16 = RegExp(r'<((?:[0-9A-Fa-f]{4}){2,200})>')
        .allMatches(combined)
        .map((m) => hexUtf16Be(m.group(1)!))
        .whereType<String>()
        .join('\n');
    final uriDecoded = combined.urlDecode();
    return [cmapDecoded, utf8Text, literal, utf16, uriDecoded, combined]
        .join('\n')
        .replaceAll(r'\\r', '\n')
        .replaceAll(r'\\n', '\n')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')');
  }

  static String _utf8OrEmpty(List<int> pdf) {
    try {
      return utf8.decode(pdf, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  static String _extractToUnicodeText(List<int> pdf) {
    final raw = latin1.decode(pdf);
    final cmaps = <Map<int, String>>[];
    for (final m in RegExp(r'/ToUnicode\s+(\d+)\s+0\s+R').allMatches(raw)) {
      final objNum = int.tryParse(m.group(1) ?? '');
      if (objNum == null) continue;
      final bytes = _objectStream(pdf, objNum);
      if (bytes == null) continue;
      final map = _parseCMap(latin1.decode(bytes));
      if (map.isNotEmpty) cmaps.add(map);
    }
    if (cmaps.isEmpty) return '';
    final merged = <int, String>{};
    for (final m in cmaps) {
      merged.addAll(m);
    }
    final streams = _extractPdfStreams(pdf);
    final buffer = StringBuffer();
    for (final m in RegExp(r'<([0-9A-Fa-f]{4,})>').allMatches(streams)) {
      final hex = m.group(1)!;
      for (final code in _chunked(hex, 4)) {
        final key = int.tryParse(code, radix: 16) ?? -1;
        buffer.write(merged[key] ?? '');
      }
    }
    return buffer.toString();
  }

  static Map<int, String> _parseCMap(String cmap) {
    final result = <int, String>{};
    for (final block in RegExp(r'beginbfchar(.*?)endbfchar', dotAll: true)
        .allMatches(cmap)) {
      for (final match in RegExp(r'<([0-9A-Fa-f]+)>\s+<([0-9A-Fa-f]+)>')
          .allMatches(block.group(1)!)) {
        final from = int.tryParse(match.group(1)!, radix: 16);
        if (from == null) continue;
        result[from] = hexUtf16Be(match.group(2)!) ?? '';
      }
    }
    for (final block in RegExp(r'beginbfrange(.*?)endbfrange', dotAll: true)
        .allMatches(cmap)) {
      for (final match in RegExp(
              r'<([0-9A-Fa-f]+)>\s+<([0-9A-Fa-f]+)>\s+<([0-9A-Fa-f]+)>')
          .allMatches(block.group(1)!)) {
        final start = int.tryParse(match.group(1)!, radix: 16);
        final end = int.tryParse(match.group(2)!, radix: 16);
        final target = int.tryParse(match.group(3)!, radix: 16);
        if (start == null || end == null || target == null) continue;
        for (var code = start; code <= end; code++) {
          result[code] = String.fromCharCode(target + code - start);
        }
      }
    }
    return result;
  }

  static List<int>? _objectStream(List<int> pdf, int objectNumber) {
    final raw = latin1.decode(pdf);
    final objMatch = RegExp('\\b$objectNumber\\s+0\\s+obj\\b').firstMatch(raw);
    if (objMatch == null) return null;
    final objectStart = objMatch.start;
    final streamStart = raw.indexOf('stream', objectStart);
    if (streamStart < 0) return null;
    final streamEnd = raw.indexOf('endstream', streamStart);
    if (streamEnd < 0) return null;
    final dataStart = _skipPdfNewline(pdf, streamStart + 'stream'.length);
    final dataEnd = _trimPdfStreamEnd(pdf, dataStart, streamEnd);
    final data = pdf.sublist(dataStart, dataEnd);
    return _inflate(data) ?? data;
  }

  static String _extractPdfStreams(List<int> pdf) {
    final raw = latin1.decode(pdf);
    final chunks = <String>[];
    var pos = 0;
    while (pos < raw.length) {
      final start = raw.indexOf('stream', pos);
      if (start < 0) break;
      final dataStart = _skipPdfNewline(pdf, start + 'stream'.length);
      final end = raw.indexOf('endstream', dataStart);
      if (end < 0) break;
      final dataEnd = _trimPdfStreamEnd(pdf, dataStart, end);
      final data = pdf.sublist(dataStart, dataEnd);
      chunks.add(latin1.decode(data));
      final inflated = _inflate(data);
      if (inflated != null) chunks.add(latin1.decode(inflated));
      pos = end + 'endstream'.length;
    }
    return chunks.join('\n');
  }

  static List<int>? _inflate(List<int> data) {
    try {
      return zlib.decode(data);
    } catch (_) {
      return null;
    }
  }

  static int _skipPdfNewline(List<int> bytes, int start) {
    var index = start;
    if (index < bytes.length && bytes[index] == 0x0D) index++;
    if (index < bytes.length && bytes[index] == 0x0A) index++;
    return index;
  }

  static int _trimPdfStreamEnd(List<int> bytes, int start, int end) {
    var index = end;
    while (index > start &&
        (bytes[index - 1] == 0x0D || bytes[index - 1] == 0x0A)) {
      index--;
    }
    return index;
  }

  static String _firstContaining(List<String> words, String text) {
    for (final w in words) {
      if (text.contains(w)) return w;
    }
    return '';
  }

  static List<String> _chunked(String s, int size) {
    final result = <String>[];
    for (var i = 0; i < s.length; i += size) {
      result.add(s.substring(i, (i + size) > s.length ? s.length : i + size));
    }
    return result;
  }

  static String _optStr(dynamic v) => v == null ? '' : v.toString();
}
