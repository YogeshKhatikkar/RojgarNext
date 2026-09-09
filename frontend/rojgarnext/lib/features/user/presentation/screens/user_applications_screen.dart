// lib/features/user/presentation/screens/user_applications_screen.dart
// COMPLETE FIXED VERSION

import 'package:flutter/material.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/widgets/file_viewer_screen.dart';

class UserApplicationsScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplicationSelected;
  final bool showAppBar;

  const UserApplicationsScreen({
    super.key,
    required this.onApplicationSelected,
    this.showAppBar = true,
  });

  @override
  State<UserApplicationsScreen> createState() => _UserApplicationsScreenState();
}

class _UserApplicationsScreenState extends State<UserApplicationsScreen> {
  List<dynamic> applications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final response = await DioClient.dio.get('/jobs/my-applications');
      if (mounted) {
        if (response.data is Map) {
          final data = response.data;
          if (data.containsKey('data') && data['data'] is Map) {
            applications = data['data']['applications'] ?? [];
          } else if (data.containsKey('applications')) {
            applications = data['applications'] ?? [];
          } else {
            applications = [];
          }
        } else {
          applications = response.data ?? [];
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to load applications: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _fetchApplications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text("My Applications"),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : applications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: applications.length,
                    itemBuilder: (context, index) {
                      final app = applications[index];
                      return _buildApplicationCard(app);
                    },
                  ),
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
          SizedBox(height: 16),
          Text(
            "No applications yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Applications you submit will appear here",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final status = app['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final appliedDate = _formatDate(app['applied_at']);
    final jobTitle = app['job_title'] ?? 'Job Opportunity';
    final organization = app['organization'] ?? 'Company';

    final hasSubmittedDocument = app['submitted_document_url'] != null &&
        app['submitted_document_url'].toString().isNotEmpty &&
        app['submitted_document_url'] != 'null';

    // ✅ FIXED: Wrap ListTile in Material widget
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => widget.onApplicationSelected(app),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor.withAlpha(25),
                      child: Icon(_getStatusIcon(status), color: statusColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jobTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            organization,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        color: statusColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusDisplay(status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(Icons.calendar_today, "Applied", appliedDate),
                    if (app['match_score'] != null)
                      _buildInfoChip(
                        Icons.auto_awesome,
                        "Match",
                        "${app['match_score']}%",
                      ),
                    if (hasSubmittedDocument)
                      _buildInfoChip(
                        Icons.upload_file,
                        "Doc",
                        "Uploaded",
                        color: Colors.teal,
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

  Widget _buildInfoChip(IconData icon, String label, String value,
      {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 4),
          Text("$label: $value",
              style: TextStyle(fontSize: 12, color: color ?? Colors.grey)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.green;
      case 'shortlisted':
        return Colors.blue;
      case 'interview':
        return Colors.orange;
      case 'offered':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'pending_verification':
        return Colors.purple;
      case 'verification_successful':
        return Colors.teal;
      case 'verification_rejected':
        return Colors.deepOrange;
      case 'review_application':
        return Colors.orange;
      case 'confirmed_application':
        return Colors.green;
      case 'update_application':
        return Colors.blue;
      case 'final_submit':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'pending_verification':
        return 'PENDING VERIFICATION';
      case 'verification_successful':
        return 'VERIFICATION SUCCESSFUL';
      case 'verification_rejected':
        return 'VERIFICATION REJECTED';
      case 'review_application':
        return 'UNDER REVIEW';
      case 'confirmed_application':
        return 'CONFIRMED';
      case 'update_application':
        return 'UPDATE SUBMITTED';
      case 'final_submit':
        return 'FINAL SUBMITTED';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Icons.check_circle;
      case 'shortlisted':
        return Icons.star;
      case 'interview':
        return Icons.people;
      case 'offered':
        return Icons.celebration;
      case 'rejected':
        return Icons.cancel;
      case 'pending_verification':
        return Icons.hourglass_empty;
      case 'verification_successful':
        return Icons.verified;
      case 'verification_rejected':
        return Icons.cancel_outlined;
      case 'review_application':
        return Icons.rate_review;
      case 'confirmed_application':
        return Icons.check_circle_outline;
      case 'update_application':
        return Icons.edit_note;
      case 'final_submit':
        return Icons.send_and_archive;
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
}

// ==================== APPLICATION DETAIL SCREEN ====================

class ApplicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;
  final VoidCallback onBack;
  final Function(Map<String, dynamic>) onViewJob;

  const ApplicationDetailScreen({
    super.key,
    required this.application,
    required this.onBack,
    required this.onViewJob,
  });

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _jobDetails;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchJobDetails();
  }

  Future<void> _fetchJobDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final jobId = widget.application['job_id'];
      if (jobId != null) {
        final jobRes = await DioClient.dio.get('/jobs/$jobId');
        _jobDetails = jobRes.data;
      }
    } catch (e) {
      debugPrint("Error fetching job details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.green;
      case 'shortlisted':
        return Colors.blue;
      case 'interview':
        return Colors.orange;
      case 'offered':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'pending_verification':
        return Colors.purple;
      case 'verification_successful':
        return Colors.teal;
      case 'verification_rejected':
        return Colors.deepOrange;
      case 'review_application':
        return Colors.orange;
      case 'confirmed_application':
        return Colors.green;
      case 'update_application':
        return Colors.blue;
      case 'final_submit':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'pending_verification':
        return 'PENDING VERIFICATION';
      case 'verification_successful':
        return 'VERIFICATION SUCCESSFUL';
      case 'verification_rejected':
        return 'VERIFICATION REJECTED';
      case 'review_application':
        return 'UNDER REVIEW';
      case 'confirmed_application':
        return 'CONFIRMED';
      case 'update_application':
        return 'UPDATE SUBMITTED';
      case 'final_submit':
        return 'FINAL SUBMITTED';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Icons.check_circle;
      case 'shortlisted':
        return Icons.star;
      case 'interview':
        return Icons.people;
      case 'offered':
        return Icons.celebration;
      case 'rejected':
        return Icons.cancel;
      case 'pending_verification':
        return Icons.hourglass_empty;
      case 'verification_successful':
        return Icons.verified;
      case 'verification_rejected':
        return Icons.cancel_outlined;
      case 'review_application':
        return Icons.rate_review;
      case 'confirmed_application':
        return Icons.check_circle_outline;
      case 'update_application':
        return Icons.edit_note;
      case 'final_submit':
        return Icons.send_and_archive;
      default:
        return Icons.pending;
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String? _getSubmittedDocumentUrl() {
    final url = widget.application['submitted_document_url'] ??
        widget.application['submittedDocumentUrl'] ??
        widget.application['document_url'] ??
        widget.application['documentUrl'];

    if (url != null && url.toString().isNotEmpty && url.toString() != 'null') {
      debugPrint("✅ Found submitted document URL: $url");
      return url.toString();
    }
    return null;
  }

  String? _getSubmittedDocumentName() {
    final name = widget.application['submitted_document_name'] ??
        widget.application['submittedDocumentName'] ??
        widget.application['document_name'] ??
        widget.application['documentName'];

    if (name != null &&
        name.toString().isNotEmpty &&
        name.toString() != 'null') {
      return name.toString();
    }
    return 'Application Document';
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

  void _viewApplicationDocument() {
    final submittedDocumentUrl = _getSubmittedDocumentUrl();
    final submittedDocumentName = _getSubmittedDocumentName();

    if (submittedDocumentUrl == null || submittedDocumentUrl.isEmpty) {
      showMessage(context,
          "No document available for this application.\n\nDocument may not have been uploaded yet.",
          isError: true);
      return;
    }

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
              url: submittedDocumentUrl,
              title: submittedDocumentName ?? "Application Document",
              downloadUrl: submittedDocumentUrl,
              fileType: _getFileType(submittedDocumentUrl),
              fileName: submittedDocumentName,
            ),
          ),
        ),
      ),
    );
  }

  String _getFileType(String url) {
    final urlLower = url.toLowerCase();
    if (urlLower.endsWith('.pdf') || urlLower.contains('.pdf')) {
      return 'pdf';
    }
    if (urlLower.endsWith('.jpg') ||
        urlLower.endsWith('.jpeg') ||
        urlLower.endsWith('.png') ||
        urlLower.endsWith('.webp') ||
        urlLower.endsWith('.gif')) {
      return 'image';
    }
    if (urlLower.contains('cloudinary.com')) {
      return 'cloudinary';
    }
    return 'unknown';
  }

  Future<void> _confirmApplication() async {
    final applicationId = widget.application['_id'];
    final status = widget.application['status'];

    if (status != 'review_application') {
      showMessage(context, "Application is not in review status",
          isError: true);
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final response = await DioClient.dio.put(
        '/jobs/applications/$applicationId/user-status',
        queryParameters: {
          'status': 'confirmed_application',
          'notes': 'Application confirmed by user',
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true || response.statusCode == 200) {
        showMessage(context, "✅ Application confirmed successfully!");
        widget.onBack();
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
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showUpdateApplicationDialog() async {
    final status = widget.application['status'];

    if (status != 'review_application') {
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

  Future<void> _submitApplicationUpdate(Map<String, dynamic> updateData) async {
    final applicationId = widget.application['_id'];

    setState(() => _isUpdating = true);

    try {
      final response = await DioClient.dio.post(
        '/jobs/applications/$applicationId/submit-update',
        data: {
          'updates': updateData['fields'],
          'notes': updateData['notes'] ?? '',
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true || response.statusCode == 200) {
        showMessage(context, "✅ Application update submitted successfully!");
        widget.onBack();
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
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Widget _buildStatusCard(String status, Color statusColor) {
    String statusSubtitle = "";

    switch (status.toLowerCase()) {
      case 'pending_verification':
        statusSubtitle = "Your payment is being verified by admin";
        break;
      case 'verification_successful':
        statusSubtitle =
            "Your payment has been verified. Application submitted!";
        break;
      case 'verification_rejected':
        statusSubtitle = "Your payment verification failed. You can re-apply.";
        break;
      case 'submitted':
        statusSubtitle = "Your document has been submitted for review";
        break;
      case 'review_application':
        statusSubtitle = "Application is under review. Please take action.";
        break;
      case 'confirmed_application':
        statusSubtitle = "Your application has been confirmed!";
        break;
      case 'update_application':
        statusSubtitle = "Your update has been submitted for admin review";
        break;
      case 'final_submit':
        statusSubtitle =
            "Final submission completed! Your application is now complete.";
        break;
      case 'shortlisted':
        statusSubtitle = "Congratulations! You've been shortlisted";
        break;
      case 'interview':
        statusSubtitle = "You have been selected for interview";
        break;
      case 'offered':
        statusSubtitle = "Congratulations! You've received an offer";
        break;
      case 'rejected':
        statusSubtitle = "Application not selected for this position";
        break;
      default:
        statusSubtitle = "Application status updated";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withAlpha(179)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_getStatusIcon(status), color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Current Status",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      _getStatusDisplay(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (statusSubtitle.isNotEmpty)
                      Text(
                        statusSubtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (status.toLowerCase() == 'verification_rejected')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text("Re-apply for this Job"),
                        content: const Text(
                            "Your payment verification was rejected. You can re-apply for this job with correct payment details.\n\nNote: You will need to make a new payment."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              if (_jobDetails != null) {
                                widget.onViewJob(_jobDetails!);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text("Re-apply Now"),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text("Re-apply for this Job"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnderReviewSection() {
    final documentUrl = _getSubmittedDocumentUrl();
    final hasDocument = documentUrl != null && documentUrl.isNotEmpty;
    final documentName = _getSubmittedDocumentName();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rate_review,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Application Under Review",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Your application is currently under review. You can view your submitted document and take action below:",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // View Document Button - Wrapped in Material
          SizedBox(
            width: double.infinity,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              color: hasDocument ? Colors.teal : Colors.grey,
              child: InkWell(
                onTap: hasDocument ? _viewApplicationDocument : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        hasDocument
                            ? "VIEW APPLICATION DOCUMENT"
                            : "NO DOCUMENT AVAILABLE",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (hasDocument && documentName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Document: $documentName",
                style: const TextStyle(fontSize: 12, color: Colors.teal),
                textAlign: TextAlign.center,
              ),
            ),

          if (!hasDocument)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "No document attached to this application.",
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          const Text(
            "Take Action:",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Material(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green,
                  child: InkWell(
                    onTap: _isUpdating ? null : _confirmApplication,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle,
                                  size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            "CONFIRM APPLICATION",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue,
                  child: InkWell(
                    onTap: _isUpdating ? null : _showUpdateApplicationDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.edit_note,
                                  size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            "UPDATE APPLICATION",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "✅ CONFIRM: Accept the application as is\n"
                    "✏️ UPDATE: Provide additional information or corrections",
                    style:
                        TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSubmitSection() {
    final documentUrl = _getSubmittedDocumentUrl();
    final hasDocument = documentUrl != null && documentUrl.isNotEmpty;
    final documentName = _getSubmittedDocumentName();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.send_and_archive,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Final Submission Completed",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Your application has been successfully submitted. You can view your submitted document below:",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // View Document Button - Wrapped in Material
          SizedBox(
            width: double.infinity,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              color: hasDocument ? Colors.deepPurple : Colors.grey,
              child: InkWell(
                onTap: hasDocument ? _viewApplicationDocument : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        hasDocument
                            ? "VIEW APPLICATION DOCUMENT"
                            : "NO DOCUMENT AVAILABLE",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (hasDocument && documentName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Document: $documentName",
                style: const TextStyle(fontSize: 12, color: Colors.deepPurple),
                textAlign: TextAlign.center,
              ),
            ),

          if (!hasDocument)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "No document attached to this application.",
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade800),
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

  Widget _buildJobInfoCard(
      Map<String, dynamic> app,
      Map<String, dynamic>? job,
    ) {
      final jobTitle = app['job_title'] ?? job?['post_name'] ?? 'Job Title';
      final organization =
          app['organization'] ?? job?['organization'] ?? 'Company';
      final appliedDate = _formatDate(app['applied_at']);
      final matchScore = app['match_score'];

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Job Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.work, "Job Title", jobTitle),
            const Divider(height: 24),
            _buildInfoRow(Icons.business, "Organization", organization),
            const Divider(height: 24),
            _buildInfoRow(Icons.calendar_today, "Applied On", appliedDate),
            if (matchScore != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                Icons.auto_awesome,
                "AI Match Score",
                "$matchScore%",
                color: _getScoreColor(matchScore),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildApplicationDetailsCard(
      Map<String, dynamic> app,
      String? submittedDocumentUrl,
      String? submittedDocumentName,
      String? submittedAt,
    ) {
      final applicantName = app['applicant_name'] ?? 'N/A';
      final applicantEmail = app['applicant_email'] ?? 'N/A';
      final coverLetter = app['cover_letter'] ?? 'No cover letter provided';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Application Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.person, "Applicant Name", applicantName),
            const Divider(height: 24),
            _buildInfoRow(Icons.email, "Email", applicantEmail),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.description,
              "Cover Letter",
              coverLetter,
              isLongText: true,
            ),
            if (submittedDocumentUrl != null &&
                submittedDocumentUrl.isNotEmpty) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.upload_file,
                            color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "Submitted Document",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.teal,
                          ),
                        ),
                        const Spacer(),
                        Material(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.teal,
                          child: InkWell(
                            onTap: _viewApplicationDocument,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.visibility,
                                      size: 18, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    "View Document",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (submittedDocumentName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "File: $submittedDocumentName",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    if (submittedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Submitted: ${_formatDate(submittedAt)}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildPaymentInformationCard(
      String transactionId,
      String transactionDate,
      String? paymentReceiptUrl,
      int? paymentAmount,
      String? paymentCategory,
    ) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.shade200),
        ),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.receipt, "Transaction ID", transactionId),
            const Divider(height: 24),
            _buildInfoRow(
                Icons.calendar_today, "Transaction Date", transactionDate),
            if (paymentAmount != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                Icons.currency_rupee,
                "Amount Paid",
                "₹$paymentAmount",
                color: Colors.green,
              ),
            ],
            if (paymentCategory != null && paymentCategory.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow(
                Icons.category,
                "Category",
                paymentCategory.toUpperCase(),
                color: Colors.blue,
              ),
            ],
            if (paymentReceiptUrl != null && paymentReceiptUrl.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.receipt, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "Payment Receipt",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.orange,
                    child: InkWell(
                      onTap: () => _showPaymentReceiptDialog(paymentReceiptUrl),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.visibility,
                                size: 18, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              "View Receipt",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Click 'View Receipt' to see your payment screenshot",
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildInfoRow(
      IconData icon,
      String label,
      String value, {
      Color? color,
      bool isLongText = false,
    }) {
      if (value.isEmpty || value == 'Not provided') return const SizedBox();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color ?? Colors.blueGrey),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: TextStyle(color: color, height: isLongText ? 1.5 : 1.2),
              ),
            ),
          ],
        ),
      );
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

    @override
    Widget build(BuildContext context) {
      final app = widget.application;
      final status = app['status'] ?? 'pending';
      final statusColor = _getStatusColor(status);
      final transactionId = app['transaction_id'] ?? 'Not provided';
      final transactionDate = app['transaction_date'] != null
          ? _formatDate(app['transaction_date'])
          : 'Not provided';
      final paymentReceiptUrl = app['payment_receipt_url'];
      final paymentAmount = app['payment_amount'];
      final paymentCategory = app['payment_category_used'];

      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(status, statusColor),
                    const SizedBox(height: 16),

                    if (status.toLowerCase() == 'review_application')
                      _buildUnderReviewSection(),
                    if (status.toLowerCase() == 'review_application')
                      const SizedBox(height: 16),

                    if (status.toLowerCase() == 'final_submit')
                      _buildFinalSubmitSection(),
                    if (status.toLowerCase() == 'final_submit')
                      const SizedBox(height: 16),

                    _buildJobInfoCard(app, _jobDetails),
                    const SizedBox(height: 16),

                    _buildApplicationDetailsCard(
                      app,
                      app['submitted_document_url'],
                      app['submitted_document_name'],
                      app['submitted_at'],
                    ),
                    const SizedBox(height: 16),

                    _buildPaymentInformationCard(
                      transactionId,
                      transactionDate,
                      paymentReceiptUrl,
                      paymentAmount,
                      paymentCategory,
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onViewJob(_jobDetails!),
                        icon: const Icon(Icons.visibility),
                        label: const Text("View Full Job Details"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
  }

// ==================== UPDATE APPLICATION DIALOG ====================
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
                    "Update Application Details",
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