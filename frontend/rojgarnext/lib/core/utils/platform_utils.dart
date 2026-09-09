// lib/core/utils/platform_utils.dart
// ✅ COMPLETE PLATFORM UTILITIES

import 'package:flutter/foundation.dart';
import 'dart:io';

class PlatformUtils {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWindows || isMacOS || isLinux;
  
  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  static bool get supportsBiometric => isAndroid || isIOS;
  static bool get supportsPushNotifications => isAndroid || isIOS;
  static bool get supportsCamera => isAndroid || isIOS;
  static bool get supportsGPS => !isWeb;
  static bool get supportsNativeFilePicker => !isWeb;
  
  static String getFilePickerErrorMessage(dynamic error) {
    if (isWeb) {
      return 'File selection is not supported in this browser. Please try again.';
    }
    return 'Error selecting file: $error';
  }

  static bool isFilePickerSupported() {
    return true;
  }

  static String getApiBaseUrl() {
    if (kReleaseMode) {
      return "https://www.rojgarnext.com/api/v1";
    }
    
    if (isWeb) {
      return "http://localhost:8000/api/v1";
    }
    
    if (isAndroid) {
      return "http://10.0.2.2:8000/api/v1";
    }
    
    if (isIOS) {
      return "http://localhost:8000/api/v1";
    }
    
    return "http://localhost:8000/api/v1";
  }

  static String getWebSocketUrl() {
    if (kReleaseMode) {
      return "wss://www.rojgarnext.com/ws/notification/ws";
    }
    
    if (isWeb) {
      return "ws://localhost:8000/notification/ws";
    }
    
    if (isAndroid) {
      return "ws://10.0.2.2:8000/notification/ws";
    }
    
    return "ws://localhost:8000/notification/ws";
  }

  static bool get isDevelopment => !kReleaseMode;
  static bool get isProduction => kReleaseMode;
}