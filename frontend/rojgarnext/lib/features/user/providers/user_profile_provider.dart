// lib/features/user/providers/user_profile_provider.dart
// ✅ SINGLE SOURCE OF TRUTH for profile photo across entire app
// ✅ FIXED: Image URL validation, force notify, version tracking
// ✅ FIXED: Cloudinary raw → image URL conversion
// ✅ FIXED: Added loadProfile() + clear() methods

import 'package:flutter/foundation.dart';
import 'package:rojgarnext/core/network/dio_client.dart';

class UserProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;

  /// Current profile photo URL — null / empty means NO photo
  String? _profilePhotoUrl;

  /// Current profile photo Cloudinary public_id (for deletion)
  String? _profilePhotoPublicId;

  /// Bumped on every update — forces dependent widgets to recompute
  int _version = 0;

  // ============================================================
  // GETTERS
  // ============================================================
  Map<String, dynamic>? get profile => _profile;
  String? get profilePhotoUrl => _profilePhotoUrl;
  String? get profilePhotoPublicId => _profilePhotoPublicId;
  bool get hasPhoto => (_profilePhotoUrl ?? '').trim().isNotEmpty;
  int get version => _version;

  // ============================================================
  // ✅ URL VALIDATOR — rejects garbage / non-image / raw-type URLs
  // ============================================================
  bool _isValidImageUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'none' ||
        lower == 'n/a') {
      return false;
    }
    return true;
  }

  /// ✅ Converts Cloudinary raw upload URL → image-renderable URL.
  /// Example:
  ///   https://res.cloudinary.com/demo/raw/upload/v1/folder/photo.jpg
  ///   → https://res.cloudinary.com/demo/image/upload/v1/folder/photo.jpg
  String _normalizeCloudinaryUrl(String url) {
    try {
      final lower = url.toLowerCase();

      // Only touch Cloudinary URLs
      if (!lower.contains('cloudinary.com')) return url;

      // Skip if already image/upload or video/upload
      if (lower.contains('/image/upload/') ||
          lower.contains('/video/upload/')) {
        return url;
      }

      // Convert raw/upload → image/upload
      if (lower.contains('/raw/upload/')) {
        final fixed = url.replaceFirst('/raw/upload/', '/image/upload/');
        debugPrint('🔄 Converted raw URL → image URL: $fixed');
        return fixed;
      }

      return url;
    } catch (e) {
      debugPrint('⚠️ URL normalize error: $e');
      return url;
    }
  }

  // ============================================================
  // ✅ SET PROFILE PHOTO (from any upload source)
  // ============================================================
  void setProfilePhoto({required String url, String? publicId}) {
    if (!_isValidImageUrl(url)) {
      debugPrint('❌ setProfilePhoto: invalid URL → $url');
      return;
    }

    final normalized = _normalizeCloudinaryUrl(url.trim());

    // ✅ Only notify if URL actually changed
    final changed = _profilePhotoUrl != normalized ||
        _profilePhotoPublicId != publicId;

    _profilePhotoUrl = normalized;
    _profilePhotoPublicId = publicId;

    if (changed) {
      _version++;
      notifyListeners();
      debugPrint('✅ Provider photo set (v$_version): $_profilePhotoUrl');
    }
  }

  /// Alias — used by some screens
  void updateProfilePhotoFromUrl(String url, {String? publicId}) {
    setProfilePhoto(url: url, publicId: publicId);
  }

  // ============================================================
  // ✅ CLEAR PROFILE PHOTO
  // ============================================================
  void clearProfilePhoto() {
    final hadPhoto = (_profilePhotoUrl ?? '').isNotEmpty;
    _profilePhotoUrl = null;
    _profilePhotoPublicId = null;
    if (hadPhoto) {
      _version++;
      notifyListeners();
      debugPrint('🗑️ Provider photo cleared (v$_version)');
    }
  }

  // ============================================================
  // ✅ LOAD PROFILE — called from main.dart on app start
  // ============================================================
  Future<void> loadProfile() async {
    await fetchProfile();
  }

  // ============================================================
  // ✅ CLEAR — called from sidebar logout
  // ============================================================
  void clear() {
    _profile = null;
    _profilePhotoUrl = null;
    _profilePhotoPublicId = null;
    _version++;
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
      final rawUrl = (additional['profile_photo_url']?.toString() ??
              data['profile_photo_url']?.toString() ??
              data['photo_url']?.toString() ??
              '')
          .trim();

      _profilePhotoPublicId = (additional['profile_photo_public_id'] ??
              data['profile_photo_public_id'])
          ?.toString();

      if (_isValidImageUrl(rawUrl)) {
        final normalized = _normalizeCloudinaryUrl(rawUrl);
        final changed = _profilePhotoUrl != normalized;
        _profilePhotoUrl = normalized;
        if (changed) _version++;
      } else {
        _profilePhotoUrl = null;
        _profilePhotoPublicId = null;
      }

      notifyListeners();
      debugPrint('✅ Provider profile fetched (v$_version) — photo: $_profilePhotoUrl');
    } catch (e) {
      debugPrint('❌ Provider fetchProfile failed: $e');
    }
  }

  // ============================================================
  // ✅ REFRESH FROM BACKEND
  // ============================================================
  Future<void> refresh() async {
    await fetchProfile();
  }

  // ============================================================
  // ✅ FULL PROFILE UPDATE
  // ============================================================
  void updateProfile(Map<String, dynamic> newProfile) {
    _profile = newProfile;
    final additional = (newProfile['additional_details'] as Map?) ?? {};
    final rawUrl = (additional['profile_photo_url']?.toString() ??
            newProfile['profile_photo_url']?.toString() ??
            '')
        .trim();

    if (_isValidImageUrl(rawUrl)) {
      _profilePhotoUrl = _normalizeCloudinaryUrl(rawUrl);
    } else {
      _profilePhotoUrl = null;
    }
    _version++;
    notifyListeners();
  }
}