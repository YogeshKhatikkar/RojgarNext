// lib/features/resume/services/resume_profile_service.dart
// ✅ Helper service to fetch / check / upload profile photo
// ✅ Used by ResumeScreen AND BuildResumeScreen

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:rojgarnext/core/network/dio_client.dart';

class ResumeProfileService {
  // ============================================================
  // ✅ GET PROFILE PHOTO URL
  // Returns null if not uploaded
  // ============================================================
  static Future<String?> getProfilePhotoUrl() async {
    try {
      final res = await DioClient.dio.get('/user/full-profile');

      Map<String, dynamic> profile = {};
      if (res.data is Map) {
        if (res.data.containsKey('data') && res.data['data'] is Map) {
          profile = Map<String, dynamic>.from(res.data['data']);
        } else {
          profile = Map<String, dynamic>.from(res.data);
        }
      }

      final additional = profile['additional_details'] as Map? ?? {};

      final candidates = <dynamic>[
        additional['profile_photo_url'],
        profile['profile_photo_url'],
        profile['photo_url'],
      ];

      for (final c in candidates) {
        final s = (c ?? '').toString().trim();
        if (s.isNotEmpty && (s.startsWith('http://') || s.startsWith('https://'))) {
          debugPrint('✅ Profile photo URL: $s');
          return s;
        }
      }

      debugPrint('ℹ️ No profile photo URL found');
      return null;
    } catch (e) {
      debugPrint('❌ getProfilePhotoUrl error: $e');
      return null;
    }
  }

  // ============================================================
  // ✅ CHECK IF PROFILE PHOTO EXISTS
  // ============================================================
  static Future<bool> hasProfilePhoto() async {
    final url = await getProfilePhotoUrl();
    return url != null && url.isNotEmpty;
  }

  // ============================================================
  // ✅ UPLOAD PROFILE PHOTO BYTES
  // Returns public URL on success, throws on failure
  // ============================================================
  static Future<String> uploadProfilePhoto({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'document_type': 'profile_photo_url',
      });

      final res = await DioClient.dio.post(
        '/user/upload-document',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (res.data is Map && res.data['success'] == true) {
        final url = (res.data['url'] as String?) ?? '';
        if (url.isNotEmpty && url.startsWith('http')) {
          debugPrint('✅ Profile photo uploaded: $url');
          return url;
        }
        throw Exception('Server returned invalid URL');
      }

      throw Exception(
        res.data is Map
            ? (res.data['message'] ?? 'Upload failed')
            : 'Upload failed',
      );
    } catch (e) {
      debugPrint('❌ uploadProfilePhoto error: $e');
      rethrow;
    }
  }
}