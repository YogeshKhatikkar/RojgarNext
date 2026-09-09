// lib/features/user/presentation/widgets/user_sidebar.dart
// ✅ COMPLETE WITH SERVICES MENU - FIXED ListTile Warning & kReleaseMode

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:go_router/go_router.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/features/user/presentation/utils/menu_types.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rojgarnext/core/network/dio_client.dart';

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
  String? _profilePhotoUrl;
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

      try {
        final response = await DioClient.dio.get('/user/full-profile');
        Map<String, dynamic> profile = {};

        if (response.data is Map) {
          if (response.data.containsKey('data')) {
            profile = response.data['data'] as Map<String, dynamic>;
          } else {
            profile = response.data as Map<String, dynamic>;
          }
        }

        final additionalDetails = profile['additional_details'] as Map? ?? {};
        final photoUrl = additionalDetails['profile_photo_url'] as String?;

        if (photoUrl != null && photoUrl.isNotEmpty) {
          _profilePhotoUrl = photoUrl;
        } else {
          final directPhotoUrl = profile['profile_photo_url'] as String?;
          if (directPhotoUrl != null && directPhotoUrl.isNotEmpty) {
            _profilePhotoUrl = directPhotoUrl;
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
    final parts = _userName.split(' ');
    if (parts.length >= 2) {
      final firstInitial = parts[0].isNotEmpty ? parts[0][0] : '';
      final lastInitial = parts[1].isNotEmpty ? parts[1][0] : '';
      if (firstInitial.isNotEmpty && lastInitial.isNotEmpty) {
        return '$firstInitial$lastInitial'.toUpperCase();
      }
    }
    return _userName[0].toUpperCase();
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
          const SizedBox(height: 12),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withAlpha(26),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhoto() {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ),
      );
    }

    if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _profilePhotoUrl!,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          placeholder: (context, url) => Container(
            color: Colors.grey,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
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
          ),
        ),
      );
    }

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

  Widget _buildExpansionItem(String title, IconData icon, List<Widget> children) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
        ),
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
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildMenuItem("Dashboard", Icons.dashboard, MenuType.dashboard),
                  const SizedBox(height: 4),

                  // Personal Info
                  _buildExpansionItem("Personal Info", Icons.person, [
                    _buildMenuItem("Basic Details", Icons.info, MenuType.personal),
                    _buildMenuItem("Education", Icons.school, MenuType.education),
                    _buildMenuItem("Experience", Icons.work, MenuType.experience),
                    _buildMenuItem("Documents", Icons.folder, MenuType.documents),
                  ]),

                  // Career / Job
                  _buildExpansionItem("Career / Job", Icons.work, [
                    _buildMenuItem("Browse Jobs", Icons.search, MenuType.jobs),
                    _buildMenuItem("My Applications", Icons.assignment, MenuType.myApplications),
                    _buildMenuItem("Saved Jobs", Icons.bookmark, MenuType.savedJobs),
                  ]),

                  // Resume
                  _buildExpansionItem("Resume", Icons.description, [
                    _buildMenuItem("My Resume", Icons.picture_as_pdf, MenuType.resume),
                    _buildMenuItem("Build Resume", Icons.edit_document, MenuType.buildResume),
                  ]),

                  // ✅ Services Menu
                  _buildExpansionItem("Services", Icons.workspace_premium, [
                    _buildMenuItem("Apply Service", Icons.add_circle_outline, MenuType.applyService),
                    _buildMenuItem("Applications", Icons.assignment_turned_in, MenuType.serviceApplications),
                  ]),

                  // Settings
                  _buildExpansionItem("Settings", Icons.settings, [
                    _buildMenuItem("Change Password", Icons.lock, MenuType.changePassword),
                    _buildMenuItem("MPIN Setup", Icons.pin, MenuType.mpin),
                    _buildMenuItem("Biometric Login", Icons.fingerprint, MenuType.biometric),
                  ]),

                  _buildMenuItem("Support", Icons.help, MenuType.support),
                  
                  // Location Test (hidden in release)
                  if (!kReleaseMode)
                    _buildMenuItem("GPS Test", Icons.gps_fixed, MenuType.locationTest),
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