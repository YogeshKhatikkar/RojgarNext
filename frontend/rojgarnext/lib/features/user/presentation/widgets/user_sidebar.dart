// lib/features/user/presentation/widgets/user_sidebar.dart
// ============================================================
// USER SIDEBAR — Matches UserDashboard parameters exactly
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/features/user/presentation/utils/menu_types.dart';

class UserSidebar extends StatefulWidget {
  final UserMenuType selectedMenu;
  final JobSubMenu selectedJobSubMenu;
  final ApplicationSubMenu selectedAppSubMenu;
  final ServiceSubMenu selectedServiceSubMenu;
  final ResumeSubMenu selectedResumeSubMenu;
  final AISubMenu selectedAISubMenu;
  final ProfileSubMenu selectedProfileSubMenu;
  final SettingsSubMenu selectedSettingsSubMenu;

  final Function(UserMenuType) onMenuSelected;
  final Function(JobSubMenu) onJobSubMenuSelected;
  final Function(ApplicationSubMenu) onApplicationSubMenuSelected;
  final Function(ServiceSubMenu) onServiceSubMenuSelected;
  final Function(ResumeSubMenu) onResumeSubMenuSelected;
  final Function(AISubMenu) onAISubMenuSelected;
  final Function(ProfileSubMenu) onProfileSubMenuSelected;
  final Function(SettingsSubMenu) onSettingsSubMenuSelected;

  const UserSidebar({
    super.key,
    required this.selectedMenu,
    required this.selectedJobSubMenu,
    required this.selectedAppSubMenu,
    required this.selectedServiceSubMenu,
    required this.selectedResumeSubMenu,
    required this.selectedAISubMenu,
    required this.selectedProfileSubMenu,
    required this.selectedSettingsSubMenu,
    required this.onMenuSelected,
    required this.onJobSubMenuSelected,
    required this.onApplicationSubMenuSelected,
    required this.onServiceSubMenuSelected,
    required this.onResumeSubMenuSelected,
    required this.onAISubMenuSelected,
    required this.onProfileSubMenuSelected,
    required this.onSettingsSubMenuSelected,
  });

  @override
  State<UserSidebar> createState() => _UserSidebarState();
}

class _UserSidebarState extends State<UserSidebar> {
  static const Color _primary = Color(0xFF6C63FF);
  static const Color _pink = Color(0xFFFF6588);

  bool _jobsExpanded = false;
  bool _appsExpanded = false;
  bool _servicesExpanded = false;
  bool _resumeExpanded = false;
  bool _aiExpanded = false;
  bool _profileExpanded = false;
  bool _settingsExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncExpansion();
  }

  @override
  void didUpdateWidget(covariant UserSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMenu != oldWidget.selectedMenu) {
      _syncExpansion();
    }
  }

  void _syncExpansion() {
    _jobsExpanded = widget.selectedMenu == UserMenuType.jobs;
    _appsExpanded = widget.selectedMenu == UserMenuType.applications;
    _servicesExpanded = widget.selectedMenu == UserMenuType.services;
    _resumeExpanded = widget.selectedMenu == UserMenuType.resume;
    _aiExpanded = widget.selectedMenu == UserMenuType.ai;
    _profileExpanded = widget.selectedMenu == UserMenuType.profile;
    _settingsExpanded = widget.selectedMenu == UserMenuType.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 30),
            // ---- Header ----
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _pink]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                size: 42,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "User Panel",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),

            // ---- Menu Items ----
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildMenuItem(
                    "Dashboard",
                    Icons.dashboard_rounded,
                    UserMenuType.dashboard,
                  ),

                  // Jobs
                  _buildExpandable(
                    title: "Jobs",
                    icon: Icons.work_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.jobs,
                    isExpanded: _jobsExpanded,
                    onToggle: () =>
                        setState(() => _jobsExpanded = !_jobsExpanded),
                    children: [
                      _buildSubItem(
                        "Browse Jobs",
                        Icons.search_rounded,
                        widget.selectedJobSubMenu == JobSubMenu.browseJobs,
                        () => widget
                            .onJobSubMenuSelected(JobSubMenu.browseJobs),
                      ),
                      _buildSubItem(
                        "Saved Jobs",
                        Icons.bookmark_rounded,
                        widget.selectedJobSubMenu == JobSubMenu.savedJobs,
                        () => widget
                            .onJobSubMenuSelected(JobSubMenu.savedJobs),
                      ),
                    ],
                  ),

                  // Applications
                  _buildExpandable(
                    title: "Applications",
                    icon: Icons.assignment_rounded,
                    isSelected:
                        widget.selectedMenu == UserMenuType.applications,
                    isExpanded: _appsExpanded,
                    onToggle: () =>
                        setState(() => _appsExpanded = !_appsExpanded),
                    children: [
                      _buildSubItem(
                        "Job Applications",
                        Icons.work_rounded,
                        widget.selectedAppSubMenu ==
                            ApplicationSubMenu.jobApplications,
                        () => widget.onApplicationSubMenuSelected(
                            ApplicationSubMenu.jobApplications),
                      ),
                    ],
                  ),

                  // Services
                  _buildExpandable(
                    title: "Services",
                    icon: Icons.workspace_premium_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.services,
                    isExpanded: _servicesExpanded,
                    onToggle: () => setState(
                        () => _servicesExpanded = !_servicesExpanded),
                    children: [
                      _buildSubItem(
                        "Browse Services",
                        Icons.grid_view_rounded,
                        widget.selectedServiceSubMenu ==
                            ServiceSubMenu.browseServices,
                        () => widget.onServiceSubMenuSelected(
                            ServiceSubMenu.browseServices),
                      ),
                      _buildSubItem(
                        "My Applications",
                        Icons.list_alt_rounded,
                        widget.selectedServiceSubMenu ==
                            ServiceSubMenu.myApplications,
                        () => widget.onServiceSubMenuSelected(
                            ServiceSubMenu.myApplications),
                      ),
                    ],
                  ),

                  // Resume
                  _buildExpandable(
                    title: "Resume",
                    icon: Icons.description_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.resume,
                    isExpanded: _resumeExpanded,
                    onToggle: () =>
                        setState(() => _resumeExpanded = !_resumeExpanded),
                    children: [
                      _buildSubItem(
                        "Build Resume",
                        Icons.build_rounded,
                        widget.selectedResumeSubMenu ==
                            ResumeSubMenu.buildResume,
                        () => widget.onResumeSubMenuSelected(
                            ResumeSubMenu.buildResume),
                      ),
                      _buildSubItem(
                        "View Resume",
                        Icons.visibility_rounded,
                        widget.selectedResumeSubMenu ==
                            ResumeSubMenu.viewResume,
                        () => widget.onResumeSubMenuSelected(
                            ResumeSubMenu.viewResume),
                      ),
                      _buildSubItem(
                        "ATS Score",
                        Icons.score_rounded,
                        widget.selectedResumeSubMenu ==
                            ResumeSubMenu.atsScore,
                        () => widget.onResumeSubMenuSelected(
                            ResumeSubMenu.atsScore),
                      ),
                      _buildSubItem(
                        "AI Generator",
                        Icons.auto_awesome_rounded,
                        widget.selectedResumeSubMenu ==
                            ResumeSubMenu.aiGenerator,
                        () => widget.onResumeSubMenuSelected(
                            ResumeSubMenu.aiGenerator),
                      ),
                    ],
                  ),

                  // AI
                  _buildExpandable(
                    title: "AI Insights",
                    icon: Icons.auto_awesome_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.ai,
                    isExpanded: _aiExpanded,
                    onToggle: () =>
                        setState(() => _aiExpanded = !_aiExpanded),
                    children: [
                      _buildSubItem(
                        "Dashboard",
                        Icons.dashboard_rounded,
                        widget.selectedAISubMenu == AISubMenu.dashboard,
                        () =>
                            widget.onAISubMenuSelected(AISubMenu.dashboard),
                      ),
                      _buildSubItem(
                        "Career Roadmap",
                        Icons.map_rounded,
                        widget.selectedAISubMenu == AISubMenu.careerRoadmap,
                        () => widget.onAISubMenuSelected(
                            AISubMenu.careerRoadmap),
                      ),
                    ],
                  ),

                  // Profile
                  _buildExpandable(
                    title: "Profile",
                    icon: Icons.person_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.profile,
                    isExpanded: _profileExpanded,
                    onToggle: () =>
                        setState(() => _profileExpanded = !_profileExpanded),
                    children: [
                      _buildSubItem(
                        "Basic Details",
                        Icons.info_rounded,
                        widget.selectedProfileSubMenu ==
                            ProfileSubMenu.basicDetails,
                        () => widget.onProfileSubMenuSelected(
                            ProfileSubMenu.basicDetails),
                      ),
                      _buildSubItem(
                        "Education",
                        Icons.school_rounded,
                        widget.selectedProfileSubMenu ==
                            ProfileSubMenu.education,
                        () => widget.onProfileSubMenuSelected(
                            ProfileSubMenu.education),
                      ),
                      _buildSubItem(
                        "Experience",
                        Icons.work_history_rounded,
                        widget.selectedProfileSubMenu ==
                            ProfileSubMenu.experience,
                        () => widget.onProfileSubMenuSelected(
                            ProfileSubMenu.experience),
                      ),
                      _buildSubItem(
                        "Advanced Details",
                        Icons.tune_rounded,
                        widget.selectedProfileSubMenu ==
                            ProfileSubMenu.advancedDetails,
                        () => widget.onProfileSubMenuSelected(
                            ProfileSubMenu.advancedDetails),
                      ),
                      _buildSubItem(
                        "Documents",
                        Icons.folder_rounded,
                        widget.selectedProfileSubMenu ==
                            ProfileSubMenu.documents,
                        () => widget.onProfileSubMenuSelected(
                            ProfileSubMenu.documents),
                      ),
                    ],
                  ),

                  // Support (leaf)
                  _buildMenuItem(
                    "Support",
                    Icons.support_agent_rounded,
                    UserMenuType.support,
                  ),

                  // Settings
                  _buildExpandable(
                    title: "Settings",
                    icon: Icons.settings_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.settings,
                    isExpanded: _settingsExpanded,
                    onToggle: () => setState(
                        () => _settingsExpanded = !_settingsExpanded),
                    children: [
                      _buildSubItem(
                        "Change Password",
                        Icons.lock_rounded,
                        widget.selectedSettingsSubMenu ==
                            SettingsSubMenu.changePassword,
                        () => widget.onSettingsSubMenuSelected(
                            SettingsSubMenu.changePassword),
                      ),
                      _buildSubItem(
                        "Setup MPIN",
                        Icons.pin_rounded,
                        widget.selectedSettingsSubMenu ==
                            SettingsSubMenu.setupMpin,
                        () => widget.onSettingsSubMenuSelected(
                            SettingsSubMenu.setupMpin),
                      ),
                      _buildSubItem(
                        "Fingerprint",
                        Icons.fingerprint_rounded,
                        widget.selectedSettingsSubMenu ==
                            SettingsSubMenu.fingerprint,
                        () => widget.onSettingsSubMenuSelected(
                            SettingsSubMenu.fingerprint),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Logout
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await SecureStorage.logout();
                  if (context.mounted) {
                    context.go(AppRoutes.home);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SIMPLE MENU ITEM (leaf)
  // ------------------------------------------------------------
  Widget _buildMenuItem(String title, IconData icon, UserMenuType menu) {
    final isSelected = widget.selectedMenu == menu;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onMenuSelected(menu),
          splashColor: Colors.white.withOpacity(0.08),
          highlightColor: Colors.white.withOpacity(0.04),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(colors: [_primary, _pink])
                  : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _primary.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EXPANDABLE MENU
  // ------------------------------------------------------------
  Widget _buildExpandable({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? _primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onToggle,
                splashColor: Colors.white.withOpacity(0.08),
                highlightColor: Colors.white.withOpacity(0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? _primary : Colors.white70,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? _primary : Colors.white70,
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isSelected ? _primary : Colors.white70,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SUB MENU ITEM
  // ------------------------------------------------------------
  Widget _buildSubItem(
    String title,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.08),
        highlightColor: Colors.white.withOpacity(0.04),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                isActive ? _primary.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(
                    color: _primary.withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? _primary : Colors.white54,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive ? _primary : Colors.white54,
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}