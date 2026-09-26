// lib/features/customadmin/presentation/screens/customadmin_dashboard.dart
// ✅ COMPLETE UPDATED VERSION
// ✅ REMOVED: Reports menu handling
// ✅ REMOVED: Pending Payments menu handling
// ✅ PRESERVED: Settings submenu (Change Password, Setup MPIN, Fingerprint)
// ✅ All original functionality preserved

import 'package:flutter/material.dart';
import 'package:rojgarnext/features/customadmin/presentation/widgets/customadmin_sidebar.dart';
import 'package:rojgarnext/features/notification/widgets/notification_bell.dart';
import 'package:rojgarnext/features/customadmin/data/customadmin_service.dart';
import 'package:rojgarnext/features/common/widgets/location_display.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/candidate_profile_screen.dart';

// ==================== UNIFIED SCREENS ====================
import 'package:rojgarnext/features/jobs/presentation/screens/add_job_screen.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/show_jobs_screen.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/applications_screen.dart';

// ✅ SERVICE SCREEN IMPORT
import 'package:rojgarnext/features/services/presentation/screens/service_application_screen.dart';

// ✅ AUTH SCREENS IMPORT - Same as User Dashboard
import 'package:rojgarnext/features/auth/presentation/screens/change_password_screen.dart';
import 'package:rojgarnext/features/auth/presentation/screens/mpin_setup_page.dart';
import 'package:rojgarnext/features/auth/presentation/screens/fingerprint_setup_page.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';

// ❌ REMOVED IMPORTS:
// - admin_reports_screen.dart (Reports removed)
// - pending_payments_screen.dart (Pending Payments removed)

// ===============================================================

enum CustomAdminMenu {
  dashboard,
  jobManagement,
  applicationManagement,
  settings,
  // ❌ REMOVED: reports
  // ❌ REMOVED: pendingPayments
}

enum JobSubMenu { allJobs, addNewJob }

enum ApplicationSubMenu {
  jobApplications,
  serviceApplications,
}

// ✅ Settings SubMenu
enum SettingsSubMenu {
  changePassword,
  setupMpin,
  fingerprint,
}

class CustomAdminDashboard extends StatefulWidget {
  const CustomAdminDashboard({super.key});

  @override
  State<CustomAdminDashboard> createState() => _CustomAdminDashboardState();
}

class _CustomAdminDashboardState extends State<CustomAdminDashboard> {
  CustomAdminMenu selectedMenu = CustomAdminMenu.dashboard;
  JobSubMenu selectedJobSubMenu = JobSubMenu.allJobs;
  ApplicationSubMenu selectedAppSubMenu = ApplicationSubMenu.jobApplications;
  SettingsSubMenu selectedSettingsSubMenu = SettingsSubMenu.changePassword;

  Map<String, dynamic>? _dashboardStats;
  bool _isLoading = true;
  String? _adminEmail;

  // For candidate profile viewing
  bool _showCandidateProfile = false;
  String? _candidateEmail;
  String? _candidateName;

  // ==================== DRAWER STATE ====================
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadAdminEmail();
    _loadDashboardStats();
  }

  Future<void> _loadAdminEmail() async {
    final email = await SecureStorage.getEmail();
    if (mounted) {
      setState(() {
        _adminEmail = email;
      });
      debugPrint("📧 CustomAdmin Email loaded: $_adminEmail");
    }
  }

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final stats = await CustomAdminService.getStats();
      if (mounted) {
        setState(() {
          _dashboardStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _refreshDashboard() {
    _loadDashboardStats();
  }

  void _showCandidateProfileFromApplication(Map<String, dynamic> application) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    setState(() {
      _candidateEmail = application['applicant_email'];
      _candidateName = application['applicant_name'] ?? 'Candidate';
      _showCandidateProfile = true;
    });
  }

  void _closeCandidateProfile() {
    setState(() {
      _showCandidateProfile = false;
      _candidateEmail = null;
      _candidateName = null;
    });
  }

  // ==================== NOTIFICATION NAVIGATION METHODS ====================

  void _navigateToJobsFromNotification() {
    debugPrint("🔔 CUSTOM ADMIN: Navigating to Job Management > All Jobs");
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _closeCandidateProfile();
        setState(() {
          selectedMenu = CustomAdminMenu.jobManagement;
          selectedJobSubMenu = JobSubMenu.allJobs;
          _showCandidateProfile = false;
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
        "🔔 CUSTOM ADMIN: Navigating to Application Management > Service Applications");
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _closeCandidateProfile();
        setState(() {
          selectedMenu = CustomAdminMenu.applicationManagement;
          selectedAppSubMenu = ApplicationSubMenu.serviceApplications;
          _showCandidateProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📋 Navigating to Service Applications..."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // ==================== MENU SELECTION WITH DRAWER CLOSE ====================

  void _onMenuSelected(CustomAdminMenu menu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = menu;
          _showCandidateProfile = false;
          if (menu == CustomAdminMenu.settings) {
            selectedSettingsSubMenu = SettingsSubMenu.changePassword;
          }
        });
      }
    });
  }

  void _onJobSubMenuSelected(JobSubMenu subMenu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = CustomAdminMenu.jobManagement;
          selectedJobSubMenu = subMenu;
          _showCandidateProfile = false;
        });
      }
    });
  }

  void _onApplicationSubMenuSelected(ApplicationSubMenu subMenu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = CustomAdminMenu.applicationManagement;
          selectedAppSubMenu = subMenu;
          _showCandidateProfile = false;
        });
      }
    });
  }

  void _onSettingsSubMenuSelected(SettingsSubMenu subMenu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = CustomAdminMenu.settings;
          selectedSettingsSubMenu = subMenu;
          _showCandidateProfile = false;
        });
      }
    });
  }

  // ============================================================
  // GET SETTINGS SCREEN BASED ON SUBMENU
  // Same screens as User Dashboard (Auth folder)
  // ============================================================
  Widget _getSettingsScreen() {
    switch (selectedSettingsSubMenu) {
      case SettingsSubMenu.changePassword:
        return const ChangePasswordScreen(
          isForgotFlow: false,
          isEmbedded: true,
        );

      case SettingsSubMenu.setupMpin:
        if (_adminEmail == null || _adminEmail!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Loading email..."),
              ],
            ),
          );
        }
        return MpinSetupPage(email: _adminEmail!);

      case SettingsSubMenu.fingerprint:
        if (_adminEmail == null || _adminEmail!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Loading email..."),
              ],
            ),
          );
        }
        return FingerprintSetupPage(email: _adminEmail!);
    }
  }

  Widget _getContent() {
    if (_showCandidateProfile && _candidateEmail != null) {
      return CandidateProfileScreen(
        email: _candidateEmail!,
        candidateName: _candidateName ?? 'Candidate',
        onBack: _closeCandidateProfile,
      );
    }

    switch (selectedMenu) {
      case CustomAdminMenu.dashboard:
        return _buildDashboardContent();

      case CustomAdminMenu.jobManagement:
        if (selectedJobSubMenu == JobSubMenu.addNewJob) {
          return AddJobScreen(
            adminRole: 'customadmin',
            onJobAdded: _refreshDashboard,
          );
        }
        return ShowJobsScreen(
          adminRole: 'customadmin',
          onJobDeleted: _refreshDashboard,
          onJobUpdated: _refreshDashboard,
        );

      case CustomAdminMenu.applicationManagement:
        if (selectedAppSubMenu == ApplicationSubMenu.jobApplications) {
          return ApplicationsScreen(
            adminRole: 'customadmin',
            filterStatus: 'all',
            onViewCandidateProfile: _showCandidateProfileFromApplication,
          );
        } else if (selectedAppSubMenu ==
            ApplicationSubMenu.serviceApplications) {
          return const ServiceApplicationScreen();
        }
        return ApplicationsScreen(
          adminRole: 'customadmin',
          filterStatus: 'all',
          onViewCandidateProfile: _showCandidateProfileFromApplication,
        );

      // ❌ REMOVED: Reports case
      // ❌ REMOVED: Pending Payments case

      case CustomAdminMenu.settings:
        return _getSettingsScreen();
    }
  }

  // ==================== DASHBOARD CONTENT ====================

  Widget _buildDashboardContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final stats = _dashboardStats;
    final topJobs = stats?['top_jobs'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
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
                      const Text(
                        "Welcome, Custom Admin",
                        style: TextStyle(
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

          // Stats Row 1
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total Jobs",
                  stats?['total_jobs']?.toString() ?? "0",
                  Icons.work,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Applications",
                  stats?['total_applications']?.toString() ?? "0",
                  Icons.assignment,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Pending",
                  stats?['pending_applications']?.toString() ?? "0",
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats Row 2
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Shortlisted",
                  stats?['shortlisted_applications']?.toString() ?? "0",
                  Icons.star,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Interview",
                  stats?['interview_applications']?.toString() ?? "0",
                  Icons.people,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Offered",
                  stats?['offered_applications']?.toString() ?? "0",
                  Icons.celebration,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats Row 3
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Rejected",
                  stats?['rejected_applications']?.toString() ?? "0",
                  Icons.cancel,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Avg AI Match",
                  "${stats?['avg_match_score'] ?? 0}%",
                  Icons.auto_awesome,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Recent (7d)",
                  stats?['recent_applications_7d']?.toString() ?? "0",
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top Jobs
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
                            child:
                                const Icon(Icons.work, color: Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              job['title']?.toString() ?? 'Job',
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
                              "${job['applications'] ?? 0} apps",
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

          // Quick Actions
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
                          if (_scaffoldKey.currentState?.isDrawerOpen ==
                              true) {
                            Navigator.of(context).pop();
                          }
                          Future.delayed(
                              const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() {
                                selectedMenu = CustomAdminMenu.jobManagement;
                                selectedJobSubMenu = JobSubMenu.addNewJob;
                                _showCandidateProfile = false;
                              });
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        "View Job Applications",
                        Icons.list_alt,
                        Colors.blue,
                        () {
                          if (_scaffoldKey.currentState?.isDrawerOpen ==
                              true) {
                            Navigator.of(context).pop();
                          }
                          Future.delayed(
                              const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() {
                                selectedMenu =
                                    CustomAdminMenu.applicationManagement;
                                selectedAppSubMenu =
                                    ApplicationSubMenu.jobApplications;
                                _showCandidateProfile = false;
                              });
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        "View Service Apps",
                        Icons.workspace_premium,
                        Colors.purple,
                        () {
                          if (_scaffoldKey.currentState?.isDrawerOpen ==
                              true) {
                            Navigator.of(context).pop();
                          }
                          Future.delayed(
                              const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() {
                                selectedMenu =
                                    CustomAdminMenu.applicationManagement;
                                selectedAppSubMenu =
                                    ApplicationSubMenu.serviceApplications;
                                _showCandidateProfile = false;
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
    final isShowingProfile = _showCandidateProfile;

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              title: Text(isShowingProfile
                  ? "Candidate Profile"
                  : _getAppBarTitle()),
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
                        onPressed: () =>
                            Scaffold.of(context).openDrawer(),
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
      drawer: isMobile
          ? Drawer(
              child: CustomAdminSidebar(
                selectedMenu: selectedMenu,
                selectedJobSubMenu: selectedJobSubMenu,
                selectedAppSubMenu: selectedAppSubMenu,
                selectedSettingsSubMenu: selectedSettingsSubMenu,
                onMenuSelected: _onMenuSelected,
                onJobSubMenuSelected: _onJobSubMenuSelected,
                onApplicationSubMenuSelected:
                    _onApplicationSubMenuSelected,
                onSettingsSubMenuSelected: _onSettingsSubMenuSelected,
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            CustomAdminSidebar(
              selectedMenu: selectedMenu,
              selectedJobSubMenu: selectedJobSubMenu,
              selectedAppSubMenu: selectedAppSubMenu,
              selectedSettingsSubMenu: selectedSettingsSubMenu,
              onMenuSelected: _onMenuSelected,
              onJobSubMenuSelected: _onJobSubMenuSelected,
              onApplicationSubMenuSelected:
                  _onApplicationSubMenuSelected,
              onSettingsSubMenuSelected: _onSettingsSubMenuSelected,
            ),
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  if (!isMobile)
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
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isShowingProfile
                                ? "Candidate Profile: $_candidateName"
                                : _getAppBarTitle(),
                            style: const TextStyle(
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

  String _getAppBarTitle() {
    if (selectedMenu == CustomAdminMenu.settings) {
      switch (selectedSettingsSubMenu) {
        case SettingsSubMenu.changePassword:
          return "Change Password";
        case SettingsSubMenu.setupMpin:
          return "Setup MPIN";
        case SettingsSubMenu.fingerprint:
          return "Fingerprint Setup";
      }
    }
    return "Custom Admin Dashboard";
  }
}