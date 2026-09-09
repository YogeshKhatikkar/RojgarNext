// lib/features/services/presentation/screens/service_application_screen.dart
// ✅ COMPLETE FIXED VERSION - With "View Acknowledgment Receipt" button

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/widgets/file_viewer_screen.dart';
import 'package:rojgarnext/features/services/models/service_types.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint; 

// ==================== GLOBAL SHOW MESSAGE FUNCTION ====================
void showMessage(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

class ServiceApplicationScreen extends StatefulWidget {
  const ServiceApplicationScreen({super.key});

  @override
  State<ServiceApplicationScreen> createState() =>
      _ServiceApplicationScreenState();
}

class _ServiceApplicationScreenState extends State<ServiceApplicationScreen> {
  List<dynamic> _applications = [];
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  Map<String, dynamic>? _selectedApplication;
  String? _errorMessage;
  String? _adminEmail;

  // ✅ Cache for service details
  final Map<String, Map<String, String>> _serviceDetailsCache = {};

  @override
  void initState() {
    super.initState();
    _getAdminEmail();
  }

  // ==================== GET ADMIN EMAIL ====================
  Future<void> _getAdminEmail() async {
    if (!mounted) return;
    try {
      final email = await SecureStorage.getEmail();
      if (email != null && email.isNotEmpty) {
        _adminEmail = email;
        debugPrint("📧 Admin Email: $_adminEmail");
        await _loadApplications();
      } else {
        setState(() => _isLoading = false);
        showMessage(context, "Could not get admin email", isError: true);
      }
    } catch (e) {
      debugPrint("❌ Error getting admin email: $e");
      setState(() => _isLoading = false);
    }
  }

  // ==================== GET SERVICE DISPLAY DETAILS ====================
  Map<String, String> _getServiceDisplayDetails(String serviceId, String subTypeId) {
    final cacheKey = '$serviceId:$subTypeId';

    if (_serviceDetailsCache.containsKey(cacheKey)) {
      return _serviceDetailsCache[cacheKey]!;
    }

    final service = ServiceMasterData.getServiceById(serviceId);
    final subType = ServiceMasterData.getSubTypeById(subTypeId);

    final details = {
      'service_name': service?.name ?? serviceId,
      'service_icon': service?.icon ?? '📄',
      'sub_service_name': subType?.name ?? subTypeId,
      'sub_service_description': subType?.description ?? '',
    };

    _serviceDetailsCache[cacheKey] = details;
    return details;
  }

  // ==================== LOAD APPLICATIONS ====================
  Future<void> _loadApplications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      final response = await DioClient.dio.get('/services/all-applications');

      if (!mounted) return;

      List<dynamic> apps = [];
      if (response.data is Map) {
        final data = response.data as Map;
        if (data.containsKey('applications')) {
          apps = data['applications'] as List<dynamic>;
        }
      }

      debugPrint("📋 Loaded ${apps.length} service applications");

      // Enrich each application with display details
      final enrichedApps = apps.map((app) {
        final appMap = app is Map<String, dynamic>
            ? app
            : Map<String, dynamic>.from(app as Map);

        final serviceId = appMap['service_id']?.toString() ?? '';
        final subTypeId = appMap['sub_type_id']?.toString() ?? '';
        final details = _getServiceDisplayDetails(serviceId, subTypeId);

        return {
          ...appMap,
          'display_service_name': details['service_name'],
          'display_service_icon': details['service_icon'],
          'display_sub_service_name': details['sub_service_name'],
        };
      }).toList();

      setState(() {
        _applications = enrichedApps;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error loading service applications: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        showMessage(context, "Failed to load applications: $e", isError: true);
      }
    }
  }

  void _showApplicationDetails(Map<String, dynamic> app) {
    setState(() {
      _selectedApplication = app;
    });
  }

  void _closeDetails() {
    setState(() {
      _selectedApplication = null;
    });
    _loadApplications();
  }

  // ==================== ✅ REFRESH CURRENT APPLICATION ====================
  Future<void> _refreshCurrentApplication(String applicationId) async {
    try {
      debugPrint("🔄 Refreshing application: $applicationId");

      final response = await DioClient.dio.get('/services/application/$applicationId');

      if (!mounted) return;

      Map<String, dynamic> updatedApp = {};

      if (response.data != null && response.data is Map) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response.data as Map);

        if (data.containsKey('data') && data['data'] is Map) {
          updatedApp = Map<String, dynamic>.from(data['data'] as Map);
        } else {
          updatedApp = data;
        }

        if (updatedApp.isEmpty || updatedApp['_id'] == null) {
          final existingApp = _applications.firstWhere(
            (app) {
              final appMap = app is Map ? Map<String, dynamic>.from(app) : {};
              return appMap['_id']?.toString() == applicationId;
            },
            orElse: () => null,
          );

          if (existingApp != null) {
            updatedApp = Map<String, dynamic>.from(existingApp as Map);
            updatedApp['_id'] = applicationId;
          }
        }

        if (updatedApp.isEmpty) {
          debugPrint("⚠️ Application not found, reloading full list");
          await _loadApplications();
          return;
        }

        // Enrich with display details
        final serviceId = updatedApp['service_id']?.toString() ?? '';
        final subTypeId = updatedApp['sub_type_id']?.toString() ?? '';
        final details = _getServiceDisplayDetails(serviceId, subTypeId);

        final Map<String, dynamic> enrichedApp = {
          ...updatedApp,
          'display_service_name': details['service_name'] ?? serviceId,
          'display_service_icon': details['service_icon'] ?? '📄',
          'display_sub_service_name': details['sub_service_name'] ?? subTypeId,
        };

        // Get the new status for logging
        final newStatus = enrichedApp['status']?.toString() ?? 'unknown';
        debugPrint("📢 Application status updated to: ${newStatus.toUpperCase()}");

        setState(() {
          final index = _applications.indexWhere((app) {
            final appMap = app is Map ? Map<String, dynamic>.from(app) : {};
            return appMap['_id']?.toString() == applicationId;
          });

          if (index != -1) {
            _applications[index] = enrichedApp;
          } else {
            _applications.add(enrichedApp);
          }

          if (_selectedApplication != null) {
            final selectedId = _selectedApplication!['_id']?.toString();
            if (selectedId == applicationId) {
              _selectedApplication = enrichedApp;
              debugPrint("✅ Selected application updated with new status: ${enrichedApp['status']}");
            }
          }
        });

        if (!mounted) return;
        showMessage(context, "✅ Status updated to ${newStatus.toUpperCase()}");

      } else {
        debugPrint("⚠️ Invalid response from API, reloading full list");
        await _loadApplications();
      }
    } catch (e) {
      debugPrint("❌ Error refreshing application: $e");
      await _loadApplications();
    }
  }

  // ==================== PAYMENT APPROVAL ====================
  Future<void> _approvePayment(String paymentId, String applicationId) async {
    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final response = await DioClient.dio.post(
        '/services/application/$applicationId/verify-payment',
        data: {
          'action': 'approve',
          'notes': 'Payment verified and approved by admin',
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(
          context,
          "✅ Payment approved successfully! Application status updated to APPROVED.",
        );

        await _refreshCurrentApplication(applicationId);

        await _sendBellNotification(
          applicationId: applicationId,
          status: 'approved',
          userEmail: _selectedApplication?['user_email'] ?? '',
          adminName: 'Admin',
          notes: 'Payment approved',
        );
      } else {
        showMessage(
          context,
          response.data['message'] ?? "Failed to approve payment",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Failed to approve payment: ${e.toString()}", isError: true);
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
            const Text("Reject Payment", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Please provide a reason for rejecting this payment:", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Enter rejection reason...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      "This reason will be sent to the applicant.",
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
                showMessage(dialogContext, "Please enter a reason for rejection", isError: true);
                return;
              }
              Navigator.pop(dialogContext, true);
              _executeRejectPayment(paymentId, applicationId, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Reject Payment"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRejectPayment(String paymentId, String applicationId, String reason) async {
    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final response = await DioClient.dio.post(
        '/services/application/$applicationId/verify-payment',
        data: {
          'action': 'reject',
          'notes': reason,
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(
          context,
          "❌ Payment rejected. Application status updated to REJECTED.",
        );

        await _refreshCurrentApplication(applicationId);

        await _sendBellNotification(
          applicationId: applicationId,
          status: 'rejected',
          userEmail: _selectedApplication?['user_email'] ?? '',
          adminName: 'Admin',
          notes: reason,
        );
      } else {
        showMessage(
          context,
          response.data['message'] ?? "Failed to reject payment",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Failed to reject payment: ${e.toString()}", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
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

  // ==================== SEND BELL NOTIFICATION ====================
  Future<void> _sendBellNotification({
    required String applicationId,
    required String status,
    required String userEmail,
    required String adminName,
    String? notes,
  }) async {
    try {
      final statusMessages = {
        'approved': '✅ Payment verified successfully! Your application is now APPROVED.',
        'rejected': '❌ Payment rejected. Reason: ${notes ?? "Please contact support"}',
        'under_review': '📋 Your application is under review.',
        'completed': '✅ FINAL SUBMISSION completed! Your application is now COMPLETED.',
        'payment_pending': '⏳ Payment pending. Please complete the payment.',
        'pending_verification': '⏳ Your payment is pending verification.',
        'confirmed_application': '✅ Your service application has been confirmed successfully!',
        'update_application': '📝 Your service application update has been submitted for admin review.',
      };

      final Map<String, dynamic> metadata = {
        'application_id': applicationId,
        'status': status,
        'admin_name': adminName,
        'service_name': _selectedApplication?['display_service_name'] ?? 'Service',
        'sub_service_name': _selectedApplication?['display_sub_service_name'] ?? '',
        'show_blue_bell': true,
      };

      if (notes != null && notes.isNotEmpty) {
        metadata['admin_notes'] = notes;
      }

      await DioClient.dio.post(
        '/notification/admin/broadcast',
        data: {
          'title': statusMessages[status] ?? "Application Status: ${status.toUpperCase()}",
          'message': statusMessages[status] ?? "Your application status has been updated to ${status.toUpperCase()}.",
          'metadata': metadata,
        },
      );

      debugPrint("🔔 BELL notification sent to user: $userEmail");
    } catch (e) {
      debugPrint("❌ Failed to send bell notification: $e");
    }
  }

  // ==================== REVIEW DIALOG WITH FILE UPLOAD ====================
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
          '/services/application/$applicationId/review-with-document',
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

        showMessage(context, "✅ Document uploaded and application moved to REVIEW!");
        await _refreshCurrentApplication(applicationId);
      } else {
        await _updateStatus(applicationId, 'review_application', notes);
        await _refreshCurrentApplication(applicationId);
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Failed to submit review: ${e.toString()}", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  // ==================== FINAL SUBMIT DIALOG WITH FILE UPLOAD ====================
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
          '/services/application/$applicationId/final-submit-with-document',
          data: formData,
          options: Options(
            headers: {"Content-Type": "multipart/form-data"},
          ),
        );

        if (!mounted) return;

        if (uploadResponse.data['success'] != true) {
          showMessage(context, "Failed to upload final document", isError: true);
          setState(() => _isUpdatingStatus = false);
          return;
        }

        showMessage(context, "✅ FINAL SUBMISSION completed with document!");
        await _refreshCurrentApplication(applicationId);
      } else {
        await _updateStatus(applicationId, 'completed', notes);
        await _refreshCurrentApplication(applicationId);
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Failed to complete submission: ${e.toString()}", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  // ==================== STATUS UPDATE ====================
  Future<void> _updateStatus(String applicationId, String newStatus, [String? notes]) async {
    if (!mounted) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final response = await DioClient.dio.put(
        '/services/application/$applicationId/status',
        data: {
          'status': newStatus,
          'admin_notes': notes ?? '',
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        debugPrint("✅ Status updated on server for $applicationId to $newStatus");
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
      showMessage(context, "Failed to update status: ${e.toString()}", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  // ==================== VIEW DOCUMENT ====================
  void _viewDocument(String url, String title) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          height: MediaQuery.of(dialogContext).size.height * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FileViewerScreen(
              url: url,
              title: title,
              downloadUrl: url,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== ✅ VIEW ACKNOWLEDGMENT RECEIPT ====================
  String _getFileType(String url) {
    final urlLower = url.toLowerCase();
    if (urlLower.endsWith('.pdf') || urlLower.contains('.pdf')) return 'pdf';
    if (urlLower.endsWith('.jpg') ||
        urlLower.endsWith('.jpeg') ||
        urlLower.endsWith('.png') ||
        urlLower.endsWith('.webp')) return 'image';
    if (urlLower.contains('cloudinary.com')) return 'cloudinary';
    return 'unknown';
  }

  void _viewAcknowledgmentReceipt() {
    final app = _selectedApplication!;
    final documentUrl = app['submitted_document_url'] ?? app['final_document_url'];
    final documentName = app['submitted_document_name'] ??
        app['final_document_name'] ??
        'Service Document';

    if (documentUrl == null || documentUrl.isEmpty) {
      showMessage(context, "No document available for this application.",
          isError: true);
      return;
    }

    debugPrint("📄 Viewing Acknowledgment Receipt for service application");
    debugPrint("🔗 Document URL: $documentUrl");
    debugPrint("📁 Document Name: $documentName");

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          height: MediaQuery.of(dialogContext).size.height * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FileViewerScreen(
              url: documentUrl,
              title: documentName,
              downloadUrl: documentUrl,
              fileType: _getFileType(documentUrl),
              fileName: documentName,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== STATUS DISPLAY METHODS ====================
  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'payment_pending':
        return 'PAYMENT PENDING';
      case 'pending_verification':
        return 'PENDING VERIFICATION';
      case 'under_review':
        return 'UNDER REVIEW';
      case 'review_application':
        return 'UNDER REVIEW';
      case 'approved':
        return 'APPROVED ✅';
      case 'rejected':
        return 'REJECTED ❌';
      case 'completed':
        return 'COMPLETED ✅';
      case 'submitted':
        return 'SUBMITTED';
      case 'update_application':
        return 'UPDATE SUBMITTED';
      case 'final_submit':
        return 'FINAL SUBMITTED';
      case 'confirmed_application':
        return 'CONFIRMED ✅';
      default:
        return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'payment_pending':
        return Colors.purple;
      case 'pending_verification':
        return Colors.orange;
      case 'under_review':
        return Colors.blue;
      case 'review_application':
        return Colors.blue;
      case 'approved':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'submitted':
        return Colors.green;
      case 'update_application':
        return Colors.orange;
      case 'final_submit':
        return Colors.deepPurple;
      case 'confirmed_application':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'payment_pending':
        return 'Waiting for user to complete payment';
      case 'pending_verification':
        return 'Payment receipt submitted, waiting for verification';
      case 'under_review':
        return 'Application is being reviewed by admin';
      case 'review_application':
        return 'Application is under review';
      case 'approved':
        return 'Payment verified and application approved';
      case 'rejected':
        return 'Payment verification failed';
      case 'completed':
        return 'Application completed successfully';
      default:
        return 'Status updated';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'payment_pending':
        return Icons.payment;
      case 'pending_verification':
        return Icons.hourglass_empty;
      case 'under_review':
      case 'review_application':
        return Icons.rate_review;
      case 'approved':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      case 'completed':
        return Icons.celebration;
      case 'submitted':
        return Icons.check_circle;
      case 'update_application':
        return Icons.edit_note;
      case 'final_submit':
        return Icons.send_and_archive;
      case 'confirmed_application':
        return Icons.check_circle;
      default:
        return Icons.pending;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    if (value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ✅ BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading service applications..."),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Failed to load applications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadApplications,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedApplication != null) {
      return _buildApplicationDetailView(_selectedApplication!);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Service Applications"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: _applications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _applications.length,
              itemBuilder: (context, index) {
                final app = _applications[index];
                return _buildApplicationCard(app);
              },
            ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final serviceName =
        app['display_service_name'] ?? app['service_name'] ?? 'Service';
    final subServiceName =
        app['display_sub_service_name'] ?? app['sub_service_name'] ?? '';
    final serviceIcon = app['display_service_icon'] ?? '📄';
    final userName = app['user_name'] ?? 'Unknown';
    final userEmail = app['user_email'] ?? 'N/A';

    final status = app['status'] ?? 'payment_pending';
    final statusColor = _getStatusColor(status);
    final appliedDate = _formatDate(app['applied_at'] ?? app['created_at']);
    final hasScreenshot = app['screenshot_url'] != null &&
        app['screenshot_url'].toString().isNotEmpty;
    final hasDocument = app['document_url'] != null &&
        app['document_url'].toString().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          userEmail,
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
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusDisplay(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
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
                child: Row(
                  children: [
                    Text(
                      serviceIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (subServiceName.isNotEmpty)
                            Text(
                              subServiceName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.calendar_today,
                    "Applied",
                    appliedDate,
                  ),
                  if (app['amount'] != null)
                    _buildInfoChip(
                      Icons.currency_rupee,
                      "Fee",
                      "₹${app['amount']}",
                      color: Colors.green,
                    ),
                  if (hasScreenshot)
                    _buildInfoChip(
                      Icons.image,
                      "Receipt",
                      "Uploaded",
                      color: Colors.orange,
                    ),
                  if (hasDocument)
                    _buildInfoChip(
                      Icons.upload_file,
                      "Doc",
                      "Uploaded",
                      color: Colors.teal,
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
                      label: const Text("View Details"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
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
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value,
      {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey),
          const SizedBox(width: 4),
          Text(
            "$label: $value",
            style: TextStyle(fontSize: 11, color: color ?? Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            "No service applications yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Applications submitted by users will appear here",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ==================== APPLICATION DETAIL VIEW ====================
  Widget _buildApplicationDetailView(Map<String, dynamic> app) {
    final serviceName =
        app['display_service_name'] ?? app['service_name'] ?? 'Service';
    final subServiceName =
        app['display_sub_service_name'] ?? app['sub_service_name'] ?? '';
    final serviceIcon = app['display_service_icon'] ?? '📄';

    final status = app['status'] ?? 'payment_pending';
    final statusColor = _getStatusColor(status);
    final userName = app['user_name'] ?? 'Unknown';
    final userEmail = app['user_email'] ?? 'N/A';
    final appliedDate = _formatDate(app['applied_at'] ?? app['created_at']);
    final hasDocument = app['document_url'] != null &&
        app['document_url'].toString().isNotEmpty;
    final hasScreenshot = app['screenshot_url'] != null &&
        app['screenshot_url'].toString().isNotEmpty;
    final fields = app['fields'] as Map<String, dynamic>? ?? {};

    // ✅ Check if document exists for acknowledgment receipt
    final hasSubmittedDocument = app['submitted_document_url'] != null &&
        app['submitted_document_url'].toString().isNotEmpty &&
        app['submitted_document_url'] != 'null';

    final hasFinalDocument = app['final_document_url'] != null &&
        app['final_document_url'].toString().isNotEmpty &&
        app['final_document_url'] != 'null';

    final hasAnyDocument = hasSubmittedDocument || hasFinalDocument;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Application Details"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeDetails,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadApplications();
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
            _buildStatusCard(app['_id'], status, statusColor),
            const SizedBox(height: 16),
            _buildUserCard(userName, userEmail, appliedDate),
            const SizedBox(height: 16),
            _buildServiceCard(serviceName, subServiceName, serviceIcon, app),
            const SizedBox(height: 16),
            _buildFieldsCard(fields),
            const SizedBox(height: 16),
            _buildPaymentVerificationSection(
              app['payment_id'],
              app['transaction_id'],
              app['transaction_date'],
              app['payment_receipt_url'] ?? app['screenshot_url'],
              app['payment_amount'] ?? app['amount'],
              app['payment_category_used'],
              status,
              app['_id'],
            ),
            const SizedBox(height: 16),
            _buildScreenshotCard(app['screenshot_url'], hasScreenshot),
            const SizedBox(height: 16),
            _buildDocumentCard(app['document_url'], hasDocument),
            const SizedBox(height: 16),

            // ==================== ✅ VIEW ACKNOWLEDGMENT RECEIPT ====================
            if (hasAnyDocument)
              _buildViewAcknowledgmentReceiptButton(),
            if (hasAnyDocument) const SizedBox(height: 16),

            _buildQuickActionButtons(app['_id'], status),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ==================== ✅ VIEW ACKNOWLEDGMENT RECEIPT BUTTON ====================
  Widget _buildViewAcknowledgmentReceiptButton() {
    final app = _selectedApplication!;
    final documentName = app['submitted_document_name'] ??
        app['final_document_name'] ??
        'Service Document';

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
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Acknowledgment Receipt",
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
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      documentName,
                      style: const TextStyle(fontSize: 13, color: Colors.indigo),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _viewAcknowledgmentReceipt,
                icon: const Icon(Icons.visibility, size: 20),
                label: const Text(
                  "View Receipt Document",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
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
  Widget _buildStatusCard(String appId, String status, Color statusColor) {
    if (status == 'rejected' || status == 'completed') {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Payment Status",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'completed' ? Icons.check_circle : Icons.cancel,
                      color: statusColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusDisplay(status),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          Text(
                            _getStatusDescription(status),
                            style: TextStyle(
                              fontSize: 13,
                              color: statusColor.withAlpha(179),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status == 'completed'
                            ? "✅ Application completed. No further action needed."
                            : "❌ Payment rejected. User may need to re-apply.",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUpdatingStatus)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Application Status",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withAlpha(51)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: statusColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStatusDisplay(status),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          _getStatusDescription(status),
                          style: TextStyle(
                            fontSize: 13,
                            color: statusColor.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (status == 'pending_verification')
              _buildPaymentVerificationButtons(appId),
            if (status != 'rejected' && status != 'completed' && status != 'pending_verification')
              _buildReviewActionButtons(appId),
            if (status == 'payment_pending')
              _buildPaymentPendingInfo(),
            if (_isUpdatingStatus)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentVerificationButtons(String appId) {
    return Column(
      children: [
        const Text(
          "Verify Payment:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUpdatingStatus
                    ? null
                    : () => _approvePayment(_selectedApplication!['payment_id'], appId),
                icon: const Icon(Icons.check, size: 18),
                label: const Text("Approve"),
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
                    : () => _rejectPayment(_selectedApplication!['payment_id'], appId),
                icon: const Icon(Icons.close, size: 18),
                label: const Text("Reject"),
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
                  "✅ Approve: Status changes to APPROVED\n❌ Reject: Status changes to REJECTED",
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewActionButtons(String appId) {
    return Column(
      children: [
        const Text(
          "Next Steps:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isUpdatingStatus ? null : () => _showReviewDialog(appId),
                icon: const Icon(Icons.rate_review, size: 18),
                label: const Text(
                  "Review",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isUpdatingStatus ? null : () => _showFinalSubmitDialog(appId),
                icon: const Icon(Icons.send_and_archive, size: 18),
                label: const Text(
                  "Final Submit",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "📝 REVIEW: Upload document and change status to UNDER REVIEW\n"
                  "✅ FINAL SUBMIT: Complete the application",
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentPendingInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "⏳ Waiting for user to complete payment.",
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== USER CARD ====================
  Widget _buildUserCard(String name, String email, String appliedDate) {
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

  // ==================== SERVICE CARD ====================
  Widget _buildServiceCard(String serviceName, String subServiceName,
      String serviceIcon, Map<String, dynamic> app) {
    final amount = app['amount'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Service Details",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.workspace_premium,
              "Service",
              "$serviceIcon $serviceName",
            ),
            if (subServiceName.isNotEmpty)
              _buildInfoRow(
                Icons.label,
                "Sub-Service",
                subServiceName,
              ),
            if (amount != null)
              _buildInfoRow(
                Icons.currency_rupee,
                "Fee",
                "₹$amount",
              ),
            _buildInfoRow(
              Icons.category,
              "Payment Type",
              "Service Fee",
              color: Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FIELDS CARD ====================
  Widget _buildFieldsCard(Map<String, dynamic> fields) {
    if (fields.isEmpty) return const SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Submitted Information",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...fields.entries.map(
              (entry) => _buildInfoRow(
                Icons.info_outline,
                entry.key.replaceAll('_', ' ').toUpperCase(),
                entry.value?.toString() ?? '',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PAYMENT VERIFICATION SECTION ====================
  Widget _buildPaymentVerificationSection(
    String? paymentId,
    String? transactionId,
    String? transactionDate,
    String? paymentReceiptUrl,
    int? paymentAmount,
    String? paymentCategory,
    String status,
    String applicationId,
  ) {
    if (status != 'pending_verification') {
      return const SizedBox();
    }

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
                const Icon(Icons.verified, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
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
                "Payment Type",
                "Service Fee",
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
                        : () => _approvePayment(paymentId!, applicationId),
                    icon: _isUpdatingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
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
                        : () => _rejectPayment(paymentId!, applicationId),
                    icon: _isUpdatingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close, size: 18),
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
                      "✅ Approve: Status changes to APPROVED\n❌ Reject: Status changes to REJECTED",
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
            if (_isUpdatingStatus)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== SCREENSHOT CARD ====================
  Widget _buildScreenshotCard(String? screenshotUrl, bool hasScreenshot) {
    if (!hasScreenshot) return const SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Payment Screenshot",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.image, color: Colors.orange),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text("Screenshot uploaded for payment verification"),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _viewDocument(screenshotUrl!, "Payment Screenshot"),
                  icon: const Icon(Icons.visibility),
                  label: const Text("View"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DOCUMENT CARD ====================
  Widget _buildDocumentCard(String? documentUrl, bool hasDocument) {
    if (!hasDocument) return const SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Uploaded Document",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.upload_file, color: Colors.teal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text("Document uploaded with the application"),
                ),
                ElevatedButton.icon(
                  onPressed: () => _viewDocument(documentUrl!, "Document"),
                  icon: const Icon(Icons.visibility),
                  label: const Text("View"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== QUICK ACTION BUTTONS ====================
  Widget _buildQuickActionButtons(String appId, String currentStatus) {
    final bool showButtons = currentStatus != 'rejected' && currentStatus != 'completed';

    if (!showButtons) {
      return const SizedBox();
    }

    if (currentStatus == 'payment_pending') {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Status Information",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payment, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "PAYMENT PENDING",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "⏳ Waiting for user to complete payment",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _showReviewDialog(appId),
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text(
                      "Review",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _showFinalSubmitDialog(appId),
                    icon: const Icon(Icons.send_and_archive, size: 18),
                    label: const Text(
                      "Final Submit",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "📝 REVIEW: Upload document and change status to UNDER REVIEW\n"
                      "✅ FINAL SUBMIT: Complete the application",
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            if (_isUpdatingStatus)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== REVIEW DIALOG CONTENT ====================
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
      final result = await FilePicker.platform.pickFiles(
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
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.rate_review,
                    color: Colors.blue,
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
                      color: Colors.blue,
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "This will change status to UNDER REVIEW. Document will be saved.",
                      style: TextStyle(fontSize: 12, color: Colors.blue),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                              ? Colors.blue.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFileName != null
                                ? Colors.blue
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
                                  ? Colors.blue
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
                                    ? Colors.blue
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

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "ℹ️ After review, the application status will change to UNDER REVIEW.",
                              style: TextStyle(fontSize: 11, color: Colors.blue),
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
                      backgroundColor: Colors.blue,
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

class _FinalSubmitDialogContentState extends State<_FinalSubmitDialogContent> {
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
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
                      "⚠️ FINAL SUBMISSION\nThis is the final step. The status will change to COMPLETED.",
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

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18,
                              color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "⚠️ This is FINAL submission. After this, no further changes are allowed.",
                              style: TextStyle(fontSize: 11,
                                  color: Colors.deepPurple),
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