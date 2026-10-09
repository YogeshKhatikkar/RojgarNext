// lib/features/user/presentation/utils/menu_types.dart
// ============================================================
// USER MENU TYPES — All enums used by UserSidebar & UserDashboard
// ============================================================
// ⚠️ IMPORTANT: These names MUST match exactly what the sidebar
//    and dashboard reference. Currently they use:
//      - ServiceSubMenu   (singular)
//      - ApplicationSubMenu
//      - JobSubMenu
//      - ResumeSubMenu
//      - AISubMenu
//      - ProfileSubMenu
//      - SettingsSubMenu
// ============================================================

/// Top-level menu items shown in the sidebar
enum UserMenuType {
  dashboard,
  jobs,
  applications,
  services,
  resume,
  ai,
  profile,
  support,
  settings,
}

/// Sub-menu items for "Jobs" parent
enum JobSubMenu {
  browseJobs,
  savedJobs,
}

/// Sub-menu items for "Applications" parent
enum ApplicationSubMenu {
  jobApplications,
  // add more here if you expand later
}

/// ✅ Sub-menu items for "Services" parent — SINGULAR name
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