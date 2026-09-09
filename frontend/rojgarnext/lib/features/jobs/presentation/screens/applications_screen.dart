// lib/features/jobs/presentation/screens/applications_screen.dart
// ✅ AI-BASED MODERN REDESIGN – Glassmorphism, Gradients, Animated Loading
// ✅ Preserves all original functionality (status updates, file uploads, payments, profile navigation)

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

  // Filter buttons - all statuses for filtering
  final List<Map<String, dynamic>> _filterButtons = [
    {'value': 'all', 'label': 'All', 'icon': Icons.list, 'color': Colors.grey},
    {
      'value': 'pending',
      'label': 'Pending',
      'icon': Icons.hourglass_empty,
      'color': Colors.orange,
    },
    {
      'value': 'pending_verification',
      'label': 'Pending Pay',
      'icon': Icons.payment,
      'color': Colors.purple,
    },
    {
      'value': 'shortlisted',
      'label': 'Shortlisted',
      'icon': Icons.star,
      'color': Colors.blue,
    },
    {
      'value': 'interview',
      'label': 'Interview',
      'icon': Icons.people,
      'color': Colors.purple,
    },
    {
      'value': 'offered',
      'label': 'Offer',
      'icon': Icons.celebration,
      'color': Colors.green,
    },
    {
      'value': 'rejected',
      'label': 'Reject',
      'icon': Icons.cancel,
      'color': Colors.red,
    },
    {
      'value': 'verification_successful',
      'label': 'Verified',
      'icon': Icons.verified,
      'color': Colors.teal,
    },
    {
      'value': 'verification_rejected',
      'label': 'Verif Reject',
      'icon': Icons.cancel,
      'color': Colors.deepOrange,
    },
    {
      'value': 'update_application',
      'label': 'Update Pending',
      'icon': Icons.edit_note,
      'color': Colors.blue,
    },
  ];

  // Status buttons for updating - ONLY THESE BUTTONS
  final List<Map<String, dynamic>> _statusButtons = [
    {
      'value': 'pending',
      'label': 'Pending',
      'color': Colors.orange,
      'icon': Icons.hourglass_empty,
    },
    {
      'value': 'shortlisted',
      'label': 'Shortlist',
      'color': Colors.blue,
      'icon': Icons.star,
    },
    {
      'value': 'interview',
      'label': 'Interview',
      'color': Colors.purple,
      'icon': Icons.people,
    },
    {
      'value': 'offered',
      'label': 'Offer',
      'color': Colors.green,
      'icon': Icons.celebration,
    },
    {
      'value': 'review_application',
      'label': 'Review',
      'color': Colors.orange.shade700,
      'icon': Icons.rate_review,
    },
    {
      'value': 'final_submit',
      'label': 'Final Submit',
      'color': Colors.deepPurple,
      'icon': Icons.send_and_archive,
    },
  ];

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
      debugPrint(
        "📧 Fetching applications for admin: $_adminEmail using $basePath",
      );

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
              // Header
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

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
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

                      // Submitted Date
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

                      // Update Notes (if any)
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

                      // Updates List
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

              // Footer Buttons
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

  // ==================== REVIEW APPLICATION DIALOG (WITH FILE UPLOAD) - FIXED ====================
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

      // Upload file if selected
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

      // Update status to review_application
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

  // ==================== FINAL SUBMIT DIALOG (WITH FILE UPLOAD) - FIXED ====================
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

      // Upload file if selected
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

      // Update status to final_submit
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

  // ==================== PAYMENT VERIFICATION METHODS ====================
  Future<void> _approvePayment(String paymentId, String applicationId) async {
    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final response = await DioClient.dio.post(
        '/admin/verify-payment/$paymentId',
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
            _selectedApplication!['payment_id'] == paymentId) {
          final updated = applications.firstWhere(
            (a) => a['payment_id'] == paymentId,
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
      showMessage(context, "Failed to approve payment: ${e.toString()}",
          isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _rejectPayment(String paymentId, String applicationId) async {
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
              _executeRejectPayment(paymentId, applicationId, reason);
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
      String paymentId, String applicationId, String reason) async {
    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final response = await DioClient.dio.post(
        '/admin/verify-payment/$paymentId',
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
            _selectedApplication!['payment_id'] == paymentId) {
          final updated = applications.firstWhere(
            (a) => a['payment_id'] == paymentId,
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
    });

    showMessage(context, "Loading candidate profile...", isError: false);
    await _fetchUserProfile(app['applicant_email']);

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

  // ==================== PAYMENT VERIFICATION SECTION ====================
  Widget _buildPaymentVerificationSection(Map<String, dynamic> app) {
    final paymentId = app['payment_id'];
    final verificationStatus =
        app['payment_verification_status'] ?? 'not_submitted';
    final transactionId = app['transaction_id'];
    final transactionDate = app['transaction_date'];
    final paymentReceiptUrl = app['payment_receipt_url'];
    final paymentAmount = app['payment_amount'];
    final paymentCategory = app['payment_category_used'];
    final rejectionReason =
        app['payment_rejection_reason'] ?? app['verification_notes'];
    final currentAppStatus = app['status'] ?? 'pending_verification';

    if (verificationStatus != 'pending') {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Payment Verification Status",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: verificationStatus == 'approved'
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  verificationStatus.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: verificationStatus == 'approved'
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
              if (transactionId != null) ...[
                const SizedBox(height: 12),
                Text("Transaction ID: $transactionId"),
              ],
              if (transactionDate != null) ...[
                const SizedBox(height: 8),
                Text("Transaction Date: ${_formatDate(transactionDate)}"),
              ],
              if (paymentAmount != null) ...[
                const SizedBox(height: 8),
                Text("Amount: ₹$paymentAmount",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ],
              if (paymentCategory != null) ...[
                const SizedBox(height: 8),
                Text("Category: ${paymentCategory.toUpperCase()}"),
              ],
              if (verificationStatus == 'rejected' &&
                  rejectionReason != null &&
                  rejectionReason.isNotEmpty) ...[
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
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            "Rejection Reason:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rejectionReason,
                        style: const TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
              if (paymentReceiptUrl != null &&
                  paymentReceiptUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showPaymentReceiptDialog(paymentReceiptUrl),
                  icon: const Icon(Icons.receipt),
                  label: const Text("View Payment Receipt"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        verificationStatus == 'approved'
                            ? "✅ Payment verified! Application status: ${_getStatusDisplay(currentAppStatus)}"
                            : "❌ Payment rejected! Application status: ${_getStatusDisplay(currentAppStatus)}",
                        style: TextStyle(
                            fontSize: 11, color: Colors.blue.shade700),
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
                Icon(Icons.verified, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  "Pending Payment Verification",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (transactionId != null)
              _buildInfoRow(Icons.receipt, "Transaction ID", transactionId),
            if (transactionDate != null)
              _buildInfoRow(
                Icons.calendar_today,
                "Transaction Date",
                _formatDate(transactionDate),
              ),
            if (paymentAmount != null)
              _buildInfoRow(
                Icons.currency_rupee,
                "Amount",
                "₹$paymentAmount",
              ),
            if (paymentCategory != null)
              _buildInfoRow(
                Icons.category,
                "Category",
                paymentCategory.toUpperCase(),
              ),
            const SizedBox(height: 12),
            if (paymentReceiptUrl != null && paymentReceiptUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentReceiptDialog(paymentReceiptUrl),
                  icon: const Icon(Icons.receipt),
                  label: const Text("View Payment Receipt"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _approvePayment(paymentId, app['_id']),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      "Approve Payment",
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _rejectPayment(paymentId, app['_id']),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(
                      "Reject Payment",
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
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
                      "✅ Approve Payment: Application status will change to VERIFICATION SUCCESSFUL\n❌ Reject Payment: Application status will change to VERIFICATION REJECTED",
                      style: TextStyle(fontSize: 11, color: Colors.orange),
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
                      backgroundColor: _getStatusColor(status).withOpacity(0.15),
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
            // ==================== VIEW UPDATES BUTTON IN DETAIL VIEW ====================
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

  // ==================== VIEW UPDATES BUTTON ====================
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

  // ==================== STATUS CARD ====================
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

  // ==================== QUICK ACTION BUTTONS ====================
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

  // ==================== COMPLETE PROFILE BUTTON ====================
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

// ==================== REVIEW DIALOG CONTENT (WITH FILE UPLOAD) - FIXED ====================
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
            // ==================== HEADER ====================
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

            // ==================== INFO BOX ====================
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

            // ==================== SCROLLABLE CONTENT ====================
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File Upload Section
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

                    // File Picker Gesture
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedFileName != null
                              ? Colors.orange.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFileName != null ? Colors.orange : Colors.blue,
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

                    // Review Notes
                    const Text(
                      "Review Notes (Optional)",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

                    // Bottom Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "ℹ️ After review, the application status will change to REVIEW_APPLICATION. Both user and admin will receive notifications.",
                              style: TextStyle(fontSize: 11, color: Colors.orange),
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

            // ==================== BUTTONS (ALWAYS VISIBLE AT BOTTOM) ====================
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

// ==================== FINAL SUBMIT DIALOG CONTENT (WITH FILE UPLOAD) - FIXED ====================
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

class _FinalSubmitDialogContentState extends State<_FinalSubmitDialogContent> {
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
            // ==================== HEADER ====================
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

            // ==================== WARNING BOX ====================
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

            // ==================== SCROLLABLE CONTENT ====================
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File Upload Section
                    const Text(
                      "📄 Upload Final Document (PDF or Image)",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "This document will be stored securely and submitted with the application.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // File Picker Gesture
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedFileName != null
                              ? Colors.deepPurple.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFileName != null ? Colors.deepPurple : Colors.blue,
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

                    // Additional Notes
                    const Text(
                      "Additional Notes (Optional)",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

                    // Bottom Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "⚠️ This is FINAL submission. After this, no further changes are allowed.",
                              style: TextStyle(fontSize: 11, color: Colors.deepPurple),
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

            // ==================== BUTTONS (ALWAYS VISIBLE AT BOTTOM) ====================
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