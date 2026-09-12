// lib/features/resume/presentation/screens/format/resume_format_popup.dart
// ============================================================================
// ✅ SINGLE FILE — Popup shell only. NO format-specific styling here.
// ✅ Format styles live in formats/*.dart — इस file को छूने की ज़रूरत नहीं
// ✅ Web + Android + iOS पर identical rendering (native Flutter widgets)
// ✅ PDF export + Refresh + Loading + Error states
// ✅ Only "Download PDF" button (Copy HTML removed)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'resume_format_base.dart';

// ============================================================================
// POPUP WIDGET
// ============================================================================
class ResumeFormatPopup extends StatefulWidget {
  final ResumeFormatBase format;
  final Map<String, dynamic> resumeData;
  final VoidCallback onClose;

  const ResumeFormatPopup({
    super.key,
    required this.format,
    required this.resumeData,
    required this.onClose,
  });

  @override
  State<ResumeFormatPopup> createState() => _ResumeFormatPopupState();
}

// ============================================================================
// STATE — NO format-specific logic here!
// ============================================================================
class _ResumeFormatPopupState extends State<ResumeFormatPopup> {
  bool _isLoading = true;
  bool _isExporting = false;
  String? _htmlContent;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    try {
      _htmlContent = widget.format.generateHtml(widget.resumeData);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error: $e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _refresh() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _prepare();
  }

  // ==========================================================================
  // PDF EXPORT — platform independent
  // ==========================================================================
  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final pdf = await _buildPdf();
      final bytes = await pdf.save();
      final safe =
          widget.format.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final fileName = 'Resume_${safe.isEmpty ? "Format" : safe}.pdf';
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF ready!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<pw.Document> _buildPdf() async {
    final pdf = pw.Document();
    final data = widget.resumeData;
    final u = _m(data['user_info']);
    final c = _m(data['contact_info']);
    final addr = _m(c['current_address']);
    final name = _s(u['full_name'], 'User');
    final email = _s(c['email']);
    final phone = _s(c['phone']);
    final city = _s(addr['city']);
    final state = _s(addr['state']);
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');
    final summary = _s(data['professional_summary']);
    final objective = _s(data['career_objective']);
    final edu = _l(data['education']);
    final exp = _l(data['experience']);
    final skills = _skills(data['skills']);
    final certs = _l(data['certifications']);
    final projects = _l(data['projects']);
    final langs = _l(data['languages']);

    PdfColor primary = PdfColors.blue900;
    try {
      final hex = widget.format.color.replaceAll('#', '');
      primary = PdfColor.fromHex(hex.length == 6 ? 'FF$hex' : hex);
    } catch (_) {
      primary = PdfColors.blue900;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: primary,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Wrap(
                  spacing: 14,
                  children: [
                    if (email.isNotEmpty)
                      pw.Text('📧 $email',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.white)),
                    if (phone.isNotEmpty)
                      pw.Text('📞 $phone',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.white)),
                    if (location.isNotEmpty)
                      pw.Text('📍 $location',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.white)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          if (summary.isNotEmpty) ...[
            _pdfTitle('Professional Summary', primary),
            pw.Text(summary,
                style: const pw.TextStyle(fontSize: 11, height: 1.4)),
            pw.SizedBox(height: 12),
          ],
          if (exp.isNotEmpty) ...[
            _pdfTitle('Work Experience', primary),
            ...exp.map((e) {
              final x = _m(e);
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_s(x['role'], 'Role'),
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(_s(x['company'], 'Company'),
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(
                      '${_s(x['start_date'])} - ${_s(x['end_date'], 'Present')}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600),
                    ),
                    if (_s(x['description']).isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(_s(x['description']),
                            style: const pw.TextStyle(
                                fontSize: 10, height: 1.3)),
                      ),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 8),
          ],
          if (edu.isNotEmpty) ...[
            _pdfTitle('Education', primary),
            ...edu.map((e) {
              final x = _m(e);
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_s(x['degree'], 'Degree'),
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(_s(x['institute'], 'Institute'),
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      'Year: ${_s(x['year_of_passing'])}'
                      '${_s(x['cgpa_percentage']).isNotEmpty ? "  |  ${_s(x['result_type'], "Score")}: ${_s(x['cgpa_percentage'])}" : ""}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 8),
          ],
          if (skills.isNotEmpty) ...[
            _pdfTitle('Skills', primary),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: skills
                  .map((s) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Text(s,
                            style: const pw.TextStyle(fontSize: 10)),
                      ))
                  .toList(),
            ),
            pw.SizedBox(height: 12),
          ],
          if (certs.isNotEmpty) ...[
            _pdfTitle('Certifications', primary),
            ...certs.map((c) {
              final x = _m(c);
              final t = [_s(x['name']), _s(x['issuer']), _s(x['year'])]
                  .where((s) => s.isNotEmpty)
                  .join(' - ');
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text('• $t',
                    style: const pw.TextStyle(fontSize: 10)),
              );
            }),
            pw.SizedBox(height: 10),
          ],
          if (projects.isNotEmpty) ...[
            _pdfTitle('Projects', primary),
            ...projects.map((p) {
              final x = _m(p);
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_s(x['title'], 'Project'),
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold)),
                    if (_s(x['description']).isNotEmpty)
                      pw.Text(_s(x['description']),
                          style: const pw.TextStyle(
                              fontSize: 10, height: 1.3)),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 8),
          ],
          if (langs.isNotEmpty) ...[
            _pdfTitle('Languages', primary),
            pw.Text(
              langs
                  .map((l) {
                    final x = _m(l);
                    final n = _s(x['name']);
                    final p = _s(x['proficiency']);
                    return p.isNotEmpty ? '$n ($p)' : n;
                  })
                  .join(', '),
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 8),
          ],
          if (objective.isNotEmpty) ...[
            _pdfTitle('Career Objective', primary),
            pw.Text(objective,
                style: const pw.TextStyle(fontSize: 11, height: 1.4)),
          ],
        ],
      ),
    );
    return pdf;
  }

  pw.Widget _pdfTitle(String title, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6, top: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
          ),
          pw.Container(
              height: 1,
              color: PdfColors.blue200,
              margin: const pw.EdgeInsets.only(top: 3)),
        ],
      ),
    );
  }

  // ==========================================================================
  // DATA HELPERS (local, minimal)
  // ==========================================================================
  Map<String, dynamic> _m(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  List<dynamic> _l(dynamic v) => v is List ? v : [];

  String _s(dynamic v, [String fb = '']) {
    if (v == null) return fb;
    final t = v.toString();
    return t.isEmpty ? fb : t;
  }

  List<String> _skills(dynamic v) {
    if (v is! Map) return [];
    final all = v['all'];
    if (all is! List) return [];
    return all
        .map((e) => e is Map ? _s(e['name']) : e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final small = size.width < 500;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.all(small ? 8 : 16),
      child: Container(
        width: size.width * (small ? 0.98 : 0.92),
        height: size.height * 0.9,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hex = widget.format.color.replaceAll('#', '');
    Color color;
    try {
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      color = const Color(0xFF6C63FF);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                Text(widget.format.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.format.name,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  kIsWeb
                      ? '🌐 Live Preview (Web)'
                      : '📱 Live Preview (Mobile)',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (widget.format.badgeText.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.format.badgeText,
                style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: _refresh,
            tooltip: 'Refresh',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
            onPressed: () {
              widget.onClose();
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  _parseColor(widget.format.color),
                ),
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 20),
            Text('Generating ${widget.format.name}...',
                style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 6),
            const Text('Please wait while we prepare your resume',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ ONLY THIS LINE CHANGES WHEN A FORMAT'S STYLE CHANGES
    // The format file (classic/modern/tech/executive/government/fresher)
    // owns all its colors, gradients, layouts, and shadows.
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: widget.format.buildPreview(context, widget.resumeData),
        ),
      ),
    );
  }

  // ==========================================================================
  // FOOTER — only "Download PDF" (full width)
  // ==========================================================================
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isExporting ? null : _exportPdf,
          icon: _isExporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.picture_as_pdf, size: 20),
          label: Text(
            _isExporting ? 'Exporting...' : 'Download PDF',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final c = hex.replaceAll('#', '');
      return Color(int.parse('FF$c', radix: 16));
    } catch (_) {
      return const Color(0xFF6C63FF);
    }
  }
}