// lib/features/customadmin/presentation/widgets/customadmin_sidebar.dart
// ✅ COMPLETE UPDATED VERSION - FIXED ListTile Warning

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import '../screens/customadmin_dashboard.dart';

class CustomAdminSidebar extends StatelessWidget {
  final CustomAdminMenu selectedMenu;
  final JobSubMenu selectedJobSubMenu;
  final ApplicationSubMenu selectedAppSubMenu;
  final Function(CustomAdminMenu) onMenuSelected;
  final Function(JobSubMenu) onJobSubMenuSelected;
  final Function(ApplicationSubMenu) onApplicationSubMenuSelected;

  const CustomAdminSidebar({
    super.key,
    required this.selectedMenu,
    required this.selectedJobSubMenu,
    required this.selectedAppSubMenu,
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
              "Custom Admin Panel",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Full Access Admin",
              style: TextStyle(color: Colors.blueAccent, fontSize: 12),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildMenuItem("Dashboard", Icons.dashboard,
                      CustomAdminMenu.dashboard),
                  _buildJobManagementMenu(),
                  _buildApplicationManagementMenu(),
                  _buildMenuItem("Reports", Icons.bar_chart,
                      CustomAdminMenu.reports),
                  _buildMenuItem("Pending Payments", Icons.payment,
                      CustomAdminMenu.pendingPayments),
                  _buildMenuItem("Settings", Icons.settings,
                      CustomAdminMenu.settings),
                ],
              ),
            ),
            const Divider(color: Colors.grey, height: 1),
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

  Widget _buildMenuItem(String title, IconData icon, CustomAdminMenu menu) {
    final isSelected = selectedMenu == menu;
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
        onTap: () => onMenuSelected(menu),
        tileColor: Colors.transparent,
      ),
    );
  }

  Widget _buildJobManagementMenu() {
    final isSelected = selectedMenu == CustomAdminMenu.jobManagement;
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
          _buildSubMenuItem("All Jobs", Icons.list, () => onJobSubMenuSelected(JobSubMenu.allJobs)),
          _buildSubMenuItem("Add New Job", Icons.add, () => onJobSubMenuSelected(JobSubMenu.addNewJob)),
        ],
      ),
    );
  }

  Widget _buildApplicationManagementMenu() {
    final isSelected = selectedMenu == CustomAdminMenu.applicationManagement;
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
          _buildSubMenuItem(
            "Job Applications",
            Icons.work,
            () => onApplicationSubMenuSelected(ApplicationSubMenu.jobApplications),
          ),
          _buildSubMenuItem(
            "Service Applications",
            Icons.workspace_premium,
            () => onApplicationSubMenuSelected(ApplicationSubMenu.serviceApplications),
          ),
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