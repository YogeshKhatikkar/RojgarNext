// lib/core/network/dio_client.dart
// ✅ COMPLETE WITH ERROR HANDLING

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../storage/secure_storage.dart';

class DioClient {
  static Dio? _dio;
  static bool _isInitialized = false;

  static Dio get dio {
    if (_dio == null || !_isInitialized) {
      _init();
    }
    return _dio!;
  }

  static void _init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );

    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          if (kDebugMode) {
            debugPrint("🌐 REQUEST: ${options.method} ${options.uri}");
            debugPrint("📦 Headers: ${options.headers}");
            if (options.data != null) {
              debugPrint("📦 Body: ${options.data}");
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint("✅ RESPONSE [${response.statusCode}]: ${response.data}");
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (kDebugMode) {
            debugPrint("❌ DIO ERROR: ${e.type}");
            debugPrint("   Message: ${e.message}");
            debugPrint("   Response: ${e.response?.data}");
          }

          if (e.response?.statusCode == 401) {
            await SecureStorage.clear();
          }

          final errorMessage = extractErrorMessage(e);

          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: errorMessage,
              response: e.response,
              type: e.type,
            ),
          );
        },
      ),
    );

    _isInitialized = true;
  }

  static String extractErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      return "Cannot connect to server at ${ApiConfig.baseUrl}\n\n"
          "Please ensure:\n"
          "1. Backend is running on port 8000\n"
          "2. Run: cd backend/rojgarnext && uvicorn app.main:app --reload --port 8000\n"
          "3. Check firewall settings\n"
          "4. If on web, ensure CORS is configured";
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return "Connection timeout. Backend might not be running on port 8000.";
    }

    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('message')) {
          return data['message'].toString();
        }
        if (data.containsKey('detail')) {
          final detail = data['detail'];
          if (detail is List) {
            return detail.map((e) => e.toString()).join('\n');
          }
          return detail.toString();
        }
        if (data.containsKey('error')) {
          return data['error'].toString();
        }
        return data.toString();
      } else if (data is String) {
        return data;
      }
    }

    if (e.response?.statusCode == 404) {
      return "API endpoint not found (404). Please check if the backend is running correctly.";
    }

    if (e.response?.statusCode == 500) {
      return "Internal server error (500). Please check backend logs.";
    }

    return e.message ?? "Network error occurred. Please try again.";
  }
}

void initDioClient() {
  DioClient.dio;
}