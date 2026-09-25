// lib/features/resume/services/resume_profile_service.dart
// ✅ Fetches profile photo URL from backend — used by ResumeScreen on load

import 'package:flutter/foundation.dart';
import 'package:rojgarnext/core/network/dio_client.dart';

class ResumeProfileService {
  /// Returns the current profile photo URL from backend, or null if not set
  static Future<String?> getProfilePhotoUrl() async {
    try {
      final response = await DioClient.dio.get('/user/full-profile');

      Map<String, dynamic> data = {};
      if (response.data is Map) {
        final body = response.data as Map;
        if (body['data'] is Map) {
          data = Map<String, dynamic>.from(body['data']);
        } else {
          data = Map<String, dynamic>.from(body);
        }
      }

      final additional = (data['additional_details'] as Map?) ?? {};
      final photoUrl = (additional['profile_photo_url']?.toString() ??
              data['profile_photo_url']?.toString() ??
              '')
          .trim();

      if (photoUrl.isEmpty) return null;
      return photoUrl;
    } catch (e) {
      debugPrint('❌ ResumeProfileService.getProfilePhotoUrl failed: $e');
      return null;
    }
  }

  /// Returns profile photo public_id (for delete tracking)
  static Future<String?> getProfilePhotoPublicId() async {
    try {
      final response = await DioClient.dio.get('/user/full-profile');
      Map<String, dynamic> data = {};
      if (response.data is Map) {
        final body = response.data as Map;
        if (body['data'] is Map) {
          data = Map<String, dynamic>.from(body['data']);
        } else {
          data = Map<String, dynamic>.from(body);
        }
      }
      final additional = (data['additional_details'] as Map?) ?? {};
      return (additional['profile_photo_public_id'] ??
              data['profile_photo_public_id'])
          ?.toString();
    } catch (e) {
      return null;
    }
  }
}