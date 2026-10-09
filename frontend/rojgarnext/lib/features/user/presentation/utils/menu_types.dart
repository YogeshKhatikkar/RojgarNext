// lib/features/user/presentation/utils/menu_types.dart
// ============================================================
// USER MENU TYPES — All enums used by UserSidebar & UserDashboard
// ============================================================
// ✅ MODIFIED: jobApplications moved to JobSubMenu
// ✅ MODIFIED: savedJobs removed from JobSubMenu
// ============================================================

/// Top-level menu items shown in the sidebar
enum UserMenuType {
  dashboard,
  jobs,
  services,
  resume,
  ai,
  profile,
  support,
  settings,
  // ⬅️ REMOVED: applications (moved under jobs)
}

/// Sub-menu items for "Jobs" parent
enum JobSubMenu {
  browseJobs,
  jobApplications,
}

/// ✅ Kept for backward compatibility — currently only has jobApplications
/// (can be expanded later if you add a separate Applications menu)
enum ApplicationSubMenu {
  jobApplications,
}

/// Sub-menu items for "Services" parent
enum ServiceSubMenu {
  browseServices,
  myApplications,
}

/// Sub-menu items for "Resume" parent
enum ResumeSubMenu {
  buildResume,
  viewResume,
  atsScore,
  aiGenerator,
}

/// Sub-menu items for "AI" parent
enum AISubMenu {
  dashboard,
  careerRoadmap,
}

/// Sub-menu items for "Profile" parent
enum ProfileSubMenu {
  basicDetails,
  education,
  experience,
  advancedDetails,
  documents,
}

/// Sub-menu items for "Settings" parent
enum SettingsSubMenu {
  changePassword,
  setupMpin,
  fingerprint,
}