// lib/features/jobs/presentation/screens/applications_screen.dart
// ✅ AI-BASED MODERN REDESIGN – Glassmorphism, Gradients, Animated Loading
// ✅ Preserves all original functionality (status updates, file uploads, payments, profile navigation)
// ✅ NEW: Two SEPARATE document sections:
//      1) ADMIN UPLOADED DOCUMENTS  → from Review / Final Submit buttons
//      2) USER UPLOADED DOCUMENTS   → uploaded by user for this application
// ✅ FIXED: Whitelist-only keys → deleted / null / stale docs NEVER show
// ✅ FIXED: /user/full-profile with email param is PRIMARY source (matches user side)
// ✅ FIXED: Admin viewing candidate docs now correctly fetches CANDIDATE documents (not admin's)
// ✅ FIXED: Payment Approve/Reject now uses application_id (not payment_id) - matches backend
// ✅ ENHANCED: Payment Verification section identical to Service Application Screen

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rojgarnext/core/widgets/file_viewer_screen.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'candidate_profile_screen.dart';

class ApplicationsScreen extends StatefulWidget {
  final String adminRole;
  final String? filterStatus;
  final Function(Map<String, dynamic>)? onViewCandidateProfile;

  const ApplicationsScreen({
    super.key,
    this.adminRole = 'admin',
    this.filterStatus,
    this.onViewCandidateProfile,
  });

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> applications = [];
  bool isLoading = true;
  String? _selectedFilter;
  Map<String, dynamic>? _selectedApplication;
  Map<String, dynamic>? _userProfile;
  String? _adminEmail;
  bool _isUpdatingStatus = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ============================================================
  // ✅ TWO SEPARATE DOCUMENT LISTS
  // ============================================================
  /// Documents uploaded by USER for this application
  /// (profile documents: Aadhaar, PAN, Resume, etc.)
  List<Map<String, dynamic>> _userDocuments = [];

  /// Documents uploaded by ADMIN via Review / Final Submit buttons
  /// (submitted_document_url + final_document_url)
  List<Map<String, dynamic>> _adminDocuments = [];

  bool _isLoadingDocuments = false;

  // ============================================================
  // ✅ COMPLETE Document Key Map — SAME as user_applications_screen
  // ============================================================
  static const List<Map<String, String>> _documentKeyMap = [
    // ==================== IDENTITY ====================
    {'key': 'profile_photo_url', 'label': 'Profile Photo'},
    {'key': 'aadhaar_front', 'label': 'Aadhaar Card (Front)'},
    {'key': 'aadhaar_back', 'label': 'Aadhaar Card (Back)'},
    {'key': 'aadhaar_url', 'label': 'Aadhaar Card'},
    {'key': 'pan_url', 'label': 'PAN Card'},
    {'key': 'passport_url', 'label': 'Passport'},
    {'key': 'voter_id_url', 'label': 'Voter ID'},
    {'key': 'driving_license_url', 'label': 'Driving License'},
    {'key': 'ration_card', 'label': 'Ration Card'},
    {'key': 'npr_card', 'label': 'NPR Card'},

    // ==================== EDUCATION ====================
    {'key': 'tenth_marksheet', 'label': '10th Marksheet'},
    {'key': 'tenth_certificate', 'label': '10th Certificate'},
    {'key': 'twelfth_marksheet', 'label': '12th Marksheet'},
    {'key': 'twelfth_certificate', 'label': '12th Certificate'},
    {'key': 'diploma_certificate', 'label': 'Diploma Certificate'},
    {'key': 'diploma_marksheet', 'label': 'Diploma Marksheet'},
    {'key': 'graduation_degree', 'label': 'Graduation Degree'},
    {'key': 'graduation_marksheet', 'label': 'Graduation Marksheet'},
    {'key': 'post_graduation_degree', 'label': 'Post Graduation Degree'},
    {'key': 'post_graduation_marksheet', 'label': 'Post Graduation Marksheet'},
    {'key': 'phd_certificate', 'label': 'PhD Certificate'},
    {'key': 'phd_thesis', 'label': 'PhD Thesis'},
    {'key': 'iti_certificate', 'label': 'ITI Certificate'},
    {'key': 'vocational_certificate', 'label': 'Vocational Training Certificate'},
    {'key': 'skill_development_certificate', 'label': 'Skill Development Certificate'},

    // ==================== PROFESSIONAL ====================
    {'key': 'resume_url', 'label': 'Resume / CV'},
    {'key': 'experience_certificate', 'label': 'Experience Certificate'},
    {'key': 'experience_letter_url', 'label': 'Experience Letter'},
    {'key': 'previous_employment_proof', 'label': 'Previous Employment Proof'},
    {'key': 'service_certificate', 'label': 'Service Certificate'},
    {'key': 'offer_letter_url', 'label': 'Offer Letter'},
    {'key': 'appointment_letter', 'label': 'Appointment Letter'},
    {'key': 'salary_slip_url', 'label': 'Salary Slip'},
    {'key': 'salary_certificate', 'label': 'Salary Certificate'},
    {'key': 'relieving_letter', 'label': 'Relieving Letter'},
    {'key': 'promotion_letter', 'label': 'Promotion Letter'},
    {'key': 'increment_letter', 'label': 'Increment Letter'},
    {'key': 'training_certificate', 'label': 'Training Certificate'},
    {'key': 'internship_certificate', 'label': 'Internship Certificate'},
    {'key': 'apprenticeship_certificate', 'label': 'Apprenticeship Certificate'},

    // ==================== CASTE ====================
    {'key': 'caste_certificate_general', 'label': 'Caste Certificate (General/UR)'},
    {'key': 'caste_certificate_obc', 'label': 'Caste Certificate (OBC)'},
    {'key': 'caste_certificate_sc', 'label': 'Caste Certificate (SC)'},
    {'key': 'caste_certificate_st', 'label': 'Caste Certificate (ST)'},
    {'key': 'caste_certificate_url', 'label': 'Caste Certificate'},
    {'key': 'ews_certificate', 'label': 'EWS Certificate'},
    {'key': 'non_creamy_layer', 'label': 'Non-Creamy Layer Certificate'},
    {'key': 'caste_validity', 'label': 'Caste Validity Certificate'},

    // ==================== DISABILITY ====================
    {'key': 'disability_certificate_url', 'label': 'Disability Certificate'},
    {'key': 'medical_certificate_physical', 'label': 'Medical Certificate (Physical)'},
    {'key': 'hearing_disability', 'label': 'Hearing Disability Certificate'},
    {'key': 'visual_disability', 'label': 'Visual Disability Certificate'},
    {'key': 'learning_disability', 'label': 'Learning Disability Certificate'},
    {'key': 'mental_disability', 'label': 'Mental Disability Certificate'},
    {'key': 'multiple_disability', 'label': 'Multiple Disability Certificate'},
    {'key': 'disability_id_card', 'label': 'Disability ID Card'},

    // ==================== INCOME ====================
    {'key': 'income_certificate_url', 'label': 'Income Certificate'},
    {'key': 'income_tax_return', 'label': 'Income Tax Return (ITR)'},
    {'key': 'form_16', 'label': 'Form 16'},
    {'key': 'bank_statement', 'label': 'Bank Passbook/Statement'},
    {'key': 'pension_certificate', 'label': 'Pension Certificate'},
    {'key': 'fd_certificate', 'label': 'Fixed Deposit Certificate'},

    // ==================== RESIDENCE ====================
    {'key': 'domicile_certificate', 'label': 'Domicile Certificate'},
    {'key': 'residence_certificate', 'label': 'Residence Certificate'},
    {'key': 'electricity_bill', 'label': 'Electricity Bill'},
    {'key': 'water_bill', 'label': 'Water Bill'},
    {'key': 'gas_bill', 'label': 'Gas Bill'},
    {'key': 'rent_agreement', 'label': 'Rent Agreement'},
    {'key': 'property_document', 'label': 'Property Document'},

    // ==================== FAMILY ====================
    {'key': 'birth_certificate', 'label': 'Birth Certificate'},
    {'key': 'marriage_certificate', 'label': 'Marriage Certificate'},
    {'key': 'family_member_id', 'label': 'Family Member ID'},
    {'key': 'dependent_certificate', 'label': 'Dependent Certificate'},
    {'key': 'family_pension', 'label': 'Family Pension Certificate'},
    {'key': 'survivor_certificate', 'label': 'Survivor Certificate'},

    // ==================== GOVERNMENT ====================
    {'key': 'job_seeker_registration', 'label': 'Job Seeker Registration'},
    {'key': 'employment_exchange_card', 'label': 'Employment Exchange Card'},
    {'key': 'ncs_id', 'label': 'National Career Service ID'},
    {'key': 'nrega_card', 'label': 'NREGA Job Card'},
    {'key': 'pmay_certificate', 'label': 'PMAY Certificate'},
    {'key': 'pmjjby_certificate', 'label': 'PMJJBY Certificate'},
    {'key': 'pmsby_certificate', 'label': 'PMSBY Certificate'},
    {'key': 'apy_enrollment', 'label': 'APY Enrollment'},

    // ==================== CERTIFICATIONS ====================
    {'key': 'professional_certification', 'label': 'Professional Certification'},
    {'key': 'skill_certificate', 'label': 'Skill Development Certificate'},
    {'key': 'computer_certificate', 'label': 'Computer Course Certificate'},
    {'key': 'language_certificate', 'label': 'Language Proficiency Certificate'},
    {'key': 'soft_skills_certificate', 'label': 'Soft Skills Certificate'},
    {'key': 'leadership_certificate', 'label': 'Leadership Certificate'},
    {'key': 'project_management_certificate', 'label': 'Project Management Certificate'},
    {'key': 'digital_marketing_certificate', 'label': 'Digital Marketing Certificate'},
    {'key': 'data_science_certificate', 'label': 'Data Science Certificate'},
    {'key': 'cloud_computing_certificate', 'label': 'Cloud Computing Certificate'},
    {'key': 'cybersecurity_certificate', 'label': 'Cybersecurity Certificate'},

    // ==================== MISCELLANEOUS ====================
    {'key': 'gap_certificate', 'label': 'Gap Certificate'},
    {'key': 'skip_certificate', 'label': 'Skip Certificate'},
    {'key': 'skip_year_certificate', 'label': 'Skip Year Certificate'},
    {'key': 'education_gap_certificate', 'label': 'Education Gap Certificate'},
    {'key': 'character_certificate', 'label': 'Character Certificate'},
    {'key': 'migration_certificate', 'label': 'Migration Certificate'},
    {'key': 'transfer_certificate', 'label': 'Transfer Certificate'},
    {'key': 'bonafide_certificate', 'label': 'Bonafide Certificate'},
    {'key': 'conduct_certificate', 'label': 'Conduct Certificate'},
    {'key': 'medical_fitness_certificate', 'label': 'Medical Fitness Certificate'},
    {'key': 'antecedent_certificate', 'label': 'Antecedent Certificate'},
    {'key': 'noc_certificate', 'label': 'No Objection Certificate (NOC)'},
    {'key': 'other_document_url', 'label': 'Other Document'},
  ];

  // Filter buttons
  final List<Map<String, dynamic>> _filterButtons = [
    {'value': 'all', 'label': 'All', 'icon': Icons.list, 'color': Colors.grey},
    {'value': 'pending', 'label': 'Pending', 'icon': Icons.hourglass_empty, 'color': Colors.orange},
    {'value': 'pending_verification', 'label': 'Pending Pay', 'icon': Icons.payment, 'color': Colors.purple},
    {'value': 'shortlisted', 'label': 'Shortlisted', 'icon': Icons.star, 'color': Colors.blue},
    {'value': 'interview', 'label': 'Interview', 'icon': Icons.people, 'color': Colors.purple},
    {'value': 'offered', 'label': 'Offer', 'icon': Icons.celebration, 'color': Colors.green},
    {'value': 'rejected', 'label': 'Reject', 'icon': Icons.cancel, 'color': Colors.red},
    {'value': 'verification_successful', 'label': 'Verified', 'icon': Icons.verified, 'color': Colors.teal},
    {'value': 'verification_rejected', 'label': 'Verif Reject', 'icon': Icons.cancel, 'color': Colors.deepOrange},
    {'value': 'update_application', 'label': 'Update Pending', 'icon': Icons.edit_note, 'color': Colors.blue},
  ];

  // Status buttons for updating
  final List<Map<String, dynamic>> _statusButtons = [
    {'value': 'pending', 'label': 'Pending', 'color': Colors.orange, 'icon': Icons.hourglass_empty},
    {'value': 'shortlisted', 'label': 'Shortlist', 'color': Colors.blue, 'icon': Icons.star},
    {'value': 'interview', 'label': 'Interview', 'color': Colors.purple, 'icon': Icons.people},
    {'value': 'offered', 'label': 'Offer', 'color': Colors.green, 'icon': Icons.celebration},
    {'value': 'review_application', 'label': 'Review', 'color': Colors.orange.shade700, 'icon': Icons.rate_review},
    {'value': 'final_submit', 'label': 'Final Submit', 'color': Colors.deepPurple, 'icon': Icons.send_and_archive},
  ];

  // ============================================================
  // ✅ ULTRA-STRICT document URL validator
  // ============================================================
  bool _isValidDocUrl(dynamic value) {
    if (value == null) return false;
    if (value is Map && value.isEmpty) return false;
    if (value is List && value.isEmpty) return false;

    final str = value.toString().trim();
    if (str.isEmpty) return false;

    final lower = str.toLowerCase();
    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == '-' ||
        lower == 'none' ||
        lower == 'false' ||
        lower == 'true' ||
        lower == '0' ||
        lower == 'not found' ||
        lower == 'notfound' ||
        lower == 'not_found' ||
        lower == 'deleted' ||
        lower == 'removed' ||
        lower == 'empty' ||
        lower == '{}' ||
        lower == '[]') {
      return false;
    }

    if (!str.startsWith('http://') &&
        !str.startsWith('https://') &&
        !str.startsWith('file:') &&
        !str.startsWith('blob:')) {
      return false;
    }

    if (str.length < 12) return false;

    if (lower.contains('not-found') ||
        lower.contains('notfound') ||
        lower.contains('placeholder') ||
        lower.contains('example.com/dummy') ||
        lower.contains('undefined')) {
      return false;
    }

    return true;
  }

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filterStatus ?? 'all';
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _getAdminEmail();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getApiBasePath() {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin';
      case 'superadmin':
        return '/superadmin';
      default:
        return '/admin';
    }
  }

  Future<void> _getAdminEmail() async {
    if (!mounted) return;
    try {
      final response = await DioClient.dio.get('/auth/me');
      if (!mounted) return;
      debugPrint("📧 Auth me response: ${response.data}");

      if (response.data is Map<String, dynamic>) {
        final data = response.data;
        if (data.containsKey('data') && data['data'] is Map) {
          _adminEmail = data['data']['email'];
        } else if (data.containsKey('email')) {
          _adminEmail = data['email'];
        }
      }

      debugPrint("📧 Admin email extracted: $_adminEmail");

      if (_adminEmail != null && _adminEmail!.isNotEmpty) {
        await _fetchApplications();
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          showMessage(context, "Could not get admin email", isError: true);
        }
      }
    } catch (e) {
      debugPrint("❌ Error getting admin email: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        showMessage(context, "Failed to get admin info: $e", isError: true);
      }
    }
  }

  Future<void> _fetchApplications() async {
    if (!mounted) return;
    if (_adminEmail == null || _adminEmail!.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      final basePath = _getApiBasePath();
      debugPrint("📧 Fetching applications for admin: $_adminEmail using $basePath");

      final jobsResponse = await DioClient.dio.get('$basePath/jobs');
      if (!mounted) return;
      List<dynamic> adminJobs = [];

      if (jobsResponse.data is Map) {
        final jobsData = jobsResponse.data;
        if (jobsData.containsKey('data') && jobsData['data'] is Map) {
          adminJobs = jobsData['data']['jobs'] ?? [];
        } else if (jobsData.containsKey('jobs')) {
          adminJobs = jobsData['jobs'] ?? [];
        } else {
          adminJobs = jobsData['data'] ?? [];
        }
      } else {
        adminJobs = jobsResponse.data ?? [];
      }

      debugPrint("📋 Admin jobs found: ${adminJobs.length}");

      final adminJobIds = adminJobs.map((job) => job['_id'].toString()).toSet();

      if (adminJobIds.isEmpty) {
        if (mounted) {
          setState(() {
            applications = [];
            isLoading = false;
          });
        }
        return;
      }

      final response = await DioClient.dio.get('$basePath/applications');
      if (!mounted) return;
      List<dynamic> allApps = [];

      if (response.data is Map) {
        final appsData = response.data;
        if (appsData.containsKey('data') && appsData['data'] is Map) {
          allApps = appsData['data']['applications'] ?? [];
        } else if (appsData.containsKey('applications')) {
          allApps = appsData['applications'] ?? [];
        } else {
          allApps = appsData['data'] ?? [];
        }
      } else {
        allApps = response.data ?? [];
      }

      applications = allApps.where((app) {
        final jobId = app['job_id']?.toString();
        return adminJobIds.contains(jobId);
      }).toList();

      debugPrint("📊 Filtered applications for admin: ${applications.length}");

      if (_selectedFilter != 'all') {
        applications = applications.where((app) {
          final status = app['status']?.toString().toLowerCase() ?? '';
          return status == _selectedFilter!.toLowerCase();
        }).toList();
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Error fetching applications: $e");
      showMessage(context, "Failed to load applications: $e", isError: true);
      applications = [];
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserProfile(String email) async {
    if (!mounted) return;
    try {
      debugPrint("📋 Fetching user profile for email: $email");
      final response = await DioClient.dio.get(
        '/user/full-profile?email=$email',
      );
      if (!mounted) return;
      if (response.data is Map) {
        final data = response.data;
        if (data.containsKey('data') && data['data'] is Map) {
          _userProfile = data['data'];
        } else {
          _userProfile = data;
        }
      }
      debugPrint("📋 User profile fetched: ${_userProfile?.keys}");
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  // ============================================================
  // ✅ FETCH USER (CANDIDATE) PROFILE DOCUMENTS — separated
  // ============================================================
  Future<void> _fetchUserDocuments(String email) async {
    if (!mounted) return;
    if (email.isEmpty) {
      debugPrint("⚠️ _fetchUserDocuments: empty email, skipping");
      return;
    }

    setState(() {
      _isLoadingDocuments = true;
      _userDocuments = [];
    });

    final List<Map<String, dynamic>> docs = [];

    void addDoc(String key, String label, dynamic value) {
      if (!_isValidDocUrl(value)) return;
      final url = value.toString().trim();
      if (docs.any((d) => d['url'] == url)) return;
      docs.add({
        'key': key,
        'label': label,
        'url': url,
        'is_application_doc': false,
        'source': 'user_profile',
      });
    }

    void processProfileMap(Map<String, dynamic> profile) {
      final additional = profile['additional_details'] as Map? ?? {};

      for (final entry in _documentKeyMap) {
        final key = entry['key']!;
        final label = entry['label']!;
        final value = additional[key] ?? profile[key];
        if (value != null) {
          addDoc(key, label, value);
        }
      }

      for (final key in ['resume_url', 'profile_photo_url']) {
        final v = profile[key];
        if (v != null) {
          addDoc(key, _labelForKey(key), v);
        }
      }
    }

    try {
      try {
        debugPrint("📄 Fetching candidate docs from /user/full-profile?email=$email");
        final res = await DioClient.dio.get(
          '/user/full-profile?email=$email',
        );

        if (res.data is Map) {
          Map<String, dynamic> profile = {};
          if (res.data.containsKey('data') && res.data['data'] is Map) {
            profile = Map<String, dynamic>.from(res.data['data']);
          } else {
            profile = Map<String, dynamic>.from(res.data);
          }
          processProfileMap(profile);
        }
      } catch (e) {
        debugPrint("⚠️ /user/full-profile?email=$email failed: $e");
      }

      if (docs.isEmpty) {
        try {
          debugPrint("📄 Fallback: /user/user-profile-by-email?email=$email");
          final res2 = await DioClient.dio.get(
            '/user/user-profile-by-email?email=$email',
          );

          if (res2.data is Map) {
            Map<String, dynamic> profile2 = {};
            if (res2.data.containsKey('data') && res2.data['data'] is Map) {
              profile2 = Map<String, dynamic>.from(res2.data['data']);
            } else {
              profile2 = Map<String, dynamic>.from(res2.data);
            }
            processProfileMap(profile2);
          }
        } catch (e) {
          debugPrint("⚠️ /user/user-profile-by-email fallback failed: $e");
        }
      }

      debugPrint("✅ Total USER documents collected: ${docs.length}");
    } catch (e) {
      debugPrint("❌ _fetchUserDocuments error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _userDocuments = docs;
          _isLoadingDocuments = false;
        });
      }
    }
  }

  // ============================================================
  // ✅ NEW: EXTRACT ADMIN-UPLOADED DOCUMENTS for a given application
  // Admin documents come ONLY from:
  //   1) submitted_document_url (Review button upload)
  //   2) final_document_url     (Final Submit button upload)
  // ============================================================
  List<Map<String, dynamic>> _getAdminDocumentsForApp(
      Map<String, dynamic> app) {
    final List<Map<String, dynamic>> list = [];

    // 1) Review document (Admin uploaded via Review)
    final submittedUrl = app['submitted_document_url'];
    if (_isValidDocUrl(submittedUrl)) {
      final urlStr = submittedUrl.toString().trim();
      if (!list.any((d) => d['url'] == urlStr)) {
        list.add({
          'key': 'submitted_document_url',
          'label': app['submitted_document_name']?.toString() ??
              'Review Document (Admin)',
          'url': urlStr,
          'download_url': app['submitted_document_download_url'],
          'source': 'admin_review',
          'is_admin_doc': true,
          'is_application_doc': true,
          'uploaded_at': app['submitted_at'],
          'uploaded_by': app['submitted_by'],
        });
      }
    }

    // 2) Final Submit document (Admin uploaded via Final Submit)
    final finalUrl = app['final_document_url'];
    if (_isValidDocUrl(finalUrl)) {
      final urlStr = finalUrl.toString().trim();
      if (!list.any((d) => d['url'] == urlStr)) {
        list.add({
          'key': 'final_document_url',
          'label': app['final_document_name']?.toString() ??
              'Final Submitted Document (Admin)',
          'url': urlStr,
          'download_url': app['final_document_download_url'],
          'source': 'admin_final',
          'is_admin_doc': true,
          'is_application_doc': true,
          'uploaded_at': app['final_submitted_at'],
          'uploaded_by': app['final_submitted_by'],
        });
      }
    }

    return list;
  }

  // ============================================================
  // ✅ EXTRACT USER-UPLOADED DOCUMENTS for a given application
  // (payment receipt + resume the user attached to this application)
  // ============================================================
  List<Map<String, dynamic>> _getUserApplicationDocsForApp(
      Map<String, dynamic> app) {
    final List<Map<String, dynamic>> list = [];

    // 1) Payment receipt (User uploaded)
    final receiptUrl = app['payment_receipt_url'];
    if (_isValidDocUrl(receiptUrl)) {
      final urlStr = receiptUrl.toString().trim();
      if (!list.any((d) => d['url'] == urlStr)) {
        list.add({
          'key': 'payment_receipt_url',
          'label': 'Payment Receipt (User)',
          'url': urlStr,
          'download_url': app['payment_receipt_download_url'],
          'source': 'user_application',
          'is_application_doc': true,
          'is_user_doc': true,
        });
      }
    }

    // 2) Resume attached to this application (User)
    final appResume = app['resume_url'];
    if (_isValidDocUrl(appResume)) {
      final urlStr = appResume.toString().trim();
      if (!list.any((d) => d['url'] == urlStr)) {
        list.add({
          'key': 'resume_url',
          'label': 'Resume (Application)',
          'url': urlStr,
          'source': 'user_application',
          'is_application_doc': true,
          'is_user_doc': true,
        });
      }
    }

    return list;
  }

  String _labelForKey(String key) {
    for (final entry in _documentKeyMap) {
      if (entry['key'] == key) return entry['label']!;
    }
    return key
        .replaceAll('_url', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ')
        .trim();
  }

  Future<void> _openDocumentViewer(
    String url, {
    String title = 'Document',
    String? downloadUrl,
    String? fileType,
  }) async {
    if (url.isEmpty) {
      showMessage(context, "Document URL not available", isError: true);
      return;
    }

    String finalUrl = url.trim();
    if (!finalUrl.startsWith('http') &&
        !finalUrl.startsWith('file') &&
        !finalUrl.startsWith('blob:')) {
      finalUrl = 'https://$finalUrl';
    }

    debugPrint("📄 Opening document viewer: $finalUrl");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.95,
          height: MediaQuery.of(dialogContext).size.height * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: FileViewerScreen(
            url: finalUrl,
            title: title,
            downloadUrl: downloadUrl ?? finalUrl,
            fileType: fileType,
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // ✅ SPLIT DOCUMENTS UI — Two distinct cards
  // ====================================================================
  Widget _buildDocumentsSection(Map<String, dynamic> app) {
    // Build separate lists
    final adminDocs = _getAdminDocumentsForApp(app);
    final userAppDocs = _getUserApplicationDocsForApp(app);

    // User docs = profile docs + user-attached application docs
    final allUserDocs = <Map<String, dynamic>>[];
    allUserDocs.addAll(userAppDocs);
    for (final d in _userDocuments) {
      final url = d['url']?.toString() ?? '';
      if (url.isEmpty) continue;
      if (allUserDocs.any((x) => x['url'] == url)) continue;
      allUserDocs.add(d);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------------
        // SECTION 1: ADMIN UPLOADED DOCUMENTS (Review / Final Submit)
        // ------------------------------------------------------------
        _buildAdminDocumentsCard(adminDocs),

        const SizedBox(height: 16),

        // ------------------------------------------------------------
        // SECTION 2: USER UPLOADED DOCUMENTS (for this application)
        // ------------------------------------------------------------
        _buildUserDocumentsCard(allUserDocs),
      ],
    );
  }

  // ====================================================================
  // ✅ ADMIN UPLOADED DOCUMENTS CARD
  // ====================================================================
  Widget _buildAdminDocumentsCard(List<Map<String, dynamic>> adminDocs) {
    final int count = adminDocs.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.purple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Admin Uploaded Documents",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Uploaded via Review / Final Submit",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$count ${count == 1 ? 'File' : 'Files'}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Body
            if (count == 0)
              _buildEmptyDocMessage(
                icon: Icons.folder_off,
                color: Colors.purple,
                message: "No admin documents uploaded yet",
                subMessage:
                    "Documents uploaded via Review or Final Submit will appear here",
              )
            else
              Column(
                children: adminDocs.asMap().entries.map((entry) {
                  return _buildAdminDocumentRow(entry.key, entry.value);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // ✅ USER UPLOADED DOCUMENTS CARD
  // ====================================================================
  Widget _buildUserDocumentsCard(List<Map<String, dynamic>> userDocs) {
    final int count = userDocs.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "User Uploaded Documents",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Uploaded by candidate for this application",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$count ${count == 1 ? 'File' : 'Files'}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Body
            if (_isLoadingDocuments)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (count == 0)
              _buildEmptyDocMessage(
                icon: Icons.folder_off,
                color: Colors.blue,
                message: "No user documents uploaded yet",
                subMessage: "Candidate has not uploaded any documents",
              )
            else
              Column(
                children: userDocs.asMap().entries.map((entry) {
                  return _buildUserDocumentRow(entry.key, entry.value);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // ✅ Empty state for documents
  // ====================================================================
  Widget _buildEmptyDocMessage({
    required IconData icon,
    required Color color,
    required String message,
    required String subMessage,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subMessage,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // ✅ ADMIN document row
  // ====================================================================
  Widget _buildAdminDocumentRow(int index, Map<String, dynamic> doc) {
    final String label = doc['label']?.toString() ?? 'Admin Document ${index + 1}';
    final String url = doc['url']?.toString() ?? '';
    final String? downloadUrl = doc['download_url']?.toString();
    final String? uploadedBy = doc['uploaded_by']?.toString();
    final dynamic uploadedAt = doc['uploaded_at'];

    final icon = _iconForUrl(url);
    final color = _colorForUrl(url);
    final fileType = _fileTypeForUrl(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "ADMIN",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      fileType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (uploadedBy != null && uploadedBy.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "By: $uploadedBy",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (uploadedAt != null) ...[
                  Text(
                    "At: ${_formatDateTimeShort(uploadedAt.toString())}",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.visibility, color: Colors.purple),
            tooltip: "View Admin Document",
            onPressed: () => _openDocumentViewer(
              url,
              title: label,
              downloadUrl: downloadUrl,
              fileType: fileType,
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // ✅ USER document row
  // ====================================================================
  Widget _buildUserDocumentRow(int index, Map<String, dynamic> doc) {
    final String label = doc['label']?.toString() ?? 'Document ${index + 1}';
    final String url = doc['url']?.toString() ?? '';
    final String? downloadUrl = doc['download_url']?.toString();
    final bool isAppDoc = doc['is_application_doc'] == true;

    final icon = _iconForUrl(url);
    final color = _colorForUrl(url);
    final fileType = _fileTypeForUrl(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAppDoc ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAppDoc ? Colors.blue.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isAppDoc)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "APPLICATION",
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    if (isAppDoc) const SizedBox(width: 6),
                    Text(
                      fileType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.visibility, color: Colors.blue),
            tooltip: "View",
            onPressed: () => _openDocumentViewer(
              url,
              title: label,
              downloadUrl: downloadUrl,
              fileType: fileType,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Helpers for icons/colors ----
  IconData _iconForUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.pdf') || u.contains('/raw/')) {
      return Icons.picture_as_pdf;
    }
    if (u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp') ||
        u.contains('.gif') ||
        u.contains('/image/')) {
      return Icons.image;
    }
    if (u.contains('.doc')) return Icons.description;
    if (u.contains('.xls')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Color _colorForUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.pdf') || u.contains('/raw/')) return Colors.red;
    if (u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp') ||
        u.contains('.gif') ||
        u.contains('/image/')) {
      return Colors.blue;
    }
    if (u.contains('.doc')) return Colors.indigo;
    if (u.contains('.xls')) return Colors.green;
    return Colors.blueGrey;
  }

  String _fileTypeForUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.pdf') || u.contains('/raw/')) return 'pdf';
    if (u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp') ||
        u.contains('.gif') ||
        u.contains('/image/')) {
      return 'image';
    }
    if (u.contains('.doc')) return 'word';
    if (u.contains('.xls')) return 'excel';
    return 'file';
  }

  // ==================== VIEW APPLICATION UPDATES DIALOG ====================
  void _showApplicationUpdatesDialog(Map<String, dynamic> application) {
    final updates = application['application_updates'];
    final updateNotes = application['update_notes'];
    final updateSubmittedAt = application['update_submitted_at'];
    final updateSubmittedBy = application['update_submitted_by'];
    final currentStatus = application['status'];

    if (updates == null || updates.isEmpty) {
      showMessage(context, "No updates found for this application",
          isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          constraints: BoxConstraints(
            maxWidth: 700,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade200,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.edit_note,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Application Updates",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Submitted by: $updateSubmittedBy",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                                  currentStatus ?? 'update_application')
                              .withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_note,
                              size: 16,
                              color: _getStatusColor(
                                  currentStatus ?? 'update_application'),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Status: ${currentStatus?.toUpperCase() ?? 'UPDATE PENDING'}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(
                                    currentStatus ?? 'update_application'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (updateSubmittedAt != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Submitted: ${_formatDateTime(updateSubmittedAt)}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (updateNotes != null && updateNotes.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.note,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Additional Notes:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                updateNotes,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      const Text(
                        "Updated Fields:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...updates.map((update) => _buildUpdateCard(update)),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Close"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> update) {
    final fieldName = update['field_name'] ?? '';
    final fieldValue = update['field_value'] ?? '';
    final submittedAt = update['submitted_at'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 16,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fieldName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              if (submittedAt != null)
                Text(
                  _formatDateTimeShort(submittedAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          const Divider(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.text_snippet,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fieldValue,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTimeShort(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  // ==================== REVIEW DIALOG ====================
  Future<void> _showReviewDialog(String applicationId) async {
    final TextEditingController notesController = TextEditingController();
    String? selectedFileName;
    Uint8List? selectedFileBytes;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ReviewDialogContent(
        notesController: notesController,
        onFileSelected: (name, bytes) {
          selectedFileName = name;
          selectedFileBytes = bytes;
        },
      ),
    );

    if (result == null) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final basePath = _getApiBasePath();
      final notes = notesController.text.trim();

      if (selectedFileBytes != null && selectedFileName != null) {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            selectedFileBytes!,
            filename: selectedFileName!,
          ),
          'notes': notes,
        });

        final uploadResponse = await DioClient.dio.post(
          '$basePath/applications/$applicationId/submit-document',
          data: formData,
          options: Options(
            headers: {"Content-Type": "multipart/form-data"},
          ),
        );

        if (!mounted) return;

        if (uploadResponse.data['success'] != true) {
          showMessage(context, "Failed to upload document", isError: true);
          setState(() => _isUpdatingStatus = false);
          return;
        }
      }

      final response = await DioClient.dio.put(
        '$basePath/applications/$applicationId/status',
        queryParameters: {
          'status': 'review_application',
          'notes': notes.isNotEmpty ? notes : null,
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(context, "✅ Application marked as REVIEW with document!");
        await _fetchApplications();

        if (_selectedApplication != null &&
            _selectedApplication!['_id'] == applicationId) {
          final updated = applications.firstWhere(
            (app) => app['_id'] == applicationId,
            orElse: () => null,
          );
          if (updated != null) {
            setState(() {
              _selectedApplication = updated;
            });
            // Re-fetch admin documents for the updated app
            _adminDocuments = _getAdminDocumentsForApp(updated);
          }
        }
      } else {
        showMessage(
          context,
          response.data['message'] ?? "Failed to update status",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Error updating status: $e");
      showMessage(context, "Failed to update status: ${e.toString()}",
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  // ==================== FINAL SUBMIT DIALOG ====================
  Future<void> _showFinalSubmitDialog(String applicationId) async {
    final TextEditingController notesController = TextEditingController();
    String? selectedFileName;
    Uint8List? selectedFileBytes;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _FinalSubmitDialogContent(
        notesController: notesController,
        onFileSelected: (name, bytes) {
          selectedFileName = name;
          selectedFileBytes = bytes;
        },
      ),
    );

    if (result == null) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final basePath = _getApiBasePath();
      final notes = notesController.text.trim();

      if (selectedFileBytes != null && selectedFileName != null) {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            selectedFileBytes!,
            filename: selectedFileName!,
          ),
          'notes': notes,
        });

        final uploadResponse = await DioClient.dio.post(
          '$basePath/applications/$applicationId/submit-document',
          data: formData,
          options: Options(
            headers: {"Content-Type": "multipart/form-data"},
          ),
        );

        if (!mounted) return;

        if (uploadResponse.data['success'] != true) {
          showMessage(context, "Failed to upload document", isError: true);
          setState(() => _isUpdatingStatus = false);
          return;
        }
      }

      final response = await DioClient.dio.put(
        '$basePath/applications/$applicationId/status',
        queryParameters: {
          'status': 'final_submit',
          'notes': notes.isNotEmpty ? notes : null,
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(context, "✅ Application FINAL SUBMITTED!");
        await _fetchApplications();

        if (_selectedApplication != null &&
            _selectedApplication!['_id'] == applicationId) {
          final updated = applications.firstWhere(
            (app) => app['_id'] == applicationId,
            orElse: () => null,
          );
          if (updated != null) {
            setState(() {
              _selectedApplication = updated;
            });
            _adminDocuments = _getAdminDocumentsForApp(updated);
          }
        }
      } else {
        showMessage(
          context,
          response.data['message'] ?? "Failed to update status",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Error updating status: $e");
      showMessage(context, "Failed to update status: ${e.toString()}",
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  // ==================== REGULAR STATUS UPDATE ====================
  Future<void> _updateStatus(String applicationId, String newStatus) async {
    if (!mounted) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final basePath = _getApiBasePath();

      debugPrint(
          "📤 Updating application $applicationId to status: $newStatus via $basePath");

      final response = await DioClient.dio.put(
        '$basePath/applications/$applicationId/status',
        queryParameters: {'status': newStatus},
      );

      debugPrint("📥 Update response: ${response.data}");

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(context, "Status updated to $newStatus successfully!");
        await _fetchApplications();

        if (_selectedApplication != null &&
            _selectedApplication!['_id'] == applicationId) {
          final updated = applications.firstWhere(
            (app) => app['_id'] == applicationId,
            orElse: () => null,
          );
          if (updated != null) {
            setState(() {
              _selectedApplication = updated;
            });
          }
        }
      } else {
        showMessage(
            context, response.data['message'] ?? "Failed to update status",
            isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Error updating status: $e");
      showMessage(context, "Failed to update status: ${e.toString()}",
          isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  // ==================== PAYMENT VERIFICATION ====================
  Future<void> _approvePayment(String applicationId, String appId) async {
    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    try {
      debugPrint("📤 Approving payment for application: $applicationId");
      final response = await DioClient.dio.post(
        '/admin/verify-payment/$applicationId',
        queryParameters: {
          'action': 'approve',
          'notes': 'Payment verified and approved by admin',
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(
          context,
          "✅ Payment approved successfully! Application status updated to VERIFICATION SUCCESSFUL.",
        );
        await _fetchApplications();

        if (_selectedApplication != null &&
            _selectedApplication!['_id'] == applicationId) {
          final updated = applications.firstWhere(
            (a) => a['_id'] == applicationId,
            orElse: () => null,
          );
          if (updated != null) {
            setState(() {
              _selectedApplication = updated;
            });
          } else {
            _closeDetails();
          }
        }
      } else {
        showMessage(
            context, response.data['message'] ?? "Failed to approve payment",
            isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Approve payment error: $e");
      showMessage(context, "Failed to approve payment: ${e.toString()}",
          isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _rejectPayment(String applicationId, String appId) async {
    if (!mounted) return;

    final TextEditingController reasonController = TextEditingController();

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cancel, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              "Reject Payment",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please provide a reason for rejecting this payment:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Enter rejection reason...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.edit_note, color: Colors.red),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This reason will be sent to the applicant.\nApplication status will be updated to VERIFICATION REJECTED.",
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                showMessage(
                    dialogContext, "Please enter a reason for rejection",
                    isError: true);
                return;
              }
              Navigator.pop(dialogContext, true);
              _executeRejectPayment(applicationId, appId, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Reject Payment"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRejectPayment(
      String applicationId, String appId, String reason) async {
    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    try {
      debugPrint("📤 Rejecting payment for application: $applicationId");
      final response = await DioClient.dio.post(
        '/admin/verify-payment/$applicationId',
        queryParameters: {
          'action': 'reject',
          'notes': reason,
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(
          context,
          "❌ Payment rejected. Application status updated to VERIFICATION REJECTED.",
        );
        await _fetchApplications();

        if (_selectedApplication != null &&
            _selectedApplication!['_id'] == applicationId) {
          final updated = applications.firstWhere(
            (a) => a['_id'] == applicationId,
            orElse: () => null,
          );
          if (updated != null) {
            setState(() {
              _selectedApplication = updated;
            });
          } else {
            _closeDetails();
          }
        }
      } else {
        showMessage(
            context, response.data['message'] ?? "Failed to reject payment",
            isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Reject payment error: $e");
      showMessage(context, "Failed to reject payment: ${e.toString()}",
          isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  void _showPaymentReceiptDialog(String? receiptUrl) {
    if (receiptUrl == null || receiptUrl.isEmpty) {
      showMessage(context, "No payment receipt available", isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          height: MediaQuery.of(dialogContext).size.height * 0.8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Payment Receipt",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.orange),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FileViewerScreen(
                  url: receiptUrl,
                  title: "Payment Receipt",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApplicationDetails(Map<String, dynamic> app) async {
    if (!mounted) return;
    setState(() {
      _selectedApplication = app;
      _userProfile = null;
      _userDocuments = [];
      _adminDocuments = _getAdminDocumentsForApp(app);
    });

    showMessage(context, "Loading candidate profile...", isError: false);

    final applicantEmail = app['applicant_email']?.toString() ?? '';

    await Future.wait([
      _fetchUserProfile(applicantEmail),
      _fetchUserDocuments(applicantEmail),
    ]);

    if (mounted) {
      setState(() {});
      if (_userProfile != null) {
        showMessage(context, "Profile loaded successfully", isError: false);
      } else {
        showMessage(context, "Could not load complete profile", isError: true);
      }
    }
  }

  void _closeDetails() {
    if (!mounted) return;
    setState(() {
      _selectedApplication = null;
      _userProfile = null;
      _userDocuments = [];
      _adminDocuments = [];
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'shortlisted':
        return Colors.blue;
      case 'interview':
        return Colors.orange;
      case 'offered':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'review_application':
        return Colors.orange.shade700;
      case 'final_submit':
        return Colors.deepPurple;
      case 'pending_verification':
        return Colors.purple;
      case 'verification_successful':
        return Colors.teal;
      case 'verification_rejected':
        return Colors.deepOrange;
      case 'update_application':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getScoreColor(dynamic score) {
    final intScore = score?.toInt() ?? 0;
    if (intScore >= 70) {
      return Colors.green;
    }
    if (intScore >= 50) {
      return Colors.orange;
    }
    return Colors.red;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) {
      return 'N/A';
    }
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _launchResume(String? url) async {
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      showMessage(context, "No resume available", isError: true);
      return;
    }
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        showMessage(context, "Could not open resume", isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Error opening resume: $e", isError: true);
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ✅ PAYMENT VERIFICATION SECTION
  // ============================================================
  Widget _buildPaymentVerificationSection(Map<String, dynamic> app) {
    final applicationId = app['_id']?.toString() ?? '';
    final verificationStatus =
        (app['payment_verification_status'] ?? 'not_submitted').toString();
    final transactionId = app['transaction_id'];
    final transactionDate = app['transaction_date'];
    final paymentReceiptUrl = app['payment_receipt_url'];
    final paymentAmount = app['payment_amount'];
    final paymentCategory = app['payment_category_used'];
    final rejectionReason =
        app['payment_rejection_reason'] ?? app['verification_notes'];
    final currentAppStatus =
        (app['status'] ?? 'pending_verification').toString();
    final paymentMethod = (app['payment_method'] ?? 'razorpay').toString();
    final razorpayPaymentId = app['razorpay_payment_id'];
    final razorpayOrderId = app['razorpay_order_id'];

    if (verificationStatus.toLowerCase() == 'pending') {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade50, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200, width: 1.5),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade700
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pending Payment Verification",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          "Review and verify the payment details",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "PENDING",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _buildPaymentInfoRow(
                Icons.receipt_long,
                "Transaction ID",
                transactionId?.toString() ?? "N/A",
              ),
              const SizedBox(height: 10),
              _buildPaymentInfoRow(
                Icons.calendar_today,
                "Transaction Date",
                transactionDate != null
                    ? _formatDate(transactionDate.toString())
                    : "N/A",
              ),
              const SizedBox(height: 10),
              _buildPaymentInfoRow(
                Icons.currency_rupee,
                "Amount Paid",
                paymentAmount != null ? "₹$paymentAmount" : "N/A",
              ),
              const SizedBox(height: 10),
              _buildPaymentInfoRow(
                Icons.category,
                "Category",
                paymentCategory?.toString().toUpperCase() ?? "N/A",
              ),
              if (razorpayPaymentId != null &&
                  razorpayPaymentId.toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildPaymentInfoRow(
                  Icons.payment,
                  "Razorpay Payment ID",
                  razorpayPaymentId.toString(),
                ),
              ],
              if (razorpayOrderId != null &&
                  razorpayOrderId.toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildPaymentInfoRow(
                  Icons.shopping_cart,
                  "Razorpay Order ID",
                  razorpayOrderId.toString(),
                ),
              ],
              if (paymentMethod.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildPaymentInfoRow(
                  Icons.account_balance_wallet,
                  "Payment Method",
                  paymentMethod.toUpperCase(),
                ),
              ],
              if (paymentReceiptUrl != null &&
                  paymentReceiptUrl.toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showPaymentReceiptDialog(paymentReceiptUrl.toString()),
                    icon: const Icon(Icons.receipt, size: 18),
                    label: const Text("View Payment Receipt"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isUpdatingStatus
                            ? null
                            : () =>
                                _approvePayment(applicationId, applicationId),
                        icon: _isUpdatingStatus
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle, size: 20),
                        label: Text(
                          _isUpdatingStatus ? "Processing..." : "Approve",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isUpdatingStatus
                            ? null
                            : () =>
                                _rejectPayment(applicationId, applicationId),
                        icon: const Icon(Icons.cancel, size: 20),
                        label: const Text(
                          "Reject",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "✅ Approve → Application → VERIFICATION SUCCESSFUL\n"
                        "❌ Reject → Application → VERIFICATION REJECTED\n"
                        "User + Admin will receive notifications.",
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isApproved = verificationStatus.toLowerCase() == 'approved';
    final isRejected = verificationStatus.toLowerCase() == 'rejected';
    final statusColor = isApproved
        ? Colors.green
        : isRejected
            ? Colors.red
            : Colors.grey;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Icon(
                    isApproved
                        ? Icons.verified
                        : isRejected
                            ? Icons.cancel
                            : Icons.hourglass_empty,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isApproved
                            ? "Payment Approved"
                            : isRejected
                                ? "Payment Rejected"
                                : "Payment Not Submitted",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isApproved
                            ? "Verification completed successfully"
                            : isRejected
                                ? "Payment was rejected by admin"
                                : "User has not submitted payment proof",
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    verificationStatus.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (transactionId != null || paymentAmount != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (transactionId != null)
                _buildPaymentInfoRow(
                  Icons.receipt_long,
                  "Transaction ID",
                  transactionId.toString(),
                ),
              if (paymentAmount != null) ...[
                const SizedBox(height: 8),
                _buildPaymentInfoRow(
                  Icons.currency_rupee,
                  "Amount",
                  "₹$paymentAmount",
                ),
              ],
              if (transactionDate != null) ...[
                const SizedBox(height: 8),
                _buildPaymentInfoRow(
                  Icons.calendar_today,
                  "Date",
                  _formatDate(transactionDate.toString()),
                ),
              ],
            ],
            if (isRejected &&
                rejectionReason != null &&
                rejectionReason.toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text(
                          "Rejection Reason:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rejectionReason.toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
            if (paymentReceiptUrl != null &&
                paymentReceiptUrl.toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showPaymentReceiptDialog(paymentReceiptUrl.toString()),
                  icon: const Icon(Icons.receipt, size: 18),
                  label: const Text("View Payment Receipt"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isApproved ? Icons.check_circle : Icons.info,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isApproved
                          ? "Application status: ${_getStatusDisplay(currentAppStatus)}"
                          : isRejected
                              ? "Application status: ${_getStatusDisplay(currentAppStatus)}"
                              : "Awaiting user payment submission",
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'verification_successful':
        return 'VERIFICATION SUCCESSFUL';
      case 'verification_rejected':
        return 'VERIFICATION REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  // ==================== BUILD ====================

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ).createShader(bounds),
                child: const Text(
                  "AI is loading applications...",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedApplication != null) {
      return _buildApplicationDetailView();
    }

    if (isLoading) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("Applications - ${widget.adminRole.toUpperCase()}"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildFilterButtons(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchApplications,
          ),
        ],
      ),
      body: applications.isEmpty
          ? _buildEmptyState()
          : Container(
              decoration: _buildGradientBackground(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: applications.length,
                itemBuilder: (context, index) =>
                    _buildApplicationCard(applications[index]),
              ),
            ),
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filterButtons.length,
        itemBuilder: (context, index) {
          final filter = _filterButtons[index];
          final isSelected = _selectedFilter == filter['value'];
          final Color color = filter['color'] as Color;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'],
                    size: 16,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 6),
                  Text(filter['label']),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = selected ? filter['value'] : 'all';
                });
                _fetchApplications();
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: color,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final jobTitle = app['job_title'] ?? 'Job Opportunity';
    final organization = app['organization'] ?? app['company'] ?? 'Company';
    final applicantName = app['applicant_name'] ?? 'Unknown';
    final applicantEmail = app['applicant_email'] ?? '';
    final status = app['status'] ?? 'pending';
    final matchScore = app['match_score'];
    final appliedDate = _formatDate(app['applied_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Material(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showApplicationDetails(app),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          _getStatusColor(status).withOpacity(0.15),
                      child: Text(
                        applicantName.isNotEmpty
                            ? applicantName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicantName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                          Text(
                            applicantEmail,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.3),
                            width: 1),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jobTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        organization,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip(
                      Icons.calendar_today,
                      "Applied",
                      appliedDate,
                    ),
                    if (matchScore != null)
                      _buildStatChip(
                        Icons.auto_awesome,
                        "AI Match",
                        "$matchScore%",
                        color: _getScoreColor(matchScore),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showApplicationDetails(app),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text("View Application"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            "$label: $value",
            style: TextStyle(
                fontSize: 12,
                color: color ?? Colors.grey.shade600,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            "No applications yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Applications will appear here when users apply to your jobs",
          ),
        ],
      ),
    );
  }

  // ==================== APPLICATION DETAIL VIEW ====================

  Widget _buildApplicationDetailView() {
    final app = _selectedApplication!;
    final jobTitle = app['job_title'] ?? 'Job Opportunity';
    final organization = app['organization'] ?? app['company'] ?? 'Company';
    final applicantName = app['applicant_name'] ?? 'Unknown';
    final applicantEmail = app['applicant_email'] ?? 'N/A';
    final status = app['status'] ?? 'pending';
    final matchScore = app['match_score'];
    final appliedDate = _formatDate(app['applied_at']);
    final coverLetter = app['cover_letter'] ?? 'No cover letter provided';
    final aiReason = app['ai_match']?['reason'] ?? '';
    final hasUpdates = app['application_updates'] != null &&
        (app['application_updates'] as List).isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Application Details"),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeDetails,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchApplications();
              if (_selectedApplication != null) {
                _showApplicationDetails(_selectedApplication!);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(app['_id'], status),
            const SizedBox(height: 16),
            _buildCandidateCard(applicantName, applicantEmail, appliedDate),
            const SizedBox(height: 16),
            _buildJobCard(jobTitle, organization, matchScore, aiReason),
            const SizedBox(height: 16),
            _buildCoverLetterCard(coverLetter),
            const SizedBox(height: 16),
            _buildCompleteProfileButton(),
            const SizedBox(height: 16),
            _buildResumeCard(app['resume_url']),
            const SizedBox(height: 16),
            _buildPaymentVerificationSection(app),
            const SizedBox(height: 16),
            // ✅ TWO SEPARATE DOCUMENT SECTIONS
            _buildDocumentsSection(app),
            const SizedBox(height: 16),
            if (hasUpdates && status.toLowerCase() == 'update_application')
              _buildViewUpdatesButton(app),
            const SizedBox(height: 16),
            _buildQuickActionButtons(app['_id'], status),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildViewUpdatesButton(Map<String, dynamic> app) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Application Updates",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "This application has updates submitted by the user. Click below to view all updates.",
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showApplicationUpdatesDialog(app),
                icon: const Icon(Icons.visibility, size: 20),
                label: const Text(
                  "View All Application Updates",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String appId, String currentStatus) {
    final statusColor = _getStatusColor(currentStatus);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Update Application Status",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Current Status:",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentStatus.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Change to:",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _statusButtons.map((s) {
              final isSelected = s['value'] == currentStatus;
              final isReview = s['value'] == 'review_application';
              final isFinalSubmit = s['value'] == 'final_submit';
              final Color buttonColor = s['color'] as Color;
              final String buttonLabel = s['label'] as String;
              final IconData buttonIcon = s['icon'] as IconData;
              final double horizontalPadding =
                  buttonLabel.length > 8 ? 12.0 : 16.0;

              return SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: (isSelected || _isUpdatingStatus)
                      ? null
                      : () {
                          if (isReview) {
                            _showReviewDialog(appId);
                          } else if (isFinalSubmit) {
                            _showFinalSubmitDialog(appId);
                          } else {
                            _updateStatus(appId, s['value'] as String);
                          }
                        },
                  icon: Icon(buttonIcon, size: 18),
                  label: Text(
                    buttonLabel,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSelected ? buttonColor : buttonColor.withAlpha(25),
                    foregroundColor: isSelected ? Colors.white : buttonColor,
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: isSelected ? 2 : 0,
                  ),
                ),
              );
            }).toList(),
          ),
          if (_isUpdatingStatus)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(String appId, String currentStatus) {
    final filteredButtons =
        _statusButtons.where((s) => s['value'] != currentStatus).toList();

    if (filteredButtons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: filteredButtons.map((s) {
                final isReview = s['value'] == 'review_application';
                final isFinalSubmit = s['value'] == 'final_submit';
                final Color buttonColor = s['color'] as Color;
                final String buttonLabel = s['label'] as String;
                final IconData buttonIcon = s['icon'] as IconData;
                final double horizontalPadding =
                    buttonLabel.length > 8 ? 12.0 : 16.0;

                return SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (isReview) {
                        _showReviewDialog(appId);
                      } else if (isFinalSubmit) {
                        _showFinalSubmitDialog(appId);
                      } else {
                        _updateStatus(appId, s['value'] as String);
                      }
                    },
                    icon: Icon(buttonIcon, size: 18),
                    label: Text(
                      buttonLabel,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 2,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateCard(String name, String email, String appliedDate) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    Icons.calendar_today,
                    "Applied On",
                    appliedDate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(
    String title,
    String company,
    dynamic matchScore,
    String aiReason,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Job Details",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.work, "Position", title),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.business, "Company", company),
            if (matchScore != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _getScoreColor(matchScore),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AI Match Score: $matchScore%",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(matchScore),
                          ),
                        ),
                        if (aiReason.isNotEmpty)
                          Text(
                            aiReason,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoverLetterCard(String coverLetter) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Cover Letter",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(coverLetter, style: const TextStyle(height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteProfileButton() {
    final applicantEmail = _selectedApplication?['applicant_email'] ?? '';
    final applicantName =
        _selectedApplication?['applicant_name'] ?? 'Candidate';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  "Candidate Information",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (widget.onViewCandidateProfile != null) {
                        widget.onViewCandidateProfile!(_selectedApplication!);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CandidateProfileScreen(
                              email: applicantEmail,
                              candidateName: applicantName,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.visibility, color: Colors.white),
                    label: const Text("View Complete Profile"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumeCard(String? resumeUrl) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Resume / CV",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _launchResume(resumeUrl),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      size: 40,
                      color: resumeUrl != null ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resumeUrl != null
                                ? "Resume Available"
                                : "No Resume Uploaded",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: resumeUrl != null
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          if (resumeUrl != null)
                            const Text(
                              "Tap to view/download",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (resumeUrl != null)
                      const Icon(Icons.open_in_new, color: Colors.blue),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== REVIEW DIALOG CONTENT (WITH FILE UPLOAD) ====================
class _ReviewDialogContent extends StatefulWidget {
  final TextEditingController notesController;
  final Function(String, Uint8List) onFileSelected;

  const _ReviewDialogContent({
    required this.notesController,
    required this.onFileSelected,
  });

  @override
  State<_ReviewDialogContent> createState() => _ReviewDialogContentState();
}

class _ReviewDialogContentState extends State<_ReviewDialogContent> {
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && mounted) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
        });
        widget.onFileSelected(file.name, file.bytes!);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Error picking file: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9 > 500 ? 500.0 : screenWidth * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.rate_review,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "REVIEW APPLICATION",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "⚠️ REVIEW APPLICATION\nThis will change status to REVIEW. Document will be saved.",
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📄 Upload Document (PDF or Image)",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Upload relevant document for review.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedFileName != null
                              ? Colors.orange.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFileName != null
                                ? Colors.orange
                                : Colors.blue,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedFileName != null
                                  ? Icons.check_circle
                                  : Icons.cloud_upload,
                              size: 48,
                              color: _selectedFileName != null
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFileName != null
                                  ? _selectedFileName!
                                  : "Tap to select document (PDF or Image)",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedFileName != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedFileName != null
                                    ? Colors.orange
                                    : Colors.blue,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedFileName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "${(_selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "Review Notes (Optional)",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widget.notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Add review comments or notes...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "ℹ️ After review, the application status will change to REVIEW_APPLICATION. Both user and admin will receive notifications.",
                              style: TextStyle(
                                  fontSize: 11, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, {
                      'notes': widget.notesController.text,
                      'fileSelected': _selectedFileName != null,
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rate_review, size: 18),
                        SizedBox(width: 8),
                        Text("Submit Review"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== FINAL SUBMIT DIALOG CONTENT ====================
class _FinalSubmitDialogContent extends StatefulWidget {
  final TextEditingController notesController;
  final Function(String, Uint8List) onFileSelected;

  const _FinalSubmitDialogContent({
    required this.notesController,
    required this.onFileSelected,
  });

  @override
  State<_FinalSubmitDialogContent> createState() =>
      _FinalSubmitDialogContentState();
}

class _FinalSubmitDialogContentState
    extends State<_FinalSubmitDialogContent> {
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && mounted) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
        });
        widget.onFileSelected(file.name, file.bytes!);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Error picking file: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9 > 500 ? 500.0 : screenWidth * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.send_and_archive,
                    color: Colors.deepPurple,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "FINAL SUBMISSION",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "⚠️ FINAL SUBMISSION\nThis is the final step. The status will change to FINAL SUBMIT.",
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📄 Upload Final Document (PDF or Image)",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "This document will be stored securely and submitted with the application.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedFileName != null
                              ? Colors.deepPurple.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFileName != null
                                ? Colors.deepPurple
                                : Colors.blue,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedFileName != null
                                  ? Icons.check_circle
                                  : Icons.cloud_upload,
                              size: 48,
                              color: _selectedFileName != null
                                  ? Colors.deepPurple
                                  : Colors.blue,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFileName != null
                                  ? _selectedFileName!
                                  : "Tap to select final document (PDF or Image)",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedFileName != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedFileName != null
                                    ? Colors.deepPurple
                                    : Colors.blue,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedFileName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "${(_selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "Additional Notes (Optional)",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widget.notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Add any final remarks or notes...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "⚠️ This is FINAL submission. After this, no further changes are allowed.",
                              style: TextStyle(
                                  fontSize: 11, color: Colors.deepPurple),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, {
                      'notes': widget.notesController.text,
                      'fileSelected': _selectedFileName != null,
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_and_archive, size: 18),
                        SizedBox(width: 8),
                        Text("Confirm Final Submit"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}