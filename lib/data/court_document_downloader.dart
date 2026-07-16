import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/court_enums.dart';
import '../models/court_task.dart';
import '../models/court_document.dart';
import '../utils/kotlin_ext.dart';
import 'court_network_client.dart';
import 'court_parsers.dart';
import 'court_task_rules.dart';

/// 顶层函数：在后台 isolate 解码 PDF（CMap zlib inflate + 正则），避免阻塞 UI。
CourtPdfInfo _extractPdfInfoIsolate((List<int>, String, String) args) =>
    CourtParsers.extractCourtPdfInfo(args.$1, args.$2, args.$3);

/// PDF 下载、传票自动下载和传票字段合并。
/// 逐一对照 Kotlin `data/CourtDocumentDownloader.kt`。
class CourtDocumentDownloader {
  CourtDocumentDownloader(this._pdfDir, {CourtNetworkClient? network})
      : _network = network ?? CourtNetworkClient();

  final Directory _pdfDir;
  final CourtNetworkClient _network;

  Future<CourtTask> downloadDocument(
      CourtTask task, String documentId, [String lawyerName = '']) async {
    final index = task.documents.indexWhere((d) => d.id == documentId);
    if (index < 0) return task;
    final document = task.documents[index];

    if (document.localPath.isNotEmpty && File(document.localPath).existsSync()) {
      final bytes = _readOrEmpty(document.localPath);
      if (bytes.isNotEmpty && document.isSummonsDocument) {
        return _withSummonsPdfInfo(task, document, bytes, lawyerName);
      }
      return task;
    }

    final bytes = await _network.downloadBytes(document.url,
        referer: task.url.ifBlank(() => 'https://zxfw.court.gov.cn/zxfw/'));
    if (bytes.isEmpty) {
      return task.withStatus(CourtTaskStatus.failed, '文书下载失败');
    }
    final file = File(p.join(_pdfDir.path, _documentFileName(task, document)));
    await file.writeAsBytes(bytes);
    final nextDocuments = [...task.documents];
    nextDocuments[index] = document.copyWith(localPath: file.path);
    final downloaded =
        task.copyWith(documents: nextDocuments, pdfPath: file.path);
    final CourtTask merged = nextDocuments[index].isSummonsDocument
        ? await _withSummonsPdfInfo(
            downloaded, nextDocuments[index], bytes, lawyerName)
        : downloaded;
    return merged.copyWith(
        status: CourtTaskStatus.pdfFound, error: '', updatedAt: nowMillis());
  }

  Future<CourtTask> autoDownloadSummons(CourtTask task,
      [String lawyerName = '']) async {
    final document =
        task.documents.where((d) => d.isSummonsDocument).firstOrNull;
    if (document == null) return task;
    if (task.summonsParseAttemptedAt > 0) return task;

    final existingPath = document.localPath;
    final hasExisting =
        existingPath.isNotEmpty && File(existingPath).existsSync();
    final bytes = hasExisting
        ? _readOrEmpty(existingPath)
        : await _network.downloadBytes(document.url,
            referer: task.url.ifBlank(() => 'https://zxfw.court.gov.cn/zxfw/'));
    if (bytes.isEmpty) {
      return task.copyWith(
        summonsParseAttemptedAt: nowMillis(),
        summonsParseStatus: SummonsParseStatus.downloadFailed,
        updatedAt: nowMillis(),
      );
    }
    final File file;
    if (hasExisting) {
      file = File(existingPath);
    } else {
      file = File(p.join(_pdfDir.path, _documentFileName(task, document)));
      await file.writeAsBytes(bytes);
    }
    final documents = task.documents
        .map((d) => d.id == document.id ? d.copyWith(localPath: file.path) : d)
        .toList();
    final updatedDoc = documents.firstWhere((d) => d.id == document.id);
    final parsed = await _withSummonsPdfInfo(
        task.copyWith(documents: documents, pdfPath: file.path),
        updatedDoc,
        bytes,
        lawyerName);
    return parsed.copyWith(
        status: CourtTaskStatus.pdfFound, error: '', updatedAt: nowMillis());
  }

  Future<CourtTask> _withSummonsPdfInfo(
      CourtTask task, CourtDocument document, List<int> bytes,
      String lawyerName) async {
    final pdfInfo = await compute(
        _extractPdfInfoIsolate, (bytes, lawyerName, document.name));
    final isSummons = document.type == CourtDocumentType.summons ||
        pdfInfo.documentTitle.contains('传票');
    final isImportant = task.important ||
        CourtParsers.isImportantDocument(document.name, task.documents) ||
        pdfInfo.documentTitle.contains('传票') ||
        pdfInfo.documentTitle.contains('判决');
    final parseSuccess = pdfInfo.summonsCaseNo.isNotEmpty ||
        pdfInfo.summonsPerson.isNotEmpty ||
        pdfInfo.summonsTimeText.isNotEmpty ||
        pdfInfo.summonsPlace.isNotEmpty ||
        pdfInfo.hearingTimeMillis > 0 ||
        pdfInfo.hearingPlace.isNotEmpty;
    final repairPerson = task.needsSummonsPersonRepair();
    final String nextSummonsPerson;
    if (repairPerson && pdfInfo.summonsPerson.isNotEmpty) {
      nextSummonsPerson = pdfInfo.summonsPerson;
    } else if (task.summonsPerson.isBlank) {
      nextSummonsPerson = pdfInfo.summonsPerson;
    } else {
      nextSummonsPerson = task.summonsPerson;
    }
    final String nextClientName;
    if (repairPerson && pdfInfo.summonsPerson.isNotEmpty) {
      nextClientName = pdfInfo.summonsPerson;
    } else if (task.clientName.isBlank) {
      nextClientName = pdfInfo.summonsPerson.ifBlank(() => pdfInfo.clientName);
    } else {
      nextClientName = task.clientName;
    }
    return task.copyWith(
      pdfSha256: pdfInfo.sha256,
      caseNo: task.caseNo.ifBlank(() => pdfInfo.summonsCaseNo),
      clientName: nextClientName,
      documentTitle: task.documentTitle.ifBlank(() => pdfInfo.documentTitle),
      important: isImportant,
      riskLevel: isSummons
          ? TaskRiskLevel.critical
          : (isImportant ? TaskRiskLevel.important : task.riskLevel),
      todoTimeMillis: (isSummons && pdfInfo.hearingTimeMillis > 0)
          ? pdfInfo.hearingTimeMillis
          : task.todoTimeMillis,
      todoPlace: (isSummons && pdfInfo.summonsPlace.isNotEmpty)
          ? pdfInfo.summonsPlace
          : ((isSummons && pdfInfo.hearingPlace.isNotEmpty)
              ? pdfInfo.hearingPlace
              : task.todoPlace),
      todoTitle: isSummons
          ? '开庭：${nextSummonsPerson.ifBlank(() => task.deliveryName())}'
          : task.todoTitle,
      summonsCaseNo: task.summonsCaseNo.ifBlank(() => pdfInfo.summonsCaseNo),
      summonsPerson: nextSummonsPerson,
      summonsTimeText: task.summonsTimeText.ifBlank(() => pdfInfo.summonsTimeText),
      summonsPlace: task.summonsPlace.ifBlank(() => pdfInfo.summonsPlace),
      summonsParseAttemptedAt: nowMillis(),
      summonsParseStatus:
          parseSuccess ? SummonsParseStatus.success : SummonsParseStatus.unrecognized,
      updatedAt: nowMillis(),
    );
  }

  String _documentFileName(CourtTask task, CourtDocument document) {
    return [
      _safeFileNamePart(task.id),
      _safeFileNamePart(document.id),
      document.safeFileName(),
    ].where((s) => s.isNotEmpty).join('-');
  }

  String _safeFileNamePart(String s) => s
      .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]+'), '_')
      .trim()
      .take(80);

  List<int> _readOrEmpty(String path) {
    try {
      return File(path).readAsBytesSync();
    } catch (_) {
      return const [];
    }
  }
}
