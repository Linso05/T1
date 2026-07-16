import 'package:flutter_test/flutter_test.dart';
import 'package:t1/data/court_parsers.dart';
import 'package:t1/models/court_enums.dart';

void main() {
  group('CourtParsers', () {
    test('解析法院送达短信', () {
      const body =
          '【上海市宝山区人民法院】您有一份送达文书，请点击链接查收 '
          'https://zxfw.court.gov.cn/zxfw/h5/index?qdbh=AAA&sdbh=BBB&sdsin=CCC '
          '（2026）沪0113民初10666号';
      final task = CourtParsers.parseCourtSms('12368', body, 1700000000000);
      expect(task, isNotNull);
      expect(task!.court, '上海市宝山区人民法院');
      expect(task.sdbh, 'BBB');
      expect(task.qdbh, 'AAA');
      expect(task.sdsin, 'CCC');
      expect(task.caseNo, contains('沪0113民初10666号'));
      expect(task.category, CourtTaskCategory.document);
    });

    test('文书类型判定', () {
      expect(CourtParsers.documentTypeFromName('传票（李世梅）.pdf'),
          CourtDocumentType.summons);
      expect(CourtParsers.documentTypeFromName('民事判决书.pdf'),
          CourtDocumentType.judgment);
      expect(CourtParsers.documentTypeFromName('民事裁定书.pdf'),
          CourtDocumentType.ruling);
      expect(CourtParsers.documentTypeFromName('诉讼费用缴纳通知.pdf'),
          CourtDocumentType.paymentNotice);
    });

    test('送达参数解析', () {
      final p = CourtParsers.deliveryParams(
          'https://x.cn/a?qdbh=Q1&sdbh=S1&sdsin=D1&foo=bar');
      expect(p.qdbh, 'Q1');
      expect(p.sdbh, 'S1');
      expect(p.sdsin, 'D1');
    });

    test('非送达审核短信归类', () {
      const body = '【上海市浦东新区人民法院】您提交的王金领诉韦保健民间借贷纠纷一案材料，'
          '审核结果为：退回补充材料';
      final task = CourtParsers.parseCourtSms('12368', body, 1700000000000);
      expect(task, isNotNull);
      expect(task!.category, CourtTaskCategory.review);
    });
  });
}
