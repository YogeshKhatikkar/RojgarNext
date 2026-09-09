// lib/core/widgets/platform_webview.dart
// ✅ COMPLETE WEBVIEW - Works on All Platforms

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
// ✅ IMPORTANT: Conditional import for Web-specific plugin.
import 'package:webview_flutter_web/webview_flutter_web.dart'
    if (dart.library.html) 'package:webview_flutter_web/webview_flutter_web.dart'
    as web;
import '../utils/platform_utils.dart';

class PlatformWebView extends StatefulWidget {
  final String htmlContent;
  final String? url;
  final String title;
  final bool showAppBar;

  const PlatformWebView({
    super.key,
    required this.htmlContent,
    this.url,
    this.title = 'Preview',
    this.showAppBar = true,
  });

  @override
  State<PlatformWebView> createState() => _PlatformWebViewState();
}

class _PlatformWebViewState extends State<PlatformWebView> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ✅ WEB PLATFORM KE LIYE REGISTER (Sirf Web par chalega)
    if (kIsWeb) {
      try {
        // ignore: invalid_use_of_protected_member
        WebViewPlatform.instance ??= web.WebWebViewPlatform();
        debugPrint('✅ WebView platform registered for web');
      } catch (e) {
        debugPrint('⚠️ WebView platform registration error: $e');
      }
    }
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController();

    // Platform-specific configuration
    if (PlatformUtils.isWeb) {
      // Web platform - load via URI
      _controller.loadRequest(
        Uri.parse(
          'data:text/html;charset=utf-8,${Uri.encodeComponent(widget.htmlContent)}',
        ),
      );
    } else {
      // Mobile/Desktop
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFFFFFFF))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
            onPageStarted: (String url) {
              if (mounted) {
                setState(() => _isLoading = true);
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('❌ WebView error: ${error.description}');
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
          ),
        )
        ..loadHtmlString(widget.htmlContent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    if (PlatformUtils.isWeb) {
                      _controller.reload();
                    } else {
                      _controller.loadHtmlString(widget.htmlContent);
                    }
                  },
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}