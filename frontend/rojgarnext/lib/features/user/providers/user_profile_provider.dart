// lib/features/user/providers/user_profile_provider.dart
// ✅ SINGLE SOURCE OF TRUTH for profile photo across entire app
// ✅ FIXED: Reads `additional_details.profile_photo_url` FIRST
// ✅ FIXED: Auto-syncs with ProfileStateService via listeners
// ✅ FIXED: Never clears photo on transient errors

import 'package:flutter/foundation.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/services/profile_state_service.dart';

class UserProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  String? _profilePhotoUrl;
  String? _profilePhotoPublicId;
  int _version = 0;

  // ============================================================
  // CONSTRUCTOR — auto-sync with ProfileStateService
  // ============================================================
  UserProfileProvider() {
    // Listen to ProfileStateService changes and mirror them
    ProfileStateService().profilePhotoUrl.addListener(_onGlobalPhotoChanged);
    ProfileStateService()
        .profilePhotoPublicId
        .addListener(_onGlobalPublicIdChanged);

    // Initial sync
    _profilePhotoUrl = ProfileStateService().profilePhotoUrl.value;
    _profilePhotoPublicId =
        ProfileStateService().profilePhotoPublicId.value;
  }

  void _onGlobalPhotoChanged() {
    final newUrl = ProfileStateService().profilePhotoUrl.value;
    if (_profilePhotoUrl != newUrl) {
      _profilePhotoUrl = newUrl;
      _version++;
      notifyListeners();
      debugPrint(
          '✅ UserProfileProvider: Synced from ProfileStateService → $_profilePhotoUrl');
    }
  }

  void _onGlobalPublicIdChanged() {
    final newId = ProfileStateService().profilePhotoPublicId.value;
    if (_profilePhotoPublicId != newId) {
      _profilePhotoPublicId = newId;
      _version++;
      notifyListeners();
    }
  }

  // ============================================================
  // GETTERS
  // ============================================================
  Map<String, dynamic>? get profile => _profile;
  String? get profilePhotoUrl => _profilePhotoUrl;
  String? get profilePhotoPublicId => _profilePhotoPublicId;
  bool get hasPhoto => (_profilePhotoUrl ?? '').trim().isNotEmpty;
  int get version => _version;

  // ============================================================
  // ✅ URL VALIDATOR
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
  String _normalizeCloudinaryUrl(String url) {
    try {
      final lower = url.toLowerCase();
      if (!lower.contains('cloudinary.com')) return url;
      if (lower.contains('/image/upload/') ||
          lower.contains('/video/upload/')) {
        return url;
      }
      if (lower.contains('/raw/upload/')) {
        return url.replaceFirst('/raw/upload/', '/image/upload/');
      }
      return url;
    } catch (e) {
      return url;
    }
  }

  // ============================================================
  // ✅ SET PROFILE PHOTO — syncs BOTH providers
  // ============================================================
  void setProfilePhoto({required String url, String? publicId}) {
    if (!_isValidImageUrl(url)) {
      debugPrint('❌ setProfilePhoto: invalid URL → $url');
      return;
    }

    final normalized = _normalizeCloudinaryUrl(url.trim());

    // Update local
    _profilePhotoUrl = normalized;
    _profilePhotoPublicId = publicId;
    _version++;
    notifyListeners();

    // ✅ Also update ProfileStateService (keeps both in sync)
    ProfileStateService().setPhoto(url: normalized, publicId: publicId);

    debugPrint('✅ Provider photo set (v$_version): $_profilePhotoUrl');
  }

  /// Alias — used by some screens
  void updateProfilePhotoFromUrl(String url, {String? publicId}) {
    setProfilePhoto(url: url, publicId: publicId);
  }

  // ============================================================
  // ✅ CLEAR PROFILE PHOTO — syncs BOTH providers
  // ============================================================
  void clearProfilePhoto() {
    _profilePhotoUrl = null;
    _profilePhotoPublicId = null;
    _version++;
    notifyListeners();

    // ✅ Also clear in ProfileStateService
    ProfileStateService().clearPhoto();

    debugPrint('🗑️ Provider photo cleared (v$_version)');
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

    // ✅ Also reset ProfileStateService
    ProfileStateService().reset();

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

        // ✅ Sync to ProfileStateService
        ProfileStateService()
            .setPhoto(url: normalized, publicId: _profilePhotoPublicId);
      } else {
        // ✅ Only clear if we don't already have a photo (prevents flicker)
        if (_profilePhotoUrl == null) {
          _profilePhotoUrl = null;
          _profilePhotoPublicId = null;
          ProfileStateService().clearPhoto();
        }
      }

      notifyListeners();
      debugPrint(
          '✅ Provider profile fetched (v$_version) — photo: $_profilePhotoUrl');
    } catch (e) {
      debugPrint('❌ Provider fetchProfile failed: $e');
      // ✅ DON'T clear photo on error
    }
  }

  Future<void> refresh() async {
    await fetchProfile();
  }

  void updateProfile(Map<String, dynamic> newProfile) {
    _profile = newProfile;
    final additional = (newProfile['additional_details'] as Map?) ?? {};
    final rawUrl = (additional['profile_photo_url']?.toString() ??
            newProfile['profile_photo_url']?.toString() ??
            '')
        .trim();

    if (_isValidImageUrl(rawUrl)) {
      _profilePhotoUrl = _normalizeCloudinaryUrl(rawUrl);
      ProfileStateService().setPhoto(url: _profilePhotoUrl!);
    }
    _version++;
    notifyListeners();
  }

  // ============================================================
  // DISPOSE — remove listeners
  // ============================================================
  @override
  void dispose() {
    try {
      ProfileStateService()
          .profilePhotoUrl
          .removeListener(_onGlobalPhotoChanged);
      ProfileStateService()
          .profilePhotoPublicId
          .removeListener(_onGlobalPublicIdChanged);
    } catch (_) {}
    super.dispose();
  }
}