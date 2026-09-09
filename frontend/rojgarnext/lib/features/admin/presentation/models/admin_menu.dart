// lib/features/admin/presentation/models/admin_menu.dart
enum AdminMenuType {
  dashboard,
  jobManagement,
  applicationManagement,
  manageUsers,
  reports,
  settings,
}

enum JobSubMenu { allJobs, addNewJob }

enum ApplicationSubMenu {
  allApplications, // Add this at the beginning
  pendingApplications,
  shortlistedApplications,
  interviewApplications,
  offeredApplications,
  rejectedApplications,
}
