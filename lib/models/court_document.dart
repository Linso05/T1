import 'court_enums.dart';
import '../data/court_parsers.dart';

/// 法院文书，对照 Kotlin `CourtDocument`。
/// JSON 字段名与 Kotlin 版严格一致，便于将来与旧 t1.db 数据互通。
class CourtDocument {
  const CourtDocument({
    required this.id,
    required this.name,
    required this.url,
    required this.format,
    required this.court,
    required this.createdAt,
    this.localPath = '',
    this.aiSummary = '',
    this.aiSummaryAt = 0,
    this.aiSummaryError = '',
    this.important = false,
    this.type = CourtDocumentType.other,
  });

  final String id;
  final String name;
  final String url;
  final String format;
  final String court;
  final String createdAt;
  final String localPath;
  final String aiSummary;
  final int aiSummaryAt;
  final String aiSummaryError;
  final bool important;
  final CourtDocumentType type;

  CourtDocument copyWith({
    String? id,
    String? name,
    String? url,
    String? format,
    String? court,
    String? createdAt,
    String? localPath,
    String? aiSummary,
    int? aiSummaryAt,
    String? aiSummaryError,
    bool? important,
    CourtDocumentType? type,
  }) {
    return CourtDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      format: format ?? this.format,
      court: court ?? this.court,
      createdAt: createdAt ?? this.createdAt,
      localPath: localPath ?? this.localPath,
      aiSummary: aiSummary ?? this.aiSummary,
      aiSummaryAt: aiSummaryAt ?? this.aiSummaryAt,
      aiSummaryError: aiSummaryError ?? this.aiSummaryError,
      important: important ?? this.important,
      type: type ?? this.type,
    );
  }

  /// 是否为传票文书（用于自动下载/解析判定）。
  bool get isSummonsDocument => type == CourtDocumentType.summons;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'format': format,
        'court': court,
        'createdAt': createdAt,
        'localPath': localPath,
        'aiSummary': aiSummary,
        'aiSummaryAt': aiSummaryAt,
        'aiSummaryError': aiSummaryError,
        'important': important,
        'type': type.code,
      };

  static CourtDocument fromJson(Map<String, dynamic> json) {
    final name = _str(json['name']);
    return CourtDocument(
      id: _str(json['id']),
      name: name,
      url: _str(json['url']),
      format: _str(json['format']),
      court: _str(json['court']),
      createdAt: _str(json['createdAt']),
      localPath: _str(json['localPath']),
      aiSummary: _str(json['aiSummary']),
      aiSummaryAt: _long(json['aiSummaryAt']),
      aiSummaryError: _str(json['aiSummaryError']),
      important: json.containsKey('important')
          ? _bool(json['important'])
          : CourtParsers.isImportantDocument(name, const []),
      type: json.containsKey('type')
          ? CourtDocumentType.fromCode(_int(json['type']))
          : CourtParsers.documentTypeFromName(name),
    );
  }

  static List<CourtDocument> listFromJson(List<dynamic>? array) {
    if (array == null) return const [];
    final result = <CourtDocument>[];
    for (final item in array) {
      if (item is Map<String, dynamic>) {
        final doc = fromJson(item);
        if (doc.url.isNotEmpty) result.add(doc);
      }
    }
    return result;
  }
}

// ---- JSON 取值兜底（对齐 Kotlin org.json 的 optXxx 行为）----
String _str(dynamic v) => v == null ? '' : v.toString();
int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
int _long(dynamic v) => _int(v);
bool _bool(dynamic v) => v is bool ? v : (v == 'true' || v == 1);
