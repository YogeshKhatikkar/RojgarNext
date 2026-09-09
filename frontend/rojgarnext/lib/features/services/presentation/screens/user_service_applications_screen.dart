// lib/features/services/presentation/screens/user_service_applications_screen.dart
// ✅ COMPLETE FIXED VERSION - With payment details displayed properly

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/widgets/file_viewer_screen.dart';
import 'package:rojgarnext/features/services/models/service_types.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/features/services/data/service_repository.dart';

class UserServiceApplicationScreen extends StatefulWidget {
  const UserServiceApplicationScreen({super.key});

  @override
  State<UserServiceApplicationScreen> createState() =>
      _UserServiceApplicationScreenState();
}

class _UserServiceApplicationScreenState
    extends State<UserServiceApplicationScreen> {
  List<dynamic> _applications = [];
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  Map<String, dynamic>? _selectedApplication;
  String? _errorMessage;
  String? _userEmail;

  final Map<String, Map<String, String>> _serviceDetailsCache = {};

  final List<Map<String, dynamic>> _filterButtons = [
    {'value': 'all', 'label': 'All', 'icon': Icons.list, 'color': Colors.grey},
    {
      'value': 'payment_pending',
      'label': 'Payment Pending',
      'icon': Icons.payment,
      'color': Colors.purple,
    },
    {
      'value': 'pending_verification',
      'label': 'Pending Verif',
      'icon': Icons.hourglass_empty,
      'color': Colors.orange,
    },
    {
      'value': 'under_review',
      'label': 'Under Review',
      'icon': Icons.rate_review,
      'color': Colors.blue,
    },
    {
      'value': 'review_application',
      'label': 'Under Review',
      'icon': Icons.rate_review,
      'color': Colors.blue,
    },
    {
      'value': 'approved',
      'label': 'Approved',
      'icon': Icons.verified,
      'color': Colors.teal,
    },
    {
      'value': 'rejected',
      'label': 'Rejected',
      'icon': Icons.cancel,
      'color': Colors.red,
    },
    {
      'value': 'completed',
      'label': 'Completed',
      'icon': Icons.celebration,
      'color': Colors.green,
    },
  ];

  String _selectedFilter = 'all';
  List<dynamic> _filteredApplications = [];

  @override
  void initState() {
    super.initState();
    _getUserEmail();
  }

  // ==================== GET USER EMAIL ====================
  Future<void> _getUserEmail() async {
    if (!mounted) return;
    try {
      final email = await SecureStorage.getEmail();
      if (email != null && email.isNotEmpty) {
        _userEmail = email;
        debugPrint("📧 User Email: $_userEmail");
        await _loadApplications();
      } else {
        setState(() => _isLoading = false);
        showMessage(context, "Could not get user email", isError: true);
      }
    } catch (e) {
      debugPrint("❌ Error getting user email: $e");
      setState(() => _isLoading = false);
    }
  }

  // ==================== GET SERVICE DISPLAY DETAILS ====================
  Map<String, String> _getServiceDisplayDetails(
      String serviceId, String subTypeId) {
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
    try {
      final apps = await ServiceRepository.getUserApplications();
      
      // ✅ DEBUG: Log the first application to see its structure
      if (apps.isNotEmpty) {
        final firstApp = apps.first as Map<String, dynamic>;
        debugPrint("📋 First application data structure:");
        debugPrint("🔍 All keys: ${firstApp.keys.toList()}");
        
        // Check for payment-related keys
        final paymentKeys = firstApp.keys.where((k) => 
          k.toString().toLowerCase().contains('payment') || 
          k.toString().toLowerCase().contains('verification') ||
          k.toString().toLowerCase().contains('transaction') ||
          k.toString().toLowerCase().contains('razorpay')
        ).toList();
        debugPrint("🔑 Payment-related keys: $paymentKeys");
        
        // Log payment data
        debugPrint("💰 payment_status: ${firstApp['payment_status']}");
        debugPrint("💰 razorpay_payment_id: ${firstApp['razorpay_payment_id']}");
        debugPrint("💰 transaction_id: ${firstApp['transaction_id']}");
        debugPrint("💰 payment_amount: ${firstApp['payment_amount']}");
        debugPrint("💰 payment_verified_at: ${firstApp['payment_verified_at']}");
        debugPrint("💰 payment_category_used: ${firstApp['payment_category_used']}");
        debugPrint("💰 status: ${firstApp['status']}");
      }
      
      if (mounted) {
        final enrichedApps = apps.map((app) {
          final appMap = app is Map<String, dynamic>
              ? app
              : Map<String, dynamic>.from(app as Map);

          final serviceId = appMap['service_id'] ?? '';
          final subTypeId = appMap['sub_type_id'] ?? '';
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
        _applyFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        showMessage(context, "Failed to load applications: $e", isError: true);
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'all') {
        _filteredApplications = _applications;
      } else {
        _filteredApplications = _applications
            .where((app) => (app['status'] ?? '').toString().toLowerCase() ==
                _selectedFilter.toLowerCase())
            .toList();
      }
    });
  }

  void _onFilterSelected(String filterValue) {
    setState(() {
      _selectedFilter = filterValue;
    });
    _applyFilter();
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
      debugPrint("🔄 Refreshing service application: $applicationId");

      final response = await DioClient.dio.get(
          '/services/application/$applicationId');

      if (!mounted) return;

      Map<String, dynamic> updatedApp = {};

      if (response.data != null && response.data is Map) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map);

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
              debugPrint(
                  "✅ Selected application updated with new status: ${enrichedApp['status']}");
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

  // ==================== ✅ CONFIRM SERVICE APPLICATION (USER ACTION) ====================
  Future<void> _confirmApplication(String applicationId) async {
    if (!mounted) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final response = await DioClient.dio.put(
        '/services/application/$applicationId/user-confirm',
        data: {'notes': 'Application confirmed by user'},
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(
          context,
          "✅ Service application confirmed successfully!",
        );

        await _refreshCurrentApplication(applicationId);

        await _sendBellNotification(
          applicationId: applicationId,
          status: 'confirmed_application',
          userEmail: _selectedApplication?['user_email'] ?? '',
          userName: _selectedApplication?['user_name'] ?? 'User',
          notes: 'Application confirmed by user',
        );
      } else {
        showMessage(
          context,
          response.data['message'] ?? "Failed to confirm application",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Failed to confirm: ${e.toString()}", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  // ==================== ✅ SHOW UPDATE APPLICATION DIALOG (USER ACTION) ====================
  void _showUpdateApplicationDialog() async {
    final status = _selectedApplication?['status'] ?? '';

    if (status != 'review_application' && status != 'under_review') {
      showMessage(context, "Application is not in review status",
          isError: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _UpdateApplicationDialog(),
    );

    if (result != null && mounted) {
      await _submitApplicationUpdate(result);
    }
  }

  // ==================== ✅ SUBMIT SERVICE APPLICATION UPDATE (USER ACTION) ====================
  Future<void> _submitApplicationUpdate(Map<String, dynamic> updateData) async {
    final applicationId = _selectedApplication!['_id'];

    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final response = await DioClient.dio.post(
        '/services/application/$applicationId/user-update',
        data: {
          'updates': updateData['fields'],
          'notes': updateData['notes'] ?? '',
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(
          context,
          "✅ Service application update submitted successfully! Admin will review.",
        );

        await _refreshCurrentApplication(applicationId);

        await _sendBellNotification(
          applicationId: applicationId,
          status: 'update_application',
          userEmail: _selectedApplication?['user_email'] ?? '',
          userName: _selectedApplication?['user_name'] ?? 'User',
          notes: 'Application update submitted by user',
        );
      } else {
        showMessage(
          context,
          response.data['message'] ?? "Failed to submit update",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Failed to submit: ${e.toString()}", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  // ==================== SEND BELL NOTIFICATION ====================
  Future<void> _sendBellNotification({
    required String applicationId,
    required String status,
    required String userEmail,
    required String userName,
    String? notes,
  }) async {
    try {
      final statusMessages = {
        'confirmed_application':
            '✅ Your service application has been confirmed successfully!',
        'update_application':
            '📝 Your service application update has been submitted for admin review.',
        'approved': '✅ Your service application has been approved!',
        'rejected': '❌ Your service application has been rejected.',
        'completed': '✅ Your service application has been completed!',
        'under_review': '📋 Your service application is under review.',
        'review_application': '📋 Your service application is under review.',
        'payment_pending': '⏳ Payment pending. Please complete the payment.',
        'pending_verification': '⏳ Your payment is pending verification.',
      };

      final Map<String, dynamic> metadata = {
        'application_id': applicationId,
        'status': status,
        'service_name':
            _selectedApplication?['display_service_name'] ?? 'Service',
        'sub_service_name':
            _selectedApplication?['display_sub_service_name'] ?? '',
        'show_blue_bell': true,
        'user_name': userName,
      };

      if (notes != null && notes.isNotEmpty) {
        metadata['notes'] = notes;
      }

      await DioClient.dio.post(
        '/notification/admin/broadcast',
        data: {
          'title': statusMessages[status] ??
              "Service Application Status: ${status.toUpperCase()}",
          'message': statusMessages[status] ??
              "Your service application status has been updated to ${status.toUpperCase()}.",
          'metadata': metadata,
        },
      );

      debugPrint("🔔 BELL notification sent to user: $userEmail");
    } catch (e) {
      debugPrint("❌ Failed to send bell notification: $e");
    }
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
      case 'payment_verified':
        return 'PAYMENT VERIFIED ✅';
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
      case 'payment_verified':
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  // ✅ UPDATED: Payment Information Display with better extraction
  Widget _buildPaymentInfoRow(IconData icon, String label, String value,
      {Color? color}) {
    if (value.isEmpty || value == 'N/A' || value == 'null') {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
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

    // ✅ FIXED: Direct database field mapping
    // Payment status from database - 'completed', 'pending', 'failed'
    final paymentStatus = app['payment_status']?.toString() ?? 'pending';
    
    // Transaction ID - using razorpay_payment_id or transaction_id
    final transactionId = 
        app['razorpay_payment_id']?.toString() ?? 
        app['transaction_id']?.toString() ?? 
        'N/A';
    
    // Payment amount
    final paymentAmount = 
        app['payment_amount'] != null 
            ? '₹${app['payment_amount']}' 
            : app['amount'] != null 
                ? '₹${app['amount']}'
                : 'N/A';
    
    // Payment date - using payment_verified_at or applied_at
    final transactionDate = 
        app['payment_verified_at'] != null 
            ? _formatDate(app['payment_verified_at'].toString()) 
            : app['applied_at'] != null 
                ? _formatDate(app['applied_at'].toString())
                : 'N/A';
    
    // Payment method - from payment_category_used
    final paymentMethod = 
        app['payment_category_used']?.toString() ?? 
        app['payment_method']?.toString() ?? 
        'N/A';
    
    // Payment receipt URL - from screenshot_url or document_url
    final paymentReceiptUrl = 
        app['screenshot_url'] ?? 
        app['payment_receipt_url'] ??
        app['receipt_url'];
    
    // ✅ IMPORTANT: Verification status is determined by the application status
    // If payment_status is 'completed' and status is 'payment_verified' or 'approved'
    String verificationStatus = 'not_submitted';
    if (paymentStatus.toLowerCase() == 'completed' && 
        (status.toLowerCase() == 'payment_verified' || 
         status.toLowerCase() == 'approved' || 
         status.toLowerCase() == 'completed')) {
      verificationStatus = 'approved';
    } else if (paymentStatus.toLowerCase() == 'pending') {
      verificationStatus = 'pending';
    } else if (status.toLowerCase() == 'rejected') {
      verificationStatus = 'rejected';
    }
    
    final rejectionReason = app['rejection_reason'] ?? app['verification_notes'];

    // Check if document exists for acknowledgment receipt
    final hasSubmittedDocument = app['submitted_document_url'] != null &&
        app['submitted_document_url'].toString().isNotEmpty &&
        app['submitted_document_url'] != 'null';

    final hasFinalDocument = app['final_document_url'] != null &&
        app['final_document_url'].toString().isNotEmpty &&
        app['final_document_url'] != 'null';

    final hasAnyDocument = hasSubmittedDocument || hasFinalDocument;

    // ✅ Debug log to verify data
    debugPrint('📊 Payment Data:');
    debugPrint('  - payment_status: $paymentStatus');
    debugPrint('  - transaction_id: $transactionId');
    debugPrint('  - payment_amount: $paymentAmount');
    debugPrint('  - payment_verified_at: $transactionDate');
    debugPrint('  - payment_category_used: $paymentMethod');
    debugPrint('  - verification_status: $verificationStatus');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Service Application Details"),
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
            // ✅ Payment Information Card with corrected data
            _buildPaymentInformationCard(
              paymentStatus: paymentStatus,
              transactionId: transactionId,
              transactionDate: transactionDate,
              paymentAmount: paymentAmount,
              paymentReceiptUrl: paymentReceiptUrl,
              verificationStatus: verificationStatus,
              rejectionReason: rejectionReason,
              paymentMethod: paymentMethod,
            ),
            const SizedBox(height: 16),
            _buildScreenshotCard(app['screenshot_url'], hasScreenshot),
            const SizedBox(height: 16),
            _buildDocumentCard(app['document_url'], hasDocument),
            const SizedBox(height: 16),
            // View Acknowledgment Receipt
            if (hasAnyDocument) _buildViewAcknowledgmentReceiptButton(),
            if (hasAnyDocument) const SizedBox(height: 16),
            // User Action Buttons
            if (status == 'review_application' || status == 'under_review')
              _buildUserActionButtons(app['_id'], status),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ==================== ✅ PAYMENT INFORMATION CARD (UPDATED) ====================
  Widget _buildPaymentInformationCard({
    required String paymentStatus,
    required String transactionId,
    required String transactionDate,
    required String paymentAmount,
    required String? paymentReceiptUrl,
    required String verificationStatus,
    required String? rejectionReason,
    required String paymentMethod,
  }) {
    // ✅ Get display text for verification status
    String getVerificationDisplay(String status) {
      switch (status.toLowerCase()) {
        case 'approved':
          return '✅ Approved';
        case 'rejected':
          return '❌ Rejected';
        case 'pending':
          return '⏳ Pending';
        case 'not_submitted':
          return '📤 Not Submitted';
        case 'submitted':
          return '📤 Submitted';
        case 'under_review':
          return '🔍 Under Review';
        default:
          return status;
      }
    }

    Color getVerificationColor(String status) {
      switch (status.toLowerCase()) {
        case 'approved':
          return Colors.green;
        case 'rejected':
          return Colors.red;
        case 'pending':
        case 'under_review':
          return Colors.orange;
        case 'not_submitted':
          return Colors.grey;
        case 'submitted':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    // ✅ Get display text for payment status
    String getPaymentStatusDisplay(String status) {
      switch (status.toLowerCase()) {
        case 'completed':
          return '✅ Completed';
        case 'pending':
          return '⏳ Pending';
        case 'failed':
          return '❌ Failed';
        case 'not_initiated':
          return '📤 Not Initiated';
        default:
          return status;
      }
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
                const Icon(Icons.payment, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  "Payment Information",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPaymentStatusColor(paymentStatus),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    getPaymentStatusDisplay(paymentStatus),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ Transaction ID - Using razorpay_payment_id
            _buildPaymentInfoRow(
                Icons.receipt, "Transaction ID", transactionId),
            const Divider(height: 24),
            
            // ✅ Transaction Date - Using payment_verified_at
            _buildPaymentInfoRow(
                Icons.calendar_today, "Transaction Date", transactionDate),
            const Divider(height: 24),
            
            // ✅ Amount - Using payment_amount
            _buildPaymentInfoRow(
                Icons.currency_rupee, "Amount", paymentAmount,
                color: Colors.green),
            const Divider(height: 24),
            
            // ✅ Payment Method - Using payment_category_used
            _buildPaymentInfoRow(
                Icons.credit_card, "Payment Method", paymentMethod),
            const Divider(height: 24),
            
            // ✅ Verification Status - Derived from payment_status and application status
            _buildPaymentInfoRow(
                Icons.verified, "Verification Status", 
                getVerificationDisplay(verificationStatus),
                color: getVerificationColor(verificationStatus)),

            // Rejection Reason (if any)
            if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Rejection Reason: $rejectionReason",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // View Payment Receipt Button
            if (paymentReceiptUrl != null && paymentReceiptUrl.isNotEmpty) ...[
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentReceiptDialog(paymentReceiptUrl),
                  icon: const Icon(Icons.receipt, size: 18),
                  label: const Text(
                    "View Payment Receipt",
                    style: TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ==================== VIEW ACKNOWLEDGMENT RECEIPT BUTTON ====================
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

  // ==================== USER ACTION BUTTONS (Confirm & Update) ====================
  Widget _buildUserActionButtons(String appId, String currentStatus) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Take Action",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Your application is currently under review. You can confirm it or submit updates:",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // VIEW DOCUMENT BUTTON (if document exists)
            if (_selectedApplication != null &&
                _selectedApplication!['document_url'] != null &&
                _selectedApplication!['document_url'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final docUrl =
                          _selectedApplication!['document_url'].toString();
                      _viewDocument(docUrl, "Application Document");
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text("View Uploaded Document"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

            Row(
              children: [
                // CONFIRM BUTTON
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _confirmApplication(appId),
                    icon: _isUpdatingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle, size: 18),
                    label: const Text(
                      "Confirm Application",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                // UPDATE BUTTON
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : _showUpdateApplicationDialog,
                    icon: _isUpdatingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_note, size: 18),
                    label: const Text(
                      "Update Application",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "✅ CONFIRM: Accept the application as is\n"
                      "✏️ UPDATE: Provide additional information or corrections",
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

  // ==================== STATUS CARD ====================
  Widget _buildStatusCard(String appId, String status, Color statusColor) {
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

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'payment_pending':
        return 'Waiting for you to complete payment';
      case 'pending_verification':
        return 'Payment receipt submitted, waiting for admin verification';
      case 'under_review':
        return 'Application is being reviewed by admin';
      case 'review_application':
        return 'Application is under review. Please take action.';
      case 'approved':
        return 'Payment verified and application approved!';
      case 'payment_verified':
        return 'Payment verified successfully!';
      case 'rejected':
        return 'Payment verification failed. You can re-apply.';
      case 'completed':
        return 'Application completed successfully!';
      case 'confirmed_application':
        return 'You have confirmed your application!';
      case 'update_application':
        return 'Your update has been submitted for admin review';
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
      case 'payment_verified':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      case 'completed':
        return Icons.celebration;
      case 'confirmed_application':
        return Icons.check_circle_outline;
      case 'update_application':
        return Icons.edit_note;
      default:
        return Icons.pending;
    }
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
    final amount = app['amount'] ?? app['payment_amount'];
    final userCategory = app['user_category'] ?? 'General/UR';

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
              "User Category",
              userCategory.toUpperCase(),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD METHOD ====================
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildFilterButtons(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: _filteredApplications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredApplications.length,
              itemBuilder: (context, index) {
                final app = _filteredApplications[index];
                return _buildApplicationCard(app);
              },
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
                    color: isSelected ? Colors.white : filter['color'],
                  ),
                  const SizedBox(width: 6),
                  Text(filter['label']),
                ],
              ),
              onSelected: (selected) {
                _onFilterSelected(selected ? filter['value'] : 'all');
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: filter['color'],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : filter['color'],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
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
    final paymentStatus = app['payment_status'] ?? 'pending';
    final amount = app['amount'] ?? app['payment_amount'];

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
                  if (amount != null)
                    _buildInfoChip(
                      Icons.currency_rupee,
                      "Fee",
                      "₹$amount",
                      color: Colors.green,
                    ),
                  _buildInfoChip(
                    Icons.payment,
                    "Payment",
                    paymentStatus.toUpperCase(),
                    color: _getPaymentStatusColor(paymentStatus),
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
            "Applications you submit will appear here",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ==================== UPDATE APPLICATION DIALOG (USER) ====================
class _UpdateApplicationDialog extends StatefulWidget {
  const _UpdateApplicationDialog();

  @override
  State<_UpdateApplicationDialog> createState() =>
      _UpdateApplicationDialogState();
}

class _UpdateApplicationDialogState extends State<_UpdateApplicationDialog> {
  final List<Map<String, dynamic>> _fields = [];
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addNewField();
  }

  void _addNewField() {
    setState(() {
      _fields.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': '',
        'value': '',
      });
    });
  }

  void _removeField(String id) {
    setState(() {
      _fields.removeWhere((field) => field['id'] == id);
    });
  }

  void _updateField(String id, String key, String value) {
    setState(() {
      final index = _fields.indexWhere((field) => field['id'] == id);
      if (index != -1) {
        _fields[index][key] = value;
      }
    });
  }

  void _submit() {
    final validFields = _fields
        .where((field) =>
            field['name'].toString().trim().isNotEmpty &&
            field['value'].toString().trim().isNotEmpty)
        .toList();

    if (validFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add at least one field with name and value"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = {
      'fields': validFields
          .map((field) => {
                'field_name': field['name'].toString().trim(),
                'field_value': field['value'].toString().trim(),
              })
          .toList(),
      'notes': _notesController.text.trim(),
    };

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      const Icon(Icons.edit_note, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "Update Service Application Details",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context),
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
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Add the information you want to update. Click + to add multiple fields.",
                      style:
                          TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      "Fields to Update",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 2,
                            child: Text(
                              "Field Name",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Text(
                              "Value",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._fields.asMap().entries.map((entry) {
                      final index = entry.key;
                      final field = entry.value;
                      final fieldId = field['id'] as String;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: field['name'],
                                decoration: InputDecoration(
                                  hintText: "e.g., Enter Field Name",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (value) =>
                                    _updateField(fieldId, 'name', value),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: field['value'],
                                decoration: InputDecoration(
                                  hintText: "Enter Correct Value",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (value) =>
                                    _updateField(fieldId, 'value', value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                if (index == _fields.length - 1)
                                  InkWell(
                                    onTap: _addNewField,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.add,
                                          color: Colors.green, size: 18),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                if (_fields.length > 1)
                                  InkWell(
                                    onTap: () => _removeField(fieldId),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.remove,
                                          color: Colors.red, size: 18),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    const Text(
                      "Additional Notes (Optional)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            "Add any additional information or comments...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, size: 18),
                        SizedBox(width: 8),
                        Text("Submit Update"),
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