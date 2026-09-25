// lib/features/user/providers/user_profile_provider.dart
// ✅ SINGLE SOURCE OF TRUTH for profile photo across entire app
// ✅ Notifies listeners on every change → no page reload needed
// ✅ Added: loadProfile() + clear() methods (fixes compile errors)

import 'package:flutter/foundation.dart';
import 'package:rojgarnext/core/network/dio_client.dart';

class UserProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;

  /// Current profile photo URL — null / empty means NO photo
  String? _profilePhotoUrl;

  /// Current profile photo Cloudinary public_id (for deletion)
  String? _profilePhotoPublicId;

  // ============================================================
  // GETTERS
  // ============================================================
  Map<String, dynamic>? get profile => _profile;
  String? get profilePhotoUrl => _profilePhotoUrl;
  String? get profilePhotoPublicId => _profilePhotoPublicId;
  bool get hasPhoto => (_profilePhotoUrl ?? '').trim().isNotEmpty;

  // ============================================================
  // ✅ SET PROFILE PHOTO (from any upload source)
  // ============================================================
  void setProfilePhoto({required String url, String? publicId}) {
    if (url.trim().isEmpty) {
      clearProfilePhoto();
      return;
    }
    _profilePhotoUrl = url.trim();
    _profilePhotoPublicId = publicId;
    notifyListeners();
    debugPrint('✅ Provider photo set: $_profilePhotoUrl');
  }

  /// Same as setProfilePhoto — alias used by ResumeScreen
  void updateProfilePhotoFromUrl(String url, {String? publicId}) {
    setProfilePhoto(url: url, publicId: publicId);
  }

  // ============================================================
  // ✅ CLEAR PROFILE PHOTO (from delete action)
  // ============================================================
  void clearProfilePhoto() {
    _profilePhotoUrl = null;
    _profilePhotoPublicId = null;
    notifyListeners();
    debugPrint('🗑️ Provider photo cleared');
  }

  // ============================================================
  // ✅ NEW: loadProfile() — called from main.dart on app start
  // Alias for fetchProfile() for backward compatibility
  // ============================================================
  Future<void> loadProfile() async {
    await fetchProfile();
  }

  // ============================================================
  // ✅ NEW: clear() — called from sidebar logout
  // Clears ALL cached profile data + photo
  // ============================================================
  void clear() {
    _profile = null;
    _profilePhotoUrl = null;
    _profilePhotoPublicId = null;
    notifyListeners();
    debugPrint('🗑️ Provider: Full profile state cleared (logout)');
  }

  // ============================================================
  // ✅ FETCH FULL PROFILE + EXTRACT PHOTO URL
  // ============================================================
  Future<void> fetchProfile() async {
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
      _profile = data;

      final additional = (data['additional_details'] as Map?) ?? {};
      final photoUrl = (additional['profile_photo_url']?.toString() ??
              data['profile_photo_url']?.toString() ??
              '')
          .trim();

      _profilePhotoPublicId = (additional['profile_photo_public_id'] ??
              data['profile_photo_public_id'])
          ?.toString();

      if (photoUrl.isNotEmpty) {
        _profilePhotoUrl = photoUrl;
      } else {
        _profilePhotoUrl = null;
        _profilePhotoPublicId = null;
      }

      notifyListeners();
      debugPrint('✅ Provider profile fetched — photo: $_profilePhotoUrl');
    } catch (e) {
      debugPrint('❌ Provider fetchProfile failed: $e');
    }
  }

  // ============================================================
  // ✅ REFRESH FROM BACKEND (safe — keeps old value on failure)
  // ============================================================
  Future<void> refresh() async {
    await fetchProfile();
  }

  // ============================================================
  // ✅ FULL PROFILE UPDATE (for other profile screens)
  // ============================================================
  void updateProfile(Map<String, dynamic> newProfile) {
    _profile = newProfile;
    final additional = (newProfile['additional_details'] as Map?) ?? {};
    final photoUrl = (additional['profile_photo_url']?.toString() ??
            newProfile['profile_photo_url']?.toString() ??
            '')
        .trim();
    if (photoUrl.isNotEmpty) {
      _profilePhotoUrl = photoUrl;
    } else {
      _profilePhotoUrl = null;
    }
    notifyListeners();
  }
}