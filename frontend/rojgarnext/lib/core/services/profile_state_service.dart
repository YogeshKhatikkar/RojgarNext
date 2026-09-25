// lib/core/services/profile_state_service.dart
// ✅ GLOBAL PROFILE STATE — Broadcasts photo changes app-wide instantly
// ✅ No page reload needed when photo is added/removed

import 'package:flutter/foundation.dart';

class ProfileStateService {
  static final ProfileStateService _instance = ProfileStateService._internal();
  factory ProfileStateService() => _instance;
  ProfileStateService._internal();

  /// Current profile photo URL — null / empty means NO photo
  final ValueNotifier<String?> profilePhotoUrl = ValueNotifier<String?>(null);

  /// Bumped whenever ANY profile data changes (triggers resume re-fetch/re-render)
  final ValueNotifier<int> profileDataVersion = ValueNotifier<int>(0);

  /// True once the initial load has completed (prevents popup before data arrives)
  final ValueNotifier<bool> hasInitialPhotoLoaded = ValueNotifier<bool>(false);

  void updatePhotoUrl(String? url) {
    final normalized = (url == null || url.trim().isEmpty) ? null : url.trim();
    profilePhotoUrl.value = normalized;
    hasInitialPhotoLoaded.value = true;
  }

  void clearPhoto() {
    profilePhotoUrl.value = null;
    hasInitialPhotoLoaded.value = true;
  }

  void bumpVersion() {
    profileDataVersion.value = profileDataVersion.value + 1;
  }

  String? get currentPhotoUrl => profilePhotoUrl.value;
  bool get hasPhoto => (profilePhotoUrl.value ?? '').isNotEmpty;
}