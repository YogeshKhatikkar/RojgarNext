// lib/features/admin/presentation/screens/admin_dashboard.dart
// COMPLETE WORKING VERSION WITH NOTIFICATION BELL
// ✅ Mobile Sidebar Auto-Hide Fix

import 'package:flutter/material.dart';
import 'package:rojgarnext/features/admin/presentation/widgets/admin_sidebar.dart';
import 'package:rojgarnext/features/admin/presentation/models/admin_menu.dart';
import 'package:rojgarnext/features/notification/widgets/notification_bell.dart';
import 'package:rojgarnext/features/common/widgets/location_display.dart';
import 'package:rojgarnext/features/admin/data/admin_service.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';

// Import screens
import 'package:rojgarnext/features/jobs/presentation/screens/add_job_screen.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/show_jobs_screen.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/applications_screen.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/candidate_profile_screen.dart';
import 'admin_users_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_settings_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminMenuType selectedMenu = AdminMenuType.dashboard;
  JobSubMenu selectedJobSubMenu = JobSubMenu.allJobs;
  ApplicationSubMenu selectedAppSubMenu = ApplicationSubMenu.allApplications;

  Map<String, dynamic> _dashboardStats = {};
  bool _isLoading = true;
  String _adminName = 'Admin';

  // For candidate profile viewing
  bool _showCandidateProfileView = false;
  String? _candidateEmail;
  String? _candidateName;

  // ==================== DRAWER STATE ====================
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadAdminName();
    _loadDashboardStats();
  }

  Future<void> _loadAdminName() async {
    final email = await SecureStorage.getEmail();
    if (email != null && email.isNotEmpty) {
      _adminName = email.split('@').first;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await AdminService.getAIDashboard();
      if (mounted) {
        setState(() {
          _dashboardStats = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCandidateProfileFromApplication(Map<String, dynamic> application) {
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    setState(() {
      _candidateEmail = application['applicant_email'];
      _candidateName = application['applicant_name'] ?? 'Candidate';
      _showCandidateProfileView = true;
    });
  }

  void _closeCandidateProfile() {
    setState(() {
      _showCandidateProfileView = false;
      _candidateEmail = null;
      _candidateName = null;
    });
  }

  // ==================== NOTIFICATION NAVIGATION METHODS ====================

  void _navigateToJobsFromNotification() {
    debugPrint("🔔 ADMIN: Navigating to Job Management > All Jobs");
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _closeCandidateProfile();
        setState(() {
          selectedMenu = AdminMenuType.jobManagement;
          selectedJobSubMenu = JobSubMenu.allJobs;
          _showCandidateProfileView = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📋 Navigating to Job Management > All Jobs..."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _navigateToApplicationsFromNotification() {
    debugPrint(
        "🔔 ADMIN: Navigating to Application Management > All Applications");
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _closeCandidateProfile();
        setState(() {
          selectedMenu = AdminMenuType.applicationManagement;
          selectedAppSubMenu = ApplicationSubMenu.allApplications;
          _showCandidateProfileView = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📋 Navigating to Application Management..."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _refreshDashboard() {
    _loadDashboardStats();
  }

  // ==================== MENU SELECTION WITH DRAWER CLOSE ====================

  void _onMenuSelected(AdminMenuType menu) {
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = menu;
          _showCandidateProfileView = false;
        });
      }
    });
  }

  void _onJobSubMenuSelected(JobSubMenu subMenu) {
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = AdminMenuType.jobManagement;
          selectedJobSubMenu = subMenu;
          _showCandidateProfileView = false;
        });
      }
    });
  }

  void _onApplicationSubMenuSelected(ApplicationSubMenu subMenu) {
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = AdminMenuType.applicationManagement;
          selectedAppSubMenu = subMenu;
          _showCandidateProfileView = false;
        });
      }
    });
  }

  Widget _getContent() {
    if (_showCandidateProfileView && _candidateEmail != null) {
      return CandidateProfileScreen(
        email: _candidateEmail!,
        candidateName: _candidateName ?? 'Candidate',
        onBack: _closeCandidateProfile,
      );
    }

    switch (selectedMenu) {
      case AdminMenuType.dashboard:
        return _buildDashboardContent();
      case AdminMenuType.jobManagement:
        if (selectedJobSubMenu == JobSubMenu.addNewJob) {
          return AddJobScreen(
            adminRole: 'admin',
            onJobAdded: _refreshDashboard,
          );
        }
        return ShowJobsScreen(
          adminRole: 'admin',
          onJobDeleted: _refreshDashboard,
          onJobUpdated: _refreshDashboard,
        );
      case AdminMenuType.applicationManagement:
        return ApplicationsScreen(
          adminRole: 'admin',
          filterStatus: _getFilterStatusFromSubMenu(),
          onViewCandidateProfile: _openCandidateProfileFromApplication,
        );
      case AdminMenuType.manageUsers:
        return const AdminUsersScreen();
      case AdminMenuType.reports:
        return const AdminReportsScreen();
      case AdminMenuType.settings:
        return const AdminSettingsScreen();
    }
  }

  String? _getFilterStatusFromSubMenu() {
    switch (selectedAppSubMenu) {
      case ApplicationSubMenu.allApplications:
        return 'all';
      case ApplicationSubMenu.pendingApplications:
        return 'pending';
      case ApplicationSubMenu.shortlistedApplications:
        return 'shortlisted';
      case ApplicationSubMenu.interviewApplications:
        return 'interview';
      case ApplicationSubMenu.offeredApplications:
        return 'offered';
      case ApplicationSubMenu.rejectedApplications:
        return 'rejected';
    }
  }

  // ==================== DASHBOARD CONTENT ====================

  Widget _buildDashboardContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final totalJobs = _dashboardStats['admin_jobs_count'] ?? 0;
    final totalApps = _dashboardStats['total_applications'] ?? 0;
    final pending = _dashboardStats['pending_applications'] ?? 0;
    final shortlisted = _dashboardStats['shortlisted_applications'] ?? 0;
    final interview = _dashboardStats['interview_applications'] ?? 0;
    final offered = _dashboardStats['offered_applications'] ?? 0;
    final rejected = _dashboardStats['rejected_applications'] ?? 0;
    final avgMatch = _dashboardStats['average_ai_match'] ?? 0;
    final recent7d = _dashboardStats['recent_applications_7d'] ?? 0;
    final topJobs = _dashboardStats['top_job_categories'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome, $_adminName!",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "Manage jobs, applications, and track your progress",
                        style: TextStyle(
                          color: Colors.white.withAlpha(217),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total Jobs",
                  totalJobs.toString(),
                  Icons.work,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Applications",
                  totalApps.toString(),
                  Icons.assignment,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Pending",
                  pending.toString(),
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Shortlisted",
                  shortlisted.toString(),
                  Icons.star,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Interview",
                  interview.toString(),
                  Icons.people,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Offered",
                  offered.toString(),
                  Icons.celebration,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Rejected",
                  rejected.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Avg AI Match",
                  "$avgMatch%",
                  Icons.auto_awesome,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Recent (7d)",
                  recent7d.toString(),
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Top Jobs by Applications",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (topJobs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        "No applications yet",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...topJobs.map(
                    (job) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.work, color: Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              job['category']?.toString() ?? 'Job',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${job['count'] ?? 0} apps",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Quick Actions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        "Add Job",
                        Icons.add_circle,
                        Colors.green,
                        () {
                          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                            Navigator.of(context).pop();
                          }
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() {
                                selectedMenu = AdminMenuType.jobManagement;
                                selectedJobSubMenu = JobSubMenu.addNewJob;
                                _showCandidateProfileView = false;
                              });
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        "View Applications",
                        Icons.list_alt,
                        Colors.blue,
                        () {
                          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                            Navigator.of(context).pop();
                          }
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() {
                                selectedMenu =
                                    AdminMenuType.applicationManagement;
                                selectedAppSubMenu =
                                    ApplicationSubMenu.allApplications;
                                _showCandidateProfileView = false;
                              });
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        "Reports",
                        Icons.bar_chart,
                        Colors.orange,
                        () {
                          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                            Navigator.of(context).pop();
                          }
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() {
                                selectedMenu = AdminMenuType.reports;
                                _showCandidateProfileView = false;
                              });
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MAIN BUILD ====================

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final isShowingProfile = _showCandidateProfileView;

    return Scaffold(
      key: _scaffoldKey, // ✅ Add key for drawer control
      appBar: isMobile
          ? AppBar(
              title: Text(
                  isShowingProfile ? "Candidate Profile" : "Admin Dashboard"),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              leading: isShowingProfile
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _closeCandidateProfile,
                    )
                  : Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
              actions: [
                const LocationDisplay(),
                NotificationBell(
                  onJobAlertClicked: _navigateToJobsFromNotification,
                  onApplicationStatusClicked:
                      _navigateToApplicationsFromNotification,
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      drawer: isMobile && !isShowingProfile
          ? Drawer(
              child: AdminSidebar(
                selectedMenu: selectedMenu,
                onMenuSelected: _onMenuSelected,
                onJobSubMenuSelected: _onJobSubMenuSelected,
                onApplicationSubMenuSelected: _onApplicationSubMenuSelected,
              ),
            )
          : null,
      body: Row(
        children: [
          // Desktop sidebar only
          if (!isMobile && !isShowingProfile)
            AdminSidebar(
              selectedMenu: selectedMenu,
              onMenuSelected: _onMenuSelected,
              onJobSubMenuSelected: _onJobSubMenuSelected,
              onApplicationSubMenuSelected: _onApplicationSubMenuSelected,
            ),
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  // Desktop top bar
                  if (!isMobile && !isShowingProfile)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Admin Panel",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          Row(
                            children: [
                              const LocationDisplay(),
                              NotificationBell(
                                onJobAlertClicked:
                                    _navigateToJobsFromNotification,
                                onApplicationStatusClicked:
                                    _navigateToApplicationsFromNotification,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (!isMobile && isShowingProfile)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.blueAccent),
                            onPressed: _closeCandidateProfile,
                            tooltip: "Back to Dashboard",
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Candidate Profile: $_candidateName",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              const LocationDisplay(),
                              NotificationBell(
                                onJobAlertClicked:
                                    _navigateToJobsFromNotification,
                                onApplicationStatusClicked:
                                    _navigateToApplicationsFromNotification,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _getContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}