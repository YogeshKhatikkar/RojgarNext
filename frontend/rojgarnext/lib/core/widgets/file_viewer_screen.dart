// lib/core/widgets/file_viewer_screen.dart
// ✅ COMPLETE FIXED VERSION - Supports Images + Opens PDF in Browser

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class FileViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? downloadUrl;
  final String? fileType;
  final String? fileName;

  const FileViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.downloadUrl,
    this.fileType,
    this.fileName,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  final TransformationController _imageController = TransformationController();

  // State
  bool _isLoading = true;
  String? _errorMessage;
  double _zoomScale = 1.0;

  // Detected properties
  String _effectiveUrl = '';
  bool _isWeb = false;
  bool _isImageSupported = false;
  bool _isPdf = false;

  @override
  void initState() {
    super.initState();
    _isWeb = kIsWeb;
    _initializeViewer();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================

  void _initializeViewer() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _effectiveUrl = widget.url;
    if (!_effectiveUrl.startsWith('http') &&
        !_effectiveUrl.startsWith('file')) {
      _effectiveUrl = 'https://$_effectiveUrl';
    }

    _detectFileType();

    debugPrint('📄 FILE VIEWER INITIALIZED');
    debugPrint('   URL: $_effectiveUrl');
    debugPrint('   Is Image Supported: $_isImageSupported');
    debugPrint('   Is PDF: $_isPdf');
    debugPrint('   Platform: ${_isWeb ? "Web" : "Mobile"}');

    if (_isImageSupported) {
      setState(() => _isLoading = false);
    } else if (_isPdf) {
      // For PDFs, we don't need to load anything - just show the viewer
      setState(() => _isLoading = false);
    } else {
      setState(() {
        _errorMessage =
            '⚠️ Unsupported file format.\n\nOnly JPG, JPEG, PNG images and PDF files are supported.\n\nTap "Open in Browser" to view this file.';
        _isLoading = false;
      });
    }
  }

  void _detectFileType() {
    final urlLower = _effectiveUrl.toLowerCase();
    final path = _effectiveUrl.split('?').first;

    // Check for PDF
    _isPdf = path.endsWith('.pdf') ||
        urlLower.contains('.pdf') ||
        (urlLower.contains('cloudinary.com') &&
            (urlLower.contains('/raw/upload/') ||
                urlLower.contains('fl_attachment') ||
                urlLower.contains('.pdf'))) ||
        (widget.fileType?.toLowerCase() == 'pdf');

    // Check if supported image (JPG, JPEG, PNG only)
    _isImageSupported = !_isPdf &&
        (path.endsWith('.jpg') ||
            path.endsWith('.jpeg') ||
            path.endsWith('.png'));

    // Also check for Cloudinary image paths
    if (!_isImageSupported &&
        !_isPdf &&
        urlLower.contains('cloudinary.com') &&
        (urlLower.contains('/image/upload/') ||
            urlLower.contains('/image/authenticated/'))) {
      _isImageSupported = true;
    }

    // Override with widget.fileType
    if (widget.fileType != null) {
      final type = widget.fileType!.toLowerCase();
      if (type == 'image') {
        _isImageSupported = true;
        _isPdf = false;
      } else if (type == 'pdf') {
        _isPdf = true;
        _isImageSupported = false;
      }
    }
  }

  // ==================== PDF VIEWER ====================

  Future<void> _viewPdf() async {
    try {
      final uri = Uri.parse(_effectiveUrl);

      debugPrint('📄 Opening PDF: $_effectiveUrl');

      // On Web: Open in new tab
      if (_isWeb) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
        _showSnackBar("PDF opened in new browser tab");
        return;
      }

      // On Mobile: Try to open with external app (PDF viewer)
      // Check if URL can be launched
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar("Opening PDF with external PDF viewer...");
      } else {
        // Fallback: Show dialog with options
        _showPdfOptionsDialog();
      }
    } catch (e) {
      debugPrint('❌ Error opening PDF: $e');
      if (mounted) {
        _showPdfOptionsDialog();
      }
    }
  }

  void _showPdfOptionsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red),
            SizedBox(width: 10),
            Text("PDF Document"),
          ],
        ),
        content: const Text(
          "This is a PDF file. How would you like to open it?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _copyLinkToClipboard();
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text("Copy Link"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openInBrowser();
            },
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text("Open in Browser"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== USER ACTIONS ====================

  Future<void> _openInBrowser() async {
    if (!mounted) return;
    try {
      final uri = Uri.parse(_effectiveUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar("Opening in browser...");
      } else {
        _showSnackBar("Cannot open URL", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error opening URL: $e", isError: true);
    }
  }

  void _copyLinkToClipboard() {
    Clipboard.setData(ClipboardData(text: _effectiveUrl));
    _showSnackBar("Link copied to clipboard!");
  }

  void _refreshViewer() {
    _initializeViewer();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== ZOOM CONTROLS FOR IMAGES ====================

  void _zoomIn() {
    setState(() {
      _zoomScale = (_zoomScale + 0.25).clamp(0.5, 3.0);
      _imageController.value = Matrix4.identity()
        ..setEntry(0, 0, _zoomScale)
        ..setEntry(1, 1, _zoomScale);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomScale = (_zoomScale - 0.25).clamp(0.5, 3.0);
      _imageController.value = Matrix4.identity()
        ..setEntry(0, 0, _zoomScale)
        ..setEntry(1, 1, _zoomScale);
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomScale = 1.0;
      _imageController.value = Matrix4.identity();
    });
  }

  // ==================== BUILD METHODS ====================

  Widget _buildImageViewer() {
    return InteractiveViewer(
      transformationController: _imageController,
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: _effectiveUrl,
          placeholder: (_, __) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Loading image..."),
              ],
            ),
          ),
          errorWidget: (_, __, ___) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("Failed to load image"),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _openInBrowser,
                  child: const Text("Open in Browser"),
                ),
              ],
            ),
          ),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade200,
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              size: 70,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.description,
                  size: 32,
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                const Text(
                  "📄 PDF Document",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isWeb
                      ? "Click below to open PDF in a new browser tab"
                      : "Click below to open PDF with your device's PDF viewer",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _viewPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 20),
                  label: const Text('Open PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 140,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _copyLinkToClipboard,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            height: 44,
            child: TextButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Open in Browser'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber,
              size: 60,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 32, color: Colors.orange),
                const SizedBox(height: 12),
                const Text(
                  "⚠️ Unsupported File Format",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ??
                      "Only JPG, JPEG, PNG images and PDF files are supported.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  label: const Text('Open'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _copyLinkToClipboard,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            label: const Text("Open in Browser"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== MAIN BUILD ====================

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_errorMessage != null) {
      content = _buildErrorView();
    } else if (_isImageSupported) {
      content = _buildImageViewer();
    } else if (_isPdf) {
      content = _buildPdfViewer();
    } else {
      content = _buildUnsupportedViewer();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        centerTitle: false,
        actions: [
          // Zoom controls (only for images)
          if (_isImageSupported && !_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _zoomOut,
              tooltip: "Zoom Out",
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: _zoomIn,
              tooltip: "Zoom In",
            ),
            IconButton(
              icon: const Icon(Icons.aspect_ratio),
              onPressed: _resetZoom,
              tooltip: "Reset Zoom",
            ),
          ],
          // Share/Copy button for PDFs
          if (_isPdf && !_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyLinkToClipboard,
              tooltip: "Copy Link",
            ),
          ],
          // Open in Browser button (always available)
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: "Open in Browser",
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshViewer,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: content,
    );
  }
}