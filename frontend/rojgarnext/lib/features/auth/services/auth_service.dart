// lib/features/auth/services/auth_service.dart
// ✅ COMPLETE FIXED VERSION

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';

class AuthService {
  static const String _auth = "/auth";

  static Dio get _dio => DioClient.dio;

  static void _log(String msg) {
    if (kDebugMode) debugPrint(msg);
  }

  static String _err(DioException e) {
    String msg = DioClient.extractErrorMessage(e);
    if (msg.isEmpty) {
      msg = e.message ?? "Network error occurred";
    }
    _log("❌ AuthService: $msg");
    return msg;
  }

  static dynamic _unwrap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('data')) {
        return responseData['data'];
      }
    }
    return responseData;
  }

  // ================= REGISTER =================
  static Future<dynamic> register(
    Map<String, dynamic> data, {
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      final Map<String, dynamic> requestData = <String, dynamic>{
        'name': data['name'] ?? '',
        'email': data['email'] ?? '',
        'mobile': data['mobile'] ?? '',
        'password': data['password'] ?? '',
      };

      if (latitude != null) {
        requestData['latitude'] = latitude;
      }
      if (longitude != null) {
        requestData['longitude'] = longitude;
      }
      if (locationName != null && locationName.isNotEmpty) {
        requestData['location_name'] = locationName;
      }

      _log(
          "📤 Register: ${data['email']}, Location included: ${latitude != null}");
      final Response res =
          await _dio.post("$_auth/register", data: requestData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  // ================= LOGIN (Email + Password) =================
  static Future<Map<String, dynamic>> login(
    Map<String, dynamic> data, {
    double? latitude,
    double? longitude,
    String? locationName,
    bool forceLocationUpdate = true,
  }) async {
    try {
      final Map<String, dynamic> requestData = <String, dynamic>{
        'email': data['email'] ?? '',
        'password': data['password'] ?? '',
      };

      if (latitude != null) {
        requestData['latitude'] = latitude;
      }
      if (longitude != null) {
        requestData['longitude'] = longitude;
      }
      if (locationName != null && locationName.isNotEmpty) {
        requestData['location_name'] = locationName;
      }
      if (forceLocationUpdate) {
        requestData['force_location_update'] = true;
      }

      debugPrint("📤 Login request:");
      debugPrint("   Email: ${data['email']}");
      debugPrint("   Location: lat=$latitude, lng=$longitude");

      final Response res = await _dio.post("$_auth/login", data: requestData);
      final Map<String, dynamic> result =
          _unwrap(res.data) as Map<String, dynamic>;

      await SecureStorage.setToken(result["access_token"] ?? "");
      await SecureStorage.setRole(result["role"] ?? "user");
      await SecureStorage.setEmail(result['email']?.toString() ?? "");
      await SecureStorage.setMobile(result['mobile']?.toString() ?? "");
      await SecureStorage.setName(result['name']?.toString() ?? "");

      debugPrint("✅ Role saved: ${result["role"]}");
      debugPrint("✅ Name saved: ${result["name"]}");
      debugPrint("✅ Mobile saved: ${result["mobile"]}");

      return result;
    } on DioException catch (e) {
      final String msg = _err(e);
      throw msg.toLowerCase().contains("invalid") ||
              msg.toLowerCase().contains("password")
          ? "Invalid email or password"
          : msg;
    }
  }

  // ================= UPDATE LOCATION =================
  static Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    try {
      final Map<String, dynamic> requestData = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      };

      if (locationName != null && locationName.isNotEmpty) {
        requestData['location_name'] = locationName;
      }

      final Response res =
          await _dio.post("$_auth/update-location", data: requestData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  // ================= GET MY LOCATION =================
  static Future<Map<String, dynamic>> getMyLocation() async {
    try {
      final Response res = await _dio.get("$_auth/my-location");
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  // ================= MPIN LOGIN =================
  static Future<Map<String, dynamic>> loginPin(
      Map<String, dynamic> data) async {
    try {
      final Response res = await _dio.post("$_auth/login-pin", data: data);
      final Map<String, dynamic> result =
          _unwrap(res.data) as Map<String, dynamic>;

      final String email = result["email"]?.toString() ?? "";
      final String name = result["name"]?.toString() ?? "";
      final String mobile = result["mobile"]?.toString() ?? "";
      final String role = result["role"]?.toString() ?? "user";
      final String token = result["access_token"]?.toString() ?? "";

      debugPrint("✅ MPIN Login - Email to save: '$email'");
      debugPrint("✅ MPIN Login - Name to save: '$name'");
      debugPrint("✅ MPIN Login - Mobile to save: '$mobile'");

      await SecureStorage.setToken(token);
      await SecureStorage.setRole(role);
      await SecureStorage.setEmail(email);
      await SecureStorage.setName(name);
      await SecureStorage.setMobile(mobile);

      return result;
    } on DioException catch (e) {
      final String msg = _err(e);
      if (e.response?.data is Map) {
        final serverMsg =
            e.response!.data['message'] ?? e.response!.data['detail'];
        if (serverMsg is String && serverMsg.isNotEmpty) {
          throw serverMsg;
        }
      }
      throw msg.contains("Invalid") || msg.contains("PIN")
          ? "Invalid email or MPIN"
          : msg;
    }
  }

  // ================= MPIN SETUP - FIXED =================
  static Future<dynamic> setupMpin(Map<String, dynamic> data) async {
    try {
      final String email = data["email"]?.toString().trim() ?? "";

      if (!email.contains('@')) {
        debugPrint("❌ Invalid email format: '$email'");
        throw Exception("Please login again with email & password first");
      }

      final String pin = data["pin"]?.toString().trim() ?? "";

      if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
        throw Exception("PIN must be 6 digits");
      }

      final Map<String, dynamic> requestData = {
        "email": email,
        "pin": pin,
      };

      debugPrint("📤 Setting MPIN for email: ${requestData['email']}");
      debugPrint("   PIN length: ${requestData['pin'].length}");

      final Response res = await _dio.post("$_auth/set-pin", data: requestData);
      debugPrint("✅ MPIN setup response: ${res.data}");
      return _unwrap(res.data);
    } on DioException catch (e) {
      debugPrint("❌ MPIN setup error: ${e.response?.data}");
      throw _err(e);
    }
  }

  // ================= ENABLE BIOMETRIC - FIXED =================
  static Future<dynamic> enableBiometric(Map<String, dynamic> data) async {
    try {
      final String email = data["email"]?.toString().trim() ?? "";

      if (email.isEmpty || !email.contains('@')) {
        throw Exception("Invalid email");
      }

      // ✅ Ensure biometric_type is valid
      final String biometricType = data["biometric_type"] ?? "fingerprint";
      final allowedTypes = ["fingerprint", "face", "iris", "none"];
      final String validType = allowedTypes.contains(biometricType) 
          ? biometricType 
          : "fingerprint";

      final Map<String, dynamic> requestData = {
        "email": email,
        "device_info": data["device_info"] ?? "Flutter Device",
        "device_id": data["device_id"] ?? "",
        "biometric_type": validType,
      };

      debugPrint("📤 Enabling biometric for email: ${requestData['email']}");
      debugPrint("   Biometric Type: ${requestData['biometric_type']}");

      final Response res =
          await _dio.post("$_auth/enable-biometric", data: requestData);
      debugPrint("✅ Biometric enable response: ${res.data}");

      return _unwrap(res.data);
    } on DioException catch (e) {
      debugPrint("❌ Biometric enable error: ${e.response?.data}");
      throw _err(e);
    }
  }

  // ================= BIOMETRIC LOGIN - FIXED =================
  static Future<Map<String, dynamic>> biometricLogin(
      Map<String, dynamic> data) async {
    try {
      final String email = data["email"]?.toString().trim() ?? "";

      if (email.isEmpty || !email.contains('@')) {
        throw Exception("Invalid email");
      }

      final Map<String, dynamic> requestData = <String, dynamic>{
        "email": email,
        "device_info": data["device_info"] ?? "Flutter Device",
      };

      // Add location if provided
      if (data.containsKey('latitude') && data['latitude'] != null) {
        requestData['latitude'] = data['latitude'];
        requestData['longitude'] = data['longitude'];
        requestData['location_name'] = data['location_name'];
      }

      debugPrint("📤 Biometric login for email: ${requestData['email']}");

      final Response res =
          await _dio.post("$_auth/biometric-login", data: requestData);
      final Map<String, dynamic> result =
          _unwrap(res.data) as Map<String, dynamic>;

      final String token = result["access_token"]?.toString() ?? "";
      final String role = result["role"]?.toString() ?? "user";
      final String emailResult = result["email"]?.toString() ?? "";
      final String name = result["name"]?.toString() ?? "";
      final String mobile = result["mobile"]?.toString() ?? "";

      debugPrint("✅ Biometric Login - Email: '$emailResult'");
      debugPrint("✅ Biometric Login - Name: '$name'");
      debugPrint("✅ Biometric Login - Mobile: '$mobile'");

      await SecureStorage.setToken(token);
      await SecureStorage.setRole(role);
      await SecureStorage.setEmail(emailResult);
      await SecureStorage.setName(name);
      await SecureStorage.setMobile(mobile);

      return result;
    } on DioException catch (e) {
      final String msg = _err(e);
      if (e.response?.data is Map) {
        final serverMsg =
            e.response!.data['message'] ?? e.response!.data['detail'];
        if (serverMsg is String && serverMsg.isNotEmpty) {
          throw serverMsg;
        }
      }
      throw msg;
    }
  }

  // ================= OTHER METHODS =================
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final Response res = await _dio.post("$_auth/forgot-password",
          data: <String, dynamic>{"email": email});
      final Map<String, dynamic> body =
          _unwrap(res.data) as Map<String, dynamic>;
      final String mobile = body['mobile']?.toString() ?? '';
      if (mobile.isNotEmpty) {
        await SecureStorage.setMobile(mobile);
        _log("✅ Mobile saved: $mobile");
      }
      return body;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<dynamic> resendResetEmailOtp(String email) async {
    try {
      final Response res = await _dio.post("$_auth/resend-reset-email-otp",
          data: <String, dynamic>{"email": email});
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<dynamic> resendResetMobileOtp(String mobile) async {
    try {
      final Response res = await _dio.post("$_auth/resend-reset-mobile-otp",
          data: <String, dynamic>{"mobile": mobile});
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<dynamic> verifyResetEmail(Map<String, dynamic> data) async {
    try {
      final Response res =
          await _dio.post("$_auth/verify-reset-email", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<dynamic> verifyResetMobile(Map<String, dynamic> data) async {
    try {
      final Response res =
          await _dio.post("$_auth/verify-reset-mobile", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<dynamic> resetPassword(Map<String, dynamic> data) async {
    try {
      final Response res = await _dio.post("$_auth/reset-password", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<dynamic> verifyEmail(Map<String, dynamic> data) async {
    try {
      final Response res = await _dio.post("$_auth/verify-email", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> verifyMobile(Map<String, dynamic> data) async {
    try {
      final Response res = await _dio.post("$_auth/verify-mobile", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> resendEmailOtp(String email) async {
    try {
      final Response res = await _dio.post("$_auth/resend-email-otp",
          data: <String, dynamic>{"email": email});
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> resendMobileOtp(String mobile) async {
    try {
      final Response res = await _dio.post("$_auth/resend-mobile-otp",
          data: <String, dynamic>{"mobile": mobile});
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }
}