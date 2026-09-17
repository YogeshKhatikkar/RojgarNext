// lib/features/resume/presentation/screens/format/resume_format_base.dart
//
// ✅ Base class that ALL resume formats must extend.
// ✅ Contains: 3 abstract methods (html, preview, pdf) + 20+ shared helpers.
// ✅ Adding a new format = extend this class + implement 3 methods.
// ✅ No changes needed anywhere else in the codebase.
// ✅ FIXED: pdfSideItem() sanitizes Unicode chars for Helvetica font.

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

abstract class ResumeFormatBase {
  // ============================================================
  // FORMAT IDENTITY — every format must override these
  // ============================================================
  String get id;
  String get name;
  String get icon;
  String get description;
  String get color;
  String get styleKey;
  String get templateType;
  String get badgeText;

  // ============================================================
  // 3 ABSTRACT METHODS — every format must implement these
  // ============================================================

  /// Generate standalone HTML for WebView / print
  String generateHtml(Map<String, dynamic> resumeData);

  /// Build native Flutter preview — must fit full page
  Widget buildPreview(BuildContext context, Map<String, dynamic> data);

  /// ✅ Build PDF content for this format.
  /// ResumePdfService just wraps this in a page and prints/downloads it.
  /// Adding a new format → implement this → no other file needs changes.
  pw.Widget buildPdfContent(Map<String, dynamic> data, PdfPageFormat pageFormat);

  // ============================================================
  // FLUTTER PREVIEW HELPERS — used by all formats
  // ============================================================

  Map<String, dynamic> pMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> pList(dynamic v) {
    if (v is List) return v.map((e) => pMap(e)).toList();
    return <Map<String, dynamic>>[];
  }

  String pStr(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  int pInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  String pLocation(Map<String, dynamic> data) {
    final c = pMap(data['contact_info']);
    final addr = pMap(c['current_address']);
    final city = pStr(addr['city']);
    final state = pStr(addr['state']);
    final country = pStr(addr['country']);
    final parts = <String>[];
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty && state != city) parts.add(state);
    if (country.isNotEmpty && country != 'India' && country != state) {
      parts.add(country);
    }
    if (parts.isNotEmpty) return parts.join(', ');
    return pStr(c['location'], 'India');
  }

  List<String> pSkills(dynamic skillsData) {
    final map = pMap(skillsData);
    final all = map['all'];
    if (all is List) {
      return all
          .map((s) => pStr(pMap(s)['name'] ?? s))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  List<String> pTools(Map<String, dynamic> data, [int limit = 12]) {
    final tools = <String>{};
    final t = data['tools'];
    if (t is List) {
      for (final x in t) {
        final s = pStr(x);
        if (s.isNotEmpty) tools.add(s);
      }
    }
    for (final proj in pList(data['projects'])) {
      final tech = proj['technologies'];
      if (tech is List) {
        for (final x in tech) {
          final s = pStr(x);
          if (s.isNotEmpty) tools.add(s);
        }
      }
    }
    return tools.take(limit).toList();
  }

  String pDesignation(Map<String, dynamic> data) {
    final exp = pList(data['experience']);
    for (final e in exp) {
      final isCurrent = e['is_current'] == true ||
          pStr(e['end_date']).isEmpty ||
          pStr(e['end_date']).toLowerCase() == 'present';
      if (isCurrent) return pStr(e['role']);
    }
    if (exp.isNotEmpty) return pStr(exp.first['role']);
    final goals = pMap(data['career_goals']);
    final dream = pStr(goals['dream_role']);
    if (dream.isNotEmpty) return dream;
    return '';
  }

  String pEduTitle(Map<String, dynamic> edu) {
    final degree = pStr(edu['degree']);
    final level = pStr(edu['level']);
    if (degree.isNotEmpty) return degree;
    if (level.isNotEmpty) return level;
    return 'Education';
  }

  String pEduSubtitle(Map<String, dynamic> edu) {
    final parts = <String>[];
    final inst = pStr(edu['institute']);
    final board = pStr(edu['board_university']);
    final year = pStr(edu['year_of_passing'] ?? edu['year']);
    final score = edu['cgpa_percentage'] != null
        ? '${pStr(edu['result_type'], 'Score')}: ${pStr(edu['cgpa_percentage'])}'
        : '';
    if (inst.isNotEmpty) parts.add(inst);
    if (board.isNotEmpty && board != inst) parts.add(board);
    if (year.isNotEmpty) parts.add(year);
    if (score.isNotEmpty) parts.add(score);
    return parts.join(' | ');
  }

  String pCert(Map<String, dynamic> cert) {
    final name = pStr(cert['name']);
    final issuer = pStr(cert['issuer']);
    final year = pStr(cert['year']);
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (issuer.isNotEmpty) parts.add(issuer);
    if (year.isNotEmpty) parts.add(year);
    return parts.join(' - ');
  }

  Widget pCard({
    required Widget child,
    Color bg = const Color(0xFFFAFAFA),
    Color? leftBorder,
    double radius = 8,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: leftBorder != null
            ? Border(left: BorderSide(color: leftBorder, width: 4))
            : null,
      ),
      child: child,
    );
  }

  Widget pInfoBox(
    String text, {
    Color bg = const Color(0xFFF5F5F5),
    Color? leftBorder,
    TextStyle? textStyle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: leftBorder != null
            ? Border(left: BorderSide(color: leftBorder, width: 4))
            : null,
      ),
      child: Text(
        text,
        style: textStyle ?? const TextStyle(fontSize: 13, height: 1.6),
      ),
    );
  }

  String escapeHtml(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String getString(
    Map<String, dynamic> data,
    String section,
    String key, [
    String fallback = '',
  ]) {
    if (section.isEmpty) return pStr(data[key], fallback);
    final s = pMap(data[section]);
    return pStr(s[key], fallback);
  }

  List<dynamic> getList(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is List) return v;
    return const [];
  }

  List<String> getSkills(Map<String, dynamic> data) {
    return pSkills(data['skills']);
  }

  String getLocation(Map<String, dynamic> data) {
    return pLocation(data);
  }

  // ============================================================
  // PDF HELPERS — shared by all PDF layouts
  // ============================================================

  /// Hex string → PdfColor (e.g. "#1E3A8A" or "1E3A8A")
  PdfColor pdfColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    try {
      return PdfColor.fromInt(int.parse(h, radix: 16));
    } catch (_) {
      return PdfColors.blueGrey;
    }
  }

  String pdfStr(dynamic v, [String fb = '']) {
    if (v == null) return fb;
    final s = v.toString().trim();
    return s.isEmpty ? fb : s;
  }

  /// ✅ FIXED: Sanitize Unicode chars that Helvetica font can't render.
  /// Replaces • ▸ — etc. with plain ASCII equivalents.
  String pdfSafe(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll('•', '-')
        .replaceAll('▸', '>')
        .replaceAll('▪', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...')
        .replaceAll('"', '"')
        .replaceAll('"', '"')
        .replaceAll("'", "'")
        .replaceAll("'", "'");
  }

  Map<String, dynamic> pdfMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> pdfList(dynamic v) {
    if (v is List) return v.map((e) => pdfMap(e)).toList();
    return <Map<String, dynamic>>[];
  }

  List<String> pdfSkills(dynamic skillsData) {
    final map = pdfMap(skillsData);
    final all = map['all'];
    if (all is List) {
      return all
          .map((s) => pdfStr(pdfMap(s)['name'] ?? s))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  List<String> pdfTools(Map<String, dynamic> data, [int limit = 15]) {
    final set = <String>{};
    final t = data['tools'];
    if (t is List) {
      for (final x in t) {
        final s = x.toString().trim();
        if (s.isNotEmpty) set.add(s);
      }
    }
    for (final proj in pdfList(data['projects'])) {
      final tech = proj['technologies'];
      if (tech is List) {
        for (final x in tech) {
          final s = x.toString().trim();
          if (s.isNotEmpty) set.add(s);
        }
      }
    }
    return set.take(limit).toList();
  }

  String pdfDesignation(Map<String, dynamic> data) {
    final exp = pdfList(data['experience']);
    for (final e in exp) {
      final isCurrent = e['is_current'] == true ||
          pdfStr(e['end_date']).isEmpty ||
          pdfStr(e['end_date']).toLowerCase() == 'present';
      if (isCurrent) return pdfStr(e['role']);
    }
    if (exp.isNotEmpty) return pdfStr(exp.first['role']);
    return '';
  }

  String pdfLocation(Map<String, dynamic> data) {
    final c = pdfMap(data['contact_info']);
    final addr = pdfMap(c['current_address']);
    final city = pdfStr(addr['city']);
    final state = pdfStr(addr['state']);
    final parts = <String>[];
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty && state != city) parts.add(state);
    if (parts.isNotEmpty) return parts.join(', ');
    return pdfStr(c['location'], 'India');
  }

  // ------------------------------------------------------------
  // PDF section titles
  // ------------------------------------------------------------
  pw.Widget pdfSideTitle(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
      child: pw.Text(
        pdfSafe(text),
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }

  pw.Widget pdfSideTitleColored(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(text),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: color,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Container(height: 1.5, width: 30, color: color),
        ],
      ),
    );
  }

  // ✅ FIXED: Sanitizes Unicode bullet characters so Helvetica can render
  pw.Widget pdfSideItem(String text, PdfColor color) {
    final safe = pdfSafe(text);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(safe, style: pw.TextStyle(fontSize: 8, color: color)),
    );
  }

  pw.Widget pdfMainTitle(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6, top: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(text),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Container(height: 1.5, width: 40, color: color),
        ],
      ),
    );
  }

  pw.Widget pdfMainTitleTech(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6, top: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(text),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(height: 0.5, color: PdfColors.grey600),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PDF experience blocks
  // ------------------------------------------------------------
  pw.Widget pdfExpBlockClassic(Map<String, dynamic> e, PdfColor accent) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(pdfStr(e['role'], 'Role')),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            pdfSafe(
                '${pdfStr(e['company'])} | ${pdfStr(e['start_date'])} - ${pdfStr(e['end_date'], 'Present')}'),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          if (pdfStr(e['description']).isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              pdfSafe(pdfStr(e['description'])),
              style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget pdfExpBlockTech(
    Map<String, dynamic> e,
    PdfColor accent,
    PdfColor cardBg,
    PdfColor greyText,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        color: cardBg,
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(pdfStr(e['role'], 'Role')),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            pdfSafe(
                '${pdfStr(e['company'])} | ${pdfStr(e['start_date'])} - ${pdfStr(e['end_date'], 'Present')}'),
            style: pw.TextStyle(fontSize: 8, color: greyText),
          ),
          if (pdfStr(e['description']).isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              pdfSafe(pdfStr(e['description'])),
              style: pw.TextStyle(
                fontSize: 9,
                lineSpacing: 1.5,
                color: PdfColors.grey300,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget pdfExpBlockExecutive(
    Map<String, dynamic> e,
    PdfColor gold,
    PdfColor cream,
    PdfColor dark,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        color: cream,
        border: pw.Border(left: pw.BorderSide(color: gold, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(pdfStr(e['role'], 'Role')),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: dark,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            pdfSafe(
                '${pdfStr(e['company'])} | ${pdfStr(e['start_date'])} - ${pdfStr(e['end_date'], 'Present')}'),
            style: pw.TextStyle(
              fontSize: 8,
              color: dark,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          if (pdfStr(e['description']).isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              pdfSafe(pdfStr(e['description'])),
              style: pw.TextStyle(fontSize: 9, lineSpacing: 1.5, color: dark),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PDF education & project blocks
  // ------------------------------------------------------------
  pw.Widget pdfEduBlockClassic(Map<String, dynamic> e, PdfColor accent) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(pdfStr(e['degree'], pdfStr(e['level'], 'Education'))),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            pdfSafe(
              [
                pdfStr(e['institute']),
                pdfStr(e['year_of_passing'] ?? e['year']),
                pdfStr(e['cgpa_percentage'] ?? e['result']),
              ].where((x) => x.isNotEmpty).join(' | '),
            ),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget pdfProjBlockClassic(Map<String, dynamic> p, PdfColor accent) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(pdfStr(p['title'], 'Project')),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          if (pdfStr(p['description']).isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              pdfSafe(pdfStr(p['description'])),
              style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget pdfProjBlockTech(
    Map<String, dynamic> p,
    PdfColor accent,
    PdfColor cardBg,
    PdfColor greyText,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        color: cardBg,
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            pdfSafe(pdfStr(p['title'], 'Project')),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          if (pdfStr(p['description']).isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              pdfSafe(pdfStr(p['description'])),
              style: pw.TextStyle(
                fontSize: 9,
                lineSpacing: 1.5,
                color: PdfColors.grey300,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Government helpers
  // ------------------------------------------------------------
  pw.Widget pdfGovSectionTitle(String t, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
      color: color,
      child: pw.Text(
        pdfSafe(t),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }

  pw.Widget pdfGovInfoTable(
    List<List<String>> rows,
    PdfColor border,
    PdfColor light,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border, width: 0.5),
      ),
      child: pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(1.2),
          1: pw.FlexColumnWidth(2),
        },
        border: pw.TableBorder.all(color: border, width: 0.5),
        children: rows.map((r) {
          return pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                color: light,
                child: pw.Text(
                  pdfSafe(r[0]),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(pdfSafe(r[1]),
                    style: const pw.TextStyle(fontSize: 9)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}