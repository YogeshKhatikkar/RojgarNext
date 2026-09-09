// lib/features/admin/presentation/widgets/admin_sidebar.dart
// ✅ WITH FIXED LOGOUT AND PROPER MENU SELECTION - FIXED ListTile Warning

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import '../models/admin_menu.dart';

class AdminSidebar extends StatelessWidget {
  final AdminMenuType selectedMenu;
  final Function(AdminMenuType) onMenuSelected;
  final Function(JobSubMenu) onJobSubMenuSelected;
  final Function(ApplicationSubMenu) onApplicationSubMenuSelected;

  const AdminSidebar({
    super.key,
    required this.selectedMenu,
    required this.onMenuSelected,
    required this.onJobSubMenuSelected,
    required this.onApplicationSubMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF1E293B),
      child: Material( // ✅ FIX: Wrapped with Material to fix ListTile warning
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                size: 45,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Admin Panel",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildMenuItem(
                      "Dashboard", Icons.dashboard, AdminMenuType.dashboard),
                  _buildJobManagementMenu(),
                  _buildApplicationManagementMenu(),
                  _buildMenuItem(
                      "Users", Icons.people, AdminMenuType.manageUsers),
                  _buildMenuItem(
                      "Reports", Icons.bar_chart, AdminMenuType.reports),
                  _buildMenuItem(
                      "Settings", Icons.settings, AdminMenuType.settings),
                ],
              ),
            ),
            const Divider(color: Colors.grey, height: 1),
            // ✅ Logout button with Material wrapper
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Logout", style: TextStyle(color: Colors.white)),
                onTap: () async {
                  await SecureStorage.logout();
                  if (context.mounted) {
                    context.go(AppRoutes.home);
                  }
                },
                tileColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, AdminMenuType type) {
    final isSelected = selectedMenu == type;
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
        onTap: () => onMenuSelected(type),
        tileColor: Colors.transparent,
      ),
    );
  }

  Widget _buildJobManagementMenu() {
    final isSelected = selectedMenu == AdminMenuType.jobManagement;
    return Theme(
      data: ThemeData(
        dividerColor: Colors.transparent,
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
        ),
      ),
      child: ExpansionTile(
        leading: Icon(
          Icons.work,
          color: isSelected ? Colors.blueAccent : Colors.white70,
        ),
        title: Text(
          "Job Management",
          style:
              TextStyle(color: isSelected ? Colors.blueAccent : Colors.white),
        ),
        collapsedIconColor: Colors.white70,
        iconColor: Colors.blueAccent,
        initiallyExpanded: isSelected,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 16),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        children: [
          _buildSubMenuItem("All Jobs", Icons.list,
              () => onJobSubMenuSelected(JobSubMenu.allJobs)),
          _buildSubMenuItem("Add New Job", Icons.add,
              () => onJobSubMenuSelected(JobSubMenu.addNewJob)),
        ],
      ),
    );
  }

  Widget _buildApplicationManagementMenu() {
    final isSelected = selectedMenu == AdminMenuType.applicationManagement;
    return Theme(
      data: ThemeData(
        dividerColor: Colors.transparent,
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
        ),
      ),
      child: ExpansionTile(
        leading: Icon(
          Icons.assignment,
          color: isSelected ? Colors.blueAccent : Colors.white70,
        ),
        title: Text(
          "Application Management",
          style:
              TextStyle(color: isSelected ? Colors.blueAccent : Colors.white),
        ),
        collapsedIconColor: Colors.white70,
        iconColor: Colors.blueAccent,
        initiallyExpanded: isSelected,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 16),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        children: [
          _buildSubMenuItem("All Applications", Icons.list_alt,
              () => onApplicationSubMenuSelected(
                  ApplicationSubMenu.allApplications)),
          _buildSubMenuItem("Pending", Icons.hourglass_empty,
              () => onApplicationSubMenuSelected(
                  ApplicationSubMenu.pendingApplications)),
          _buildSubMenuItem("Shortlisted", Icons.star,
              () => onApplicationSubMenuSelected(
                  ApplicationSubMenu.shortlistedApplications)),
          _buildSubMenuItem("Interview", Icons.people,
              () => onApplicationSubMenuSelected(
                  ApplicationSubMenu.interviewApplications)),
          _buildSubMenuItem("Offered", Icons.celebration,
              () => onApplicationSubMenuSelected(
                  ApplicationSubMenu.offeredApplications)),
          _buildSubMenuItem("Rejected", Icons.cancel,
              () => onApplicationSubMenuSelected(
                  ApplicationSubMenu.rejectedApplications)),
        ],
      ),
    );
  }

  Widget _buildSubMenuItem(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: Colors.white70, size: 20),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        onTap: onTap,
        tileColor: Colors.transparent,
      ),
    );
  }
}