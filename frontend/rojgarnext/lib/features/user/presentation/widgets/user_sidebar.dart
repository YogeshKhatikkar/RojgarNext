// lib/features/user/presentation/widgets/user_sidebar.dart
// ✅ Listens to UserProfileProvider → photo updates everywhere instantly
// ✅ NEW: Camera icon overlay on profile photo → tap to upload
// ✅ Same pattern as Build Resume screen

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/features/user/presentation/utils/menu_types.dart';
import 'package:rojgarnext/features/user/providers/user_profile_provider.dart';
import 'package:rojgarnext/features/resume/presentation/widgets/profile_photo_upload_dialog.dart';

class UserSidebar extends StatefulWidget {
  final MenuType selectedMenu;
  final Function(MenuType) onMenuSelected;

  const UserSidebar({
    super.key,
    required this.selectedMenu,
    required this.onMenuSelected,
  });

  @override
  State<UserSidebar> createState() => _UserSidebarState();
}

class _UserSidebarState extends State<UserSidebar> {
  String _userName = "User";
  String _userEmail = "";
  String? _fallbackPhotoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final email = await SecureStorage.getEmail();
      if (email != null && email.isNotEmpty) {
        _userEmail = email;
        _userName = email.split('@').first;
      }

      final name = await SecureStorage.getName();
      if (name != null && name.isNotEmpty) {
        _userName = name;
      }

      // Fetch profile photo (also syncs to provider)
      try {
        final response = await DioClient.dio.get('/user/full-profile');
        Map<String, dynamic> profile = {};

        if (response.data is Map) {
          if (response.data.containsKey('data')) {
            profile = Map<String, dynamic>.from(response.data['data']);
          } else {
            profile = Map<String, dynamic>.from(response.data);
          }
        }

        final additionalDetails =
            profile['additional_details'] as Map? ?? {};
        final photoUrl = (additionalDetails['profile_photo_url'] ??
                profile['profile_photo_url'] ??
                profile['photo_url'] ??
                '')
            .toString()
            .trim();

        if (photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
          _fallbackPhotoUrl = photoUrl;

          // ✅ Push to provider so all screens see it
          if (mounted) {
            Provider.of<UserProfileProvider>(context, listen: false)
                .updateProfilePhotoFromUrl(photoUrl);
          }
        }

        final fullName = profile['full_name'] as String?;
        if (fullName != null && fullName.isNotEmpty) {
          _userName = fullName;
        }
      } catch (e) {
        debugPrint("Error fetching profile photo: $e");
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getInitials() {
    if (_userName.isEmpty) return 'U';
    final parts = _userName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _userName[0].toUpperCase();
  }

  Widget _initialsAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.purple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    // ✅ Listen to provider — auto-updates when photo changes anywhere
    return Consumer<UserProfileProvider>(
      builder: (context, provider, _) {
        final url = provider.profilePhotoUrl ?? _fallbackPhotoUrl;

        if (_isLoading && (url == null || url.isEmpty)) {
          return Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        if (url != null && url.isNotEmpty) {
          return ClipOval(
            child: CachedNetworkImage(
              key: ValueKey(url),
              imageUrl: url,
              fit: BoxFit.cover,
              width: 80,
              height: 80,
              placeholder: (context, u) => Container(
                color: Colors.grey,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, u, error) => _initialsAvatar(),
            ),
          );
        }

        return _initialsAvatar();
      },
    );
  }

  // ============================================================
  // ✅ NEW: Open ProfilePhotoUploadDialog (same as Build Resume)
  // ============================================================
  Future<void> _openProfilePhotoUpload() async {
    if (!mounted) return;

    // Read current photo from provider (single source of truth)
    final currentUrl =
        Provider.of<UserProfileProvider>(context, listen: false)
            .profilePhotoUrl ??
        _fallbackPhotoUrl;

    final uploadedUrl = await ProfilePhotoUploadDialog.show(
      context,
      currentPhotoUrl: currentUrl,
    );

    // ✅ Provider is already updated inside the dialog —
    // no setState needed. But we refresh the local fallback anyway.
    if (uploadedUrl != null && uploadedUrl.isNotEmpty && mounted) {
      setState(() {
        _fallbackPhotoUrl = uploadedUrl;
      });
      debugPrint("✅ Sidebar: profile photo updated → $uploadedUrl");
    }
  }

  // ============================================================
  // ✅ Profile section with camera icon overlay
  // ============================================================
  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ✅ Photo + camera overlay (Stack — same as Build Resume)
          GestureDetector(
            onTap: _openProfilePhotoUpload,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withAlpha(51),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildProfilePhoto(),
                ),

                // ✅ Camera icon at bottom-right
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openProfilePhotoUpload,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueAccent.shade400,
                              Colors.purpleAccent.shade200,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _userEmail,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          // Small hint text
          Text(
            "Tap photo to update",
            style: TextStyle(
              color: Colors.white.withAlpha(120),
              fontSize: 9,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withAlpha(26),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, MenuType type) {
    final isSelected = widget.selectedMenu == type;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.blueAccent : Colors.white70,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blueAccent : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.blueAccent.withAlpha(51),
        onTap: () => widget.onMenuSelected(type),
        tileColor: Colors.transparent,
      ),
    );
  }

  Widget _buildExpansionItem(
      String title, IconData icon, List<Widget> children) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        listTileTheme: const ListTileThemeData(tileColor: Colors.transparent),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.white70, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        collapsedIconColor: Colors.white70,
        iconColor: Colors.blueAccent,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 16),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        children: children,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.redAccent),
        title: const Text(
          "Logout",
          style: TextStyle(color: Colors.white),
        ),
        onTap: () async {
          // Clear the provider state
          if (mounted) {
            Provider.of<UserProfileProvider>(context, listen: false).clear();
          }
          await SecureStorage.logout();
          if (context.mounted) {
            context.go(AppRoutes.home);
          }
        },
        tileColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF1E293B),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 30),
            _buildProfileSection(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildMenuItem(
                      "Dashboard", Icons.dashboard, MenuType.dashboard),
                  const SizedBox(height: 4),
                  _buildExpansionItem("Personal Info", Icons.person, [
                    _buildMenuItem(
                        "Basic Details", Icons.info, MenuType.personal),
                    _buildMenuItem(
                        "Education", Icons.school, MenuType.education),
                    _buildMenuItem(
                        "Experience", Icons.work, MenuType.experience),
                    _buildMenuItem(
                        "Documents", Icons.folder, MenuType.documents),
                  ]),
                  _buildExpansionItem("Career / Job", Icons.work, [
                    _buildMenuItem("Browse Jobs", Icons.search, MenuType.jobs),
                    _buildMenuItem("My Applications", Icons.assignment,
                        MenuType.myApplications),
                    _buildMenuItem("Saved Jobs", Icons.bookmark,
                        MenuType.savedJobs),
                  ]),
                  _buildExpansionItem("Resume", Icons.description, [
                    _buildMenuItem("My Resume", Icons.picture_as_pdf,
                        MenuType.resume),
                    _buildMenuItem("Build Resume", Icons.edit_document,
                        MenuType.buildResume),
                  ]),
                  _buildExpansionItem("Services", Icons.workspace_premium, [
                    _buildMenuItem("Apply Service",
                        Icons.add_circle_outline, MenuType.applyService),
                    _buildMenuItem("Applications",
                        Icons.assignment_turned_in, MenuType.serviceApplications),
                  ]),
                  _buildExpansionItem("Settings", Icons.settings, [
                    _buildMenuItem("Change Password", Icons.lock,
                        MenuType.changePassword),
                    _buildMenuItem("MPIN Setup", Icons.pin, MenuType.mpin),
                    _buildMenuItem("Biometric Login", Icons.fingerprint,
                        MenuType.biometric),
                  ]),
                  _buildMenuItem("Support", Icons.help, MenuType.support),
                  if (!kReleaseMode)
                    _buildMenuItem("GPS Test", Icons.gps_fixed,
                        MenuType.locationTest),
                ],
              ),
            ),
            const Divider(color: Colors.grey, height: 1),
            _buildLogoutButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}