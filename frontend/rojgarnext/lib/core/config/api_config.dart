// lib/core/config/api_config.dart
// ✅ PLATFORM-AWARE API CONFIGURATION

import 'package:flutter/foundation.dart';
import '../utils/platform_utils.dart';

class ApiConfig {
  static String get baseUrl {
    debugPrint("🌐 Platform: ${PlatformUtils.platformName}");
    debugPrint("📱 Mode: ${kReleaseMode ? 'Release' : 'Development'}");

    if (kReleaseMode) {
      return "https://www.rojgarnext.com/api/v1";
    }

    // Development mode with platform-specific URLs
    if (PlatformUtils.isWeb) {
      return "http://localhost:8000/api/v1";
    }

    if (PlatformUtils.isAndroid) {
      return "http://10.0.2.2:8000/api/v1";
    }

    if (PlatformUtils.isIOS) {
      return "http://localhost:8000/api/v1";
    }

    if (PlatformUtils.isDesktop) {
      return "http://localhost:8000/api/v1";
    }

    return "http://localhost:8000/api/v1";
  }

  static String get webSocketUrl {
    if (kReleaseMode) {
      return "wss://www.rojgarnext.com/ws/notification/ws";
    }

    if (PlatformUtils.isWeb) {
      return "ws://localhost:8000/notification/ws";
    }

    if (PlatformUtils.isAndroid) {
      return "ws://10.0.2.2:8000/notification/ws";
    }

    return "ws://localhost:8000/notification/ws";
  }

  // ✅ PRODUCTION UPI ID - Read from .env via backend
  static String get upiId {
    if (kReleaseMode) {
      return "your-business-upi@ybl"; // Replace with your actual UPI ID
    }
    return "7869986602@ybl"; // Test UPI ID
  }

  static bool get isDevelopment => !kReleaseMode;
  static bool get isProduction => kReleaseMode;
}