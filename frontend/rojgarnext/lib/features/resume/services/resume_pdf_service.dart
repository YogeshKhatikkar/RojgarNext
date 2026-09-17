// lib/features/resume/services/resume_pdf_service.dart
// ✅ Full page coverage for ALL formats
// ✅ Uses pw.Page (bounded height) → stretch + Expanded work correctly

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:rojgarnext/features/resume/presentation/screens/format/resume_format_manager.dart';

class ResumePdfService {
  // ============================================================
  // CORE: Build PDF bytes using the selected format
  // ============================================================
  static Future<Uint8List> buildPdfBytes({
    required Map<String, dynamic> data,
    required String styleKey,
    required String colorHex,
  }) async {
    final format = ResumeFormatManager.getFormatById(styleKey) ??
        ResumeFormatManager.defaultFormat;

    debugPrint('📄 ResumePdfService → format: ${format.id} (${format.name})');

    final doc = pw.Document();
    const pageFormat = PdfPageFormat.a4;

    // ✅ SINGLE PAGE — pw.Page provides BOUNDED height.
    // This makes crossAxisAlignment.stretch and pw.Expanded work inside
    // pw.Row → sidebar fills the entire A4 page top→bottom.
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => format.buildPdfContent(data, pageFormat),
      ),
    );

    return await doc.save();
  }

  // ============================================================
  // PUBLIC ACTIONS — download / print / share
  // ============================================================
  static Future<void> download({
    required String fileNameBase,
    required Map<String, dynamic> data,
    required String styleKey,
    required String colorHex,
  }) async {
    try {
      final bytes = await buildPdfBytes(
        data: data,
        styleKey: styleKey,
        colorHex: colorHex,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${fileNameBase}_${styleKey}_Resume.pdf',
      );
      debugPrint('✅ Downloaded: ${fileNameBase}_${styleKey}_Resume.pdf');
    } catch (e) {
      debugPrint('❌ Download error: $e');
      rethrow;
    }
  }

  static Future<void> print({
    required Map<String, dynamic> data,
    required String styleKey,
    required String colorHex,
  }) async {
    try {
      final bytes = await buildPdfBytes(
        data: data,
        styleKey: styleKey,
        colorHex: colorHex,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: '${styleKey}_Resume',
      );
      debugPrint('✅ Sent to printer: $styleKey');
    } catch (e) {
      debugPrint('❌ Print error: $e');
      rethrow;
    }
  }

  static Future<void> share({
    required String fileNameBase,
    required Map<String, dynamic> data,
    required String styleKey,
    required String colorHex,
  }) async {
    try {
      final bytes = await buildPdfBytes(
        data: data,
        styleKey: styleKey,
        colorHex: colorHex,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${fileNameBase}_${styleKey}_Resume.pdf',
      );
      debugPrint('✅ Shared: ${fileNameBase}_${styleKey}_Resume.pdf');
    } catch (e) {
      debugPrint('❌ Share error: $e');
      rethrow;
    }
  }
}