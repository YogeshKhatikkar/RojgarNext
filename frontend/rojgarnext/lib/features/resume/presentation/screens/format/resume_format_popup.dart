// lib/features/resume/presentation/screens/format/resume_format_popup.dart
// ✅ FIXED: Print / Download / Share now correctly use the CURRENT format
// ✅ No more stuck spinner — proper state reset on error
// ✅ Filename includes format name so you can verify the correct format is exported

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/resume/services/resume_pdf_service.dart';
import 'resume_format_base.dart';

class ResumeFormatPopup extends StatefulWidget {
  final ResumeFormatBase format;
  final Map<String, dynamic> resumeData;
  final VoidCallback? onClose;

  const ResumeFormatPopup({
    super.key,
    required this.format,
    required this.resumeData,
    this.onClose,
  });

  @override
  State<ResumeFormatPopup> createState() => _ResumeFormatPopupState();
}

class _ResumeFormatPopupState extends State<ResumeFormatPopup> {
  bool _isGenerating = false;

  @override
  void dispose() {
    widget.onClose?.call();
    super.dispose();
  }

  String get _nameBase {
    final u = widget.resumeData['user_info'];
    final name =
        (u is Map ? (u['full_name'] ?? '') : '').toString().trim();
    if (name.isEmpty) return 'Resume';
    return name.replaceAll(RegExp(r'[^\w]'), '_');
  }

  /// ✅ Always use the CURRENT format's styleKey + color
  String get _currentStyleKey => widget.format.styleKey;
  String get _currentColor => widget.format.color;

  Future<void> _handleDownload() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    debugPrint('📥 DOWNLOAD clicked → format=${widget.format.id} '
        'styleKey=$_currentStyleKey color=$_currentColor');

    try {
      await ResumePdfService.download(
        fileNameBase: _nameBase,
        data: widget.resumeData,
        styleKey: _currentStyleKey,
        colorHex: _currentColor,
      );
      if (mounted) {
        showMessage(context,
            "✅ ${widget.format.name} resume downloaded successfully");
      }
    } catch (e) {
      debugPrint('❌ Download failed: $e');
      if (mounted) {
        showMessage(context, "❌ Download failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handlePrint() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    debugPrint('🖨️ PRINT clicked → format=${widget.format.id} '
        'styleKey=$_currentStyleKey color=$_currentColor');

    try {
      await ResumePdfService.print(
        data: widget.resumeData,
        styleKey: _currentStyleKey,
        colorHex: _currentColor,
      );
      if (mounted) {
        showMessage(context,
            "🖨️ Print dialog opened for ${widget.format.name}");
      }
    } catch (e) {
      debugPrint('❌ Print failed: $e');
      if (mounted) {
        showMessage(context, "❌ Print failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleShare() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    debugPrint('📤 SHARE clicked → format=${widget.format.id} '
        'styleKey=$_currentStyleKey color=$_currentColor');

    try {
      await ResumePdfService.share(
        fileNameBase: _nameBase,
        data: widget.resumeData,
        styleKey: _currentStyleKey,
        colorHex: _currentColor,
      );
      if (mounted) {
        showMessage(context,
            "📤 ${widget.format.name} resume ready to share");
      }
    } catch (e) {
      debugPrint('❌ Share failed: $e');
      if (mounted) {
        showMessage(context, "❌ Share failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 600;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: size.width * 0.95,
        height: size.height * 0.92,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: isNarrow
                  ? _buildNarrowHeader()
                  : _buildWideHeader(),
            ),
            const Divider(height: 1),
            // PREVIEW
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: widget.format.buildPreview(
                      context,
                      widget.resumeData,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WIDE HEADER (desktop / tablet)
  // ============================================================
  Widget _buildWideHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Text(widget.format.icon, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.format.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text(widget.format.description,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        // PRINT
        Tooltip(
          message: "Print this ${widget.format.name}",
          child: IconButton(
            icon: const Icon(Icons.print_outlined,
                color: Colors.blueAccent, size: 24),
            onPressed: _isGenerating ? null : _handlePrint,
          ),
        ),
        // DOWNLOAD PDF
        Tooltip(
          message: "Download this ${widget.format.name}",
          child: IconButton(
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded,
                    color: Colors.green, size: 26),
            onPressed: _isGenerating ? null : _handleDownload,
          ),
        ),
        // SHARE
        Tooltip(
          message: "Share this ${widget.format.name}",
          child: IconButton(
            icon: const Icon(Icons.share_outlined,
                color: Colors.purple, size: 24),
            onPressed: _isGenerating ? null : _handleShare,
          ),
        ),
        // CLOSE
        IconButton(
          icon: const Icon(Icons.close, size: 24),
          onPressed: () => Navigator.pop(context),
          tooltip: "Close",
        ),
      ],
    );
  }

  // ============================================================
  // NARROW HEADER (phone) — wraps buttons to second row
  // ============================================================
  Widget _buildNarrowHeader() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(widget.format.icon,
                  style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.format.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(widget.format.description,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 22),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionChip(
              icon: Icons.print_outlined,
              label: "Print",
              color: Colors.blueAccent,
              onTap: _isGenerating ? null : _handlePrint,
            ),
            _actionChip(
              icon: Icons.download_rounded,
              label: "Download",
              color: Colors.green,
              onTap: _isGenerating ? null : _handleDownload,
              loading: _isGenerating,
            ),
            _actionChip(
              icon: Icons.share_outlined,
              label: "Share",
              color: Colors.purple,
              onTap: _isGenerating ? null : _handleShare,
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}