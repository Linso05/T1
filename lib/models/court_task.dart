import 'dart:convert';

import 'court_enums.dart';
import 'court_document.dart';
import '../data/court_parsers.dart';

int nowMillis() => DateTime.now().millisecondsSinceEpoch;

/// 法院送达任务，对照 Kotlin `CourtTask`。字段与 JSON key 保持一致。
class CourtTask {
  CourtTask({
    required this.id,
    required this.court,
    required this.caseNo,
    required this.url,
    this.qdbh = '',
    this.sdbh = '',
    this.sdsin = '',
    required this.contact,
    required this.summary,
    required this.smsAddress,
    required this.smsBody,
    required this.smsDateMillis,
    this.status = CourtTaskStatus.pending,
    this.clientName = '',
    this.documentTitle = '',
    this.documents = const [],
    this.pdfPath = '',
    this.pdfSha256 = '',
    this.error = '',
    this.category = CourtTaskCategory.document,
    this.unread = true,
    this.important = false,
    this.todoTimeMillis = 0,
    this.todoPlace = '',
    this.todoTitle = '',
    this.summonsCaseNo = '',
    this.summonsPerson = '',
    this.summonsTimeText = '',
    this.summonsPlace = '',
    this.summonsParseAttemptedAt = 0,
    this.summonsParseStatus = SummonsParseStatus.notAttempted,
    this.manualTodo = false,
    this.manualTodoNote = '',
    this.sourceType = MonitorSourceType.sms,
    this.syncState = TaskSyncState.idle,
    this.retryAt = 0,
    this.retryCount = 0,
    this.riskLevel = TaskRiskLevel.normal,
    int? updatedAt,
  }) : updatedAt = updatedAt ?? nowMillis();

  final String id;
  final String court;
  final String caseNo;
  final String url;
  final String qdbh;
  final String sdbh;
  final String sdsin;
  final String contact;
  final String summary;
  final String smsAddress;
  final String smsBody;
  final int smsDateMillis;
  final CourtTaskStatus status;
  final String clientName;
  final String documentTitle;
  final List<CourtDocument> documents;
  final String pdfPath;
  final String pdfSha256;
  final String error;
  final CourtTaskCategory category;
  final bool unread;
  final bool important;
  final int todoTimeMillis;
  final String todoPlace;
  final String todoTitle;
  final String summonsCaseNo;
  final String summonsPerson;
  final String summonsTimeText;
  final String summonsPlace;
  final int summonsParseAttemptedAt;
  final SummonsParseStatus summonsParseStatus;
  final bool manualTodo;
  final String manualTodoNote;
  final MonitorSourceType sourceType;
  final TaskSyncState syncState;
  final int retryAt;
  final int retryCount;
  final TaskRiskLevel riskLevel;
  final int updatedAt;

  CourtTask copyWith({
    String? id,
    String? court,
    String? caseNo,
    String? url,
    String? qdbh,
    String? sdbh,
    String? sdsin,
    String? contact,
    String? summary,
    String? smsAddress,
    String? smsBody,
    int? smsDateMillis,
    CourtTaskStatus? status,
    String? clientName,
    String? documentTitle,
    List<CourtDocument>? documents,
    String? pdfPath,
    String? pdfSha256,
    String? error,
    CourtTaskCategory? category,
    bool? unread,
    bool? important,
    int? todoTimeMillis,
    String? todoPlace,
    String? todoTitle,
    String? summonsCaseNo,
    String? summonsPerson,
    String? summonsTimeText,
    String? summonsPlace,
    int? summonsParseAttemptedAt,
    SummonsParseStatus? summonsParseStatus,
    bool? manualTodo,
    String? manualTodoNote,
    MonitorSourceType? sourceType,
    TaskSyncState? syncState,
    int? retryAt,
    int? retryCount,
    TaskRiskLevel? riskLevel,
    int? updatedAt,
  }) {
    return CourtTask(
      id: id ?? this.id,
      court: court ?? this.court,
      caseNo: caseNo ?? this.caseNo,
      url: url ?? this.url,
      qdbh: qdbh ?? this.qdbh,
      sdbh: sdbh ?? this.sdbh,
      sdsin: sdsin ?? this.sdsin,
      contact: contact ?? this.contact,
      summary: summary ?? this.summary,
      smsAddress: smsAddress ?? this.smsAddress,
      smsBody: smsBody ?? this.smsBody,
      smsDateMillis: smsDateMillis ?? this.smsDateMillis,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      documentTitle: documentTitle ?? this.documentTitle,
      documents: documents ?? this.documents,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfSha256: pdfSha256 ?? this.pdfSha256,
      error: error ?? this.error,
      category: category ?? this.category,
      unread: unread ?? this.unread,
      important: important ?? this.important,
      todoTimeMillis: todoTimeMillis ?? this.todoTimeMillis,
      todoPlace: todoPlace ?? this.todoPlace,
      todoTitle: todoTitle ?? this.todoTitle,
      summonsCaseNo: summonsCaseNo ?? this.summonsCaseNo,
      summonsPerson: summonsPerson ?? this.summonsPerson,
      summonsTimeText: summonsTimeText ?? this.summonsTimeText,
      summonsPlace: summonsPlace ?? this.summonsPlace,
      summonsParseAttemptedAt:
          summonsParseAttemptedAt ?? this.summonsParseAttemptedAt,
      summonsParseStatus: summonsParseStatus ?? this.summonsParseStatus,
      manualTodo: manualTodo ?? this.manualTodo,
      manualTodoNote: manualTodoNote ?? this.manualTodoNote,
      sourceType: sourceType ?? this.sourceType,
      syncState: syncState ?? this.syncState,
      retryAt: retryAt ?? this.retryAt,
      retryCount: retryCount ?? this.retryCount,
      riskLevel: riskLevel ?? this.riskLevel,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  CourtTask withStatus(CourtTaskStatus next, [String message = '']) =>
      copyWith(status: next, error: message, updatedAt: nowMillis());

  CourtTask markRead() => copyWith(unread: false, updatedAt: nowMillis());

  Map<String, dynamic> toJson() => {
        'id': id,
        'court': court,
        'caseNo': caseNo,
        'url': url,
        'qdbh': qdbh,
        'sdbh': sdbh,
        'sdsin': sdsin,
        'contact': contact,
        'summary': summary,
        'smsAddress': smsAddress,
        'smsBody': smsBody,
        'smsDateMillis': smsDateMillis,
        'status': status.code,
        'clientName': clientName,
        'documentTitle': documentTitle,
        'documents': documents.map((e) => e.toJson()).toList(),
        'pdfPath': pdfPath,
        'pdfSha256': pdfSha256,
        'error': error,
        'category': category.code,
        'unread': unread,
        'important': important,
        'todoTimeMillis': todoTimeMillis,
        'todoPlace': todoPlace,
        'todoTitle': todoTitle,
        'summonsCaseNo': summonsCaseNo,
        'summonsPerson': summonsPerson,
        'summonsTimeText': summonsTimeText,
        'summonsPlace': summonsPlace,
        'summonsParseAttemptedAt': summonsParseAttemptedAt,
        'summonsParseStatus': summonsParseStatus.code,
        'manualTodo': manualTodo,
        'manualTodoNote': manualTodoNote,
        'sourceType': sourceType.code,
        'syncState': syncState.code,
        'retryAt': retryAt,
        'retryCount': retryCount,
        'riskLevel': riskLevel.code,
        'updatedAt': updatedAt,
      };

  static CourtTask fromJson(Map<String, dynamic> json) {
    final documents = CourtDocument.listFromJson(json['documents'] as List<dynamic>?);
    final title = _str(json['documentTitle']);
    return CourtTask(
      id: _str(json['id']),
      court: _str(json['court']),
      caseNo: _str(json['caseNo']),
      url: _str(json['url']),
      qdbh: _str(json['qdbh']),
      sdbh: _str(json['sdbh']),
      sdsin: _str(json['sdsin']),
      contact: _str(json['contact']),
      summary: _str(json['summary']),
      smsAddress: _str(json['smsAddress']),
      smsBody: _str(json['smsBody']),
      smsDateMillis: _int(json['smsDateMillis']),
      status: CourtTaskStatus.fromCode(_int(json['status'])),
      clientName: _str(json['clientName']),
      documentTitle: title,
      documents: documents,
      pdfPath: _str(json['pdfPath']),
      pdfSha256: _str(json['pdfSha256']),
      error: _str(json['error']),
      category: CourtTaskCategory.fromCode(_int(json['category'])),
      unread: json.containsKey('unread') ? _bool(json['unread']) : true,
      important: json.containsKey('important')
          ? _bool(json['important'])
          : CourtParsers.isImportantDocument(title, documents),
      todoTimeMillis: _int(json['todoTimeMillis']),
      todoPlace: _str(json['todoPlace']),
      todoTitle: _str(json['todoTitle']),
      summonsCaseNo: _str(json['summonsCaseNo']),
      summonsPerson: _str(json['summonsPerson']),
      summonsTimeText: _str(json['summonsTimeText']),
      summonsPlace: _str(json['summonsPlace']),
      summonsParseAttemptedAt: _int(json['summonsParseAttemptedAt']),
      summonsParseStatus: SummonsParseStatus.fromCode(
          _int(json['summonsParseStatus'])),
      manualTodo: json.containsKey('manualTodo') ? _bool(json['manualTodo']) : false,
      manualTodoNote: _str(json['manualTodoNote']),
      sourceType: MonitorSourceType.fromCode(
          json.containsKey('sourceType') ? _int(json['sourceType']) : 0),
      syncState: TaskSyncState.fromCode(
          json.containsKey('syncState') ? _int(json['syncState']) : 0),
      retryAt: _int(json['retryAt']),
      retryCount: _int(json['retryCount']),
      riskLevel: TaskRiskLevel.fromCode(
          json.containsKey('riskLevel') ? _int(json['riskLevel']) : 0),
      updatedAt: json.containsKey('updatedAt') ? _int(json['updatedAt']) : nowMillis(),
    );
  }

  /// 序列化整张任务列表为 UTF-8 JSON 字节（对照 Kotlin listToJson）。
  static List<int> listToBytes(List<CourtTask> tasks) =>
      utf8.encode(jsonEncode(tasks.map((e) => e.toJson()).toList()));

  static List<CourtTask> listFromBytes(List<int> bytes) {
    try {
      final array = jsonDecode(utf8.decode(bytes)) as List<dynamic>;
      final result = <CourtTask>[];
      for (final item in array) {
        if (item is Map<String, dynamic>) {
          final task = fromJson(item);
          if (task.id.isNotEmpty && task.url.isNotEmpty) result.add(task);
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}

String _str(dynamic v) => v == null ? '' : v.toString();
int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
bool _bool(dynamic v) => v is bool ? v : (v == 'true' || v == 1);
