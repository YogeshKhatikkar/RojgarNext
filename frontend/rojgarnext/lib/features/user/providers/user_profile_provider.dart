// lib/features/user/providers/user_profile_provider.dart
// ✅ GLOBAL STATE - SAME PHOTO EVERYWHERE WITHOUT RELOAD
// ✅ Used by: UserDashboard, ResumeScreen, BuildResumeScreen, UserSidebar,
//             UserDocumentsScreen
// ✅ When photo updates → notifyListeners() → all listeners rebuild instantly
// ✅ NEW: setProfilePhoto() + clearProfilePhoto() for cross-screen sync
// ✅ Complete file — no lines skipped

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/config/api_config.dart';

class UserProfileProvider extends ChangeNotifier {
  // ============================================================
  // STATE
  // ============================================================
  String? _profilePhotoUrl;
  String? _profilePhotoPublicId;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _resumeData;
  List<String> _availableResumeFormats = [];
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _errorMessage;

  // Getters
  String? get profilePhotoUrl => _profilePhotoUrl;
  String? get profilePhotoPublicId => _profilePhotoPublicId;
  Map<String, dynamic>? get profileData => _profileData;
  Map<String, dynamic>? get resumeData => _resumeData;
  List<String> get availableResumeFormats => _availableResumeFormats;
  bool get isLoading => _isLoading;
  bool get isUploadingPhoto => _isUploadingPhoto;
  String? get errorMessage => _errorMessage;
  bool get hasProfilePhoto =>
      _profilePhotoUrl != null && _profilePhotoUrl!.trim().isNotEmpty;

  // ============================================================
  // LOAD PROFILE (from /user/full-profile)
  // ============================================================
  Future<void> loadProfile({bool force = false}) async {
    if (_isLoading && !force) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        _profileData = null;
        _profilePhotoUrl = null;
        _notify();
        return;
      }

      final response = await DioClient.dio.get('/user/full-profile');
      Map<String, dynamic> data = {};
      if (response.data is Map) {
        final rd = response.data;
        if (rd.containsKey('data') && rd['data'] is Map) {
          data = Map<String, dynamic>.from(rd['data']);
        } else {
          data = Map<String, dynamic>.from(rd);
        }
      }
      _profileData = data;

      // Extract profile photo URL — check multiple places
      final additional = data['additional_details'] as Map? ?? {};
      final photo = (data['profile_photo_url']?.toString() ??
              additional['profile_photo_url']?.toString() ??
              data['photo_url']?.toString() ??
              '')
          .trim();

      if (photo.isNotEmpty &&
          (photo.startsWith('http://') || photo.startsWith('https://'))) {
        _profilePhotoUrl = photo;
        _profilePhotoPublicId =
            data['profile_photo_public_id']?.toString() ??
                additional['profile_photo_public_id']?.toString();
      } else {
        _profilePhotoUrl = null;
        _profilePhotoPublicId = null;
      }

      _availableResumeFormats =
          List<String>.from(data['resume_formats_available'] ?? []);

      debugPrint("✅ ProfileProvider loaded: photo=$_profilePhotoUrl");
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("❌ ProfileProvider load failed: $e");
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // UPLOAD PROFILE PHOTO — uses /user/upload-document
  // Same endpoint used by ResumeProfileService
  // ============================================================
  Future<bool> uploadProfilePhoto({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    if (_isUploadingPhoto) return false;

    _isUploadingPhoto = true;
    _errorMessage = null;
    _notify();

    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        throw Exception("No authentication token found");
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/user/upload-document');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Determine MIME type
      final ext = fileName.toLowerCase().split('.').last;
      String mimeType = 'image/jpeg';
      switch (ext) {
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        case 'bmp':
          mimeType = 'image/bmp';
          break;
        case 'jpg':
        case 'jpeg':
        default:
          mimeType = 'image/jpeg';
      }

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ));
      request.fields['document_type'] = 'profile_photo_url';

      debugPrint("📤 Uploading profile photo: $fileName ($mimeType)");
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      debugPrint("📥 Upload status: ${response.statusCode}");
      debugPrint("📥 Upload body: ${response.body}");

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            "Upload failed: ${response.statusCode} - ${response.body}");
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final newUrl = (responseData['url']?.toString() ??
              responseData['data']?['url']?.toString() ??
              '')
          .trim();

      if (newUrl.isEmpty || !newUrl.startsWith('http')) {
        throw Exception("Server did not return a valid photo URL");
      }

      // ✅ Update local state IMMEDIATELY — UI updates without reload
      _profilePhotoUrl = newUrl;
      _profilePhotoPublicId = responseData['public_id']?.toString() ??
          responseData['data']?['public_id']?.toString();

      // ✅ Persist to profile DB (non-blocking)
      _persistPhotoToProfile(newUrl, _profilePhotoPublicId);

      // ✅ Notify all listeners — sidebar + resume + dashboard rebuild instantly
      _notify();

      // ✅ Refresh full profile in background (non-blocking)
      unawaited(loadProfile(force: true));

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("❌ Upload profile photo failed: $e");
      _notify();
      return false;
    } finally {
      _isUploadingPhoto = false;
      _notify();
    }
  }

  // ============================================================
  // ✅ NEW: SET PHOTO (called from Documents screen after upload)
  // ============================================================
  void setProfilePhoto({
    required String url,
    String? publicId,
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    if (_profilePhotoUrl == trimmed &&
        (publicId == null || publicId == _profilePhotoPublicId)) {
      return; // no change — avoid redundant notify
    }

    _profilePhotoUrl = trimmed;
    if (publicId != null && publicId.isNotEmpty) {
      _profilePhotoPublicId = publicId;
    }

    // ✅ Update cached profileData too
    _profileData ??= {};
    _profileData!['profile_photo_url'] = trimmed;
    final additional =
        Map<String, dynamic>.from((_profileData!['additional_details'] as Map?) ?? {});
    additional['profile_photo_url'] = trimmed;
    if (publicId != null && publicId.isNotEmpty) {
      additional['profile_photo_public_id'] = publicId;
    }
    _profileData!['additional_details'] = additional;

    debugPrint("✅ ProfileProvider: setProfilePhoto → $trimmed");
    _notify();
  }

  // ============================================================
  // ✅ NEW: CLEAR ONLY PROFILE PHOTO (called from Documents screen on delete)
  // Keeps profileData intact — only removes photo
  // ============================================================
  void clearProfilePhoto() {
    _profilePhotoUrl = null;
    _profilePhotoPublicId = null;

    // Also purge from cached profileData so resume rebuild is clean
    if (_profileData != null) {
      _profileData!.remove('profile_photo_url');
      final additional = _profileData!['additional_details'];
      if (additional is Map) {
        additional.remove('profile_photo_url');
        additional.remove('profile_photo_public_id');
      }
    }

    debugPrint("🗑️ ProfileProvider: clearProfilePhoto called");
    _notify();
  }

  // ============================================================
  // ✅ NEW: Persist photo URL to profile DB (non-blocking)
  // ============================================================
  Future<void> _persistPhotoToProfile(String url, String? publicId) async {
    try {
      final updateData = <String, dynamic>{
        'additional_details.profile_photo_url': url,
      };
      if (publicId != null && publicId.isNotEmpty) {
        updateData['additional_details.profile_photo_public_id'] = publicId;
      }
      await DioClient.dio.put('/user/update-profile', data: updateData);
      debugPrint("✅ Photo persisted to profile DB");
    } catch (e) {
      debugPrint("⚠️ Could not persist photo URL to profile (non-fatal): $e");
    }
  }

  // ============================================================
  // UPDATE PHOTO FROM EXTERNAL URL (called by other services)
  // ============================================================
  void updateProfilePhotoFromUrl(String url, {String? publicId}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    if (_profilePhotoUrl == trimmed) return; // avoid redundant notify

    _profilePhotoUrl = trimmed;
    if (publicId != null) _profilePhotoPublicId = publicId;
    _notify();
  }

  // ============================================================
  // REBUILD RESUME (manual trigger)
  // ============================================================
  Future<bool> rebuildResume() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) return false;

      final response = await DioClient.dio.post('/resume/rebuild');
      if (response.data['success'] == true) {
        _resumeData = Map<String, dynamic>.from(
          response.data['resume_data'] ?? {},
        );
        _availableResumeFormats =
            List<String>.from(response.data['formats'] ?? []);
        _notify();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ rebuildResume failed: $e");
      return false;
    }
  }

  // ============================================================
  // UPDATE PROFILE DATA (merge)
  // ============================================================
  void updateProfileData(Map<String, dynamic> newData) {
    _profileData = {...?_profileData, ...newData};
    final additional = _profileData?['additional_details'] as Map? ?? {};
    final photo = (_profileData?['profile_photo_url']?.toString() ??
            additional['profile_photo_url']?.toString() ??
            '')
        .trim();
    if (photo.isNotEmpty) {
      _profilePhotoUrl = photo;
    }
    _notify();
  }

  // ============================================================
  // CLEAR (on logout) — full reset
  // ============================================================
  void clear() {
    _profilePhotoUrl = null;
    _profilePhotoPublicId = null;
    _profileData = null;
    _resumeData = null;
    _availableResumeFormats = [];
    _errorMessage = null;
    _notify();
  }

  // ============================================================
  // INTERNAL
  // ============================================================
  void _setLoading(bool v) {
    _isLoading = v;
    _notify();
  }

  void _notify() {
    try {
      notifyListeners();
    } catch (e) {
      debugPrint("⚠️ Provider notify error: $e");
    }
  }
}

// Helper to run futures without awaiting
void unawaited(Future<void> f) {
  // ignore: discarded_futures
  f;
}