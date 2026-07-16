import 'package:flutter/cupertino.dart';
import 'package:pdfrx/pdfrx.dart';

import '../fp/fp_widgets.dart';

/// 内置 PDF 查看页（pdfrx 渲染，深色背景 + FocusPoint 返回栏）。
class PdfViewerPage extends StatelessWidget {
  const PdfViewerPage({super.key, required this.title, required this.path});
  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF2C2C2E);
    return ColoredBox(
      color: dark,
      child: SafeArea(
        bottom: true,
        child: Column(
          children: [
            FpBackBar(
              label: title,
              onBack: () => Navigator.of(context).pop(),
              color: const Color(0xFFF7F7F5),
            ),
            Expanded(
              child: PdfViewer.file(
                path,
                params: const PdfViewerParams(backgroundColor: dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
