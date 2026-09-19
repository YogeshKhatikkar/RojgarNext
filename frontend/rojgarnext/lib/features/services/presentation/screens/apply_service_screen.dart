// lib/features/services/presentation/screens/apply_service_screen.dart
// ✅ AI-BASED MODERN DESIGN — Matches Basic Details / Experience / Education screens
// ✅ FULLY UPDATED: Uploaded documents now carry full metadata (url, public_id,
//    resource_type, name, size) so that UserServiceApplicationsScreen can render
//    them properly. Deleted documents are STRICTLY excluded via _isValidDocUrl().

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/services/data/service_repository.dart';
import 'package:rojgarnext/features/services/models/service_types.dart';
import 'package:rojgarnext/features/payment/presentation/screens/payment_screen.dart';
import 'package:rojgarnext/features/payment/presentation/payment.dart'
    show PaymentType;

class ApplyServiceScreen extends StatefulWidget {
  const ApplyServiceScreen({super.key});

  @override
  State<ApplyServiceScreen> createState() => _ApplyServiceScreenState();
}

class _ApplyServiceScreenState extends State<ApplyServiceScreen> {
  // ==================== STATE ====================
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentStep = 0; // 0 = Service, 1 = SubType, 2 = Form

  // User Details
  String _userEmail = '';
  String _userName = '';
  String _userMobile = '';
  bool _userDetailsLoaded = false;

  // Selections
  ServiceType? _selectedService;
  ServiceSubType? _selectedSubType;

  // Form Data (text fields only)
  final Map<String, TextEditingController> _controllers = {};

  // ✅ NEW: Single source of truth — full document metadata
  final Map<String, _UploadedDoc> _uploadedDocs = {};

  // ✅ NEW: Per-document upload progress
  final Map<String, bool> _isUploadingDoc = {};

  // Payment
  String? _paymentId;
  int _serviceFee = 100;
  bool _paymentCompleted = false;
  String? _razorpayOrderId;

  final List<ServiceType> _allServices = ServiceRepository.getAllServices();

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ==================== USER DETAILS ====================
  Future<void> _loadUserDetails() async {
    if (!mounted) return;

    try {
      final email = await SecureStorage.getEmail();
      final name = await SecureStorage.getName();
      final mobile = await SecureStorage.getMobile();

      if (email != null && email.isNotEmpty) {
        _userEmail = email;
        _userName = name ?? email.split('@').first;
        _userMobile = mobile ?? '';
        _userDetailsLoaded = true;
        if (mounted) setState(() {});
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await DioClient.dio.get('/auth/me');
      if (mounted && response.data is Map) {
        final data = response.data;
        final userData = data['data'] as Map? ?? data;

        _userEmail = userData['email']?.toString() ?? '';
        _userName =
            userData['name']?.toString() ?? _userEmail.split('@').first;
        _userMobile = userData['mobile']?.toString() ?? '';
        _userDetailsLoaded = true;

        if (_userEmail.isNotEmpty) await SecureStorage.setEmail(_userEmail);
        if (_userName.isNotEmpty) await SecureStorage.setName(_userName);
        if (_userMobile.isNotEmpty) await SecureStorage.setMobile(_userMobile);

        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("❌ Error loading user details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== FORM INITIALIZATION ====================
  void _initializeForm() {
    _controllers.clear();
    _uploadedDocs.clear();
    _isUploadingDoc.clear();

    if (_selectedSubType != null) {
      for (final field in _selectedSubType!.requiredFields) {
        if (_isAutoFilledField(field.key)) continue;
        _controllers[field.key] = TextEditingController();
      }
      for (final doc in _selectedSubType!.requiredDocuments) {
        _isUploadingDoc[doc] = false;
      }
    }
  }

  bool _isAutoFilledField(String key) {
    return key == 'full_name' ||
        key == 'name' ||
        key == 'email' ||
        key == 'mobile' ||
        key == 'phone';
  }

  // ==================== SELECTION METHODS ====================
  void _selectService(ServiceType service) {
    setState(() {
      _selectedService = service;
      _selectedSubType = null;
      _currentStep = 1;
      _resetSelections();
    });
  }

  void _selectSubType(ServiceSubType subType) {
    setState(() {
      _selectedSubType = subType;
      _currentStep = 2;
      _resetSelections();
    });
    _initializeForm();
  }

  void _goBack() {
    setState(() {
      if (_currentStep == 2) {
        _currentStep = 1;
        _selectedSubType = null;
        _resetSelections();
      } else if (_currentStep == 1) {
        _currentStep = 0;
        _selectedService = null;
      }
    });
  }

  void _resetSelections() {
    _controllers.clear();
    _uploadedDocs.clear();
    _isUploadingDoc.clear();
    _paymentCompleted = false;
    _paymentId = null;
    _razorpayOrderId = null;
  }

  // ==================== STRICT DOC URL VALIDATOR ====================
  /// Filters out: null, "", "null", "undefined", "n/a", "na", "-",
  /// "none", "false", "0" and any non-URL garbage.
  bool _isValidDocUrl(dynamic value) {
    if (value == null) return false;
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
        lower == '0') {
      return false;
    }

    if (!str.startsWith('http://') &&
        !str.startsWith('https://') &&
        !str.startsWith('file:') &&
        !str.startsWith('blob:')) {
      return false;
    }

    if (str.length < 12) return false;
    return true;
  }

  // ==================== DOCUMENT HANDLING ====================
  Future<void> _pickDocument(String docName) async {
    try {
      // ✅ Correct usage — FilePicker.platform works on Web + Mobile
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // critical for Web
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          showMessage(context, "File data unavailable", isError: true);
        }
        return;
      }

      // Enforce max 10 MB
      const maxBytes = 10 * 1024 * 1024;
      if (file.bytes!.length > maxBytes) {
        if (mounted) {
          showMessage(context, "File too large (max 10 MB)", isError: true);
        }
        return;
      }

      // Kick off upload
      await _uploadDocumentToCloudinary(docName, file.bytes!, file.name);
    } catch (e) {
      debugPrint("❌ _pickDocument error: $e");
      if (mounted) {
        showMessage(
          context,
          "Error picking file: ${_cleanErr(e)}",
          isError: true,
        );
      }
    }
  }

  Future<void> _uploadDocumentToCloudinary(
    String docName,
    Uint8List fileBytes,
    String fileName,
  ) async {
    // Show loading for this specific doc
    if (mounted) {
      setState(() => _isUploadingDoc[docName] = true);
    }

    try {
      final token = await SecureStorage.getToken();
      if (token == null) throw Exception("No authentication token found");

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'document_type': docName,
      });

      final response = await DioClient.dio.post(
        '/user/upload-document',
        data: formData,
        options: Options(
          headers: {
            "Content-Type": "multipart/form-data",
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (!mounted) return;

      final data = response.data;
      if (data is! Map || data['success'] != true) {
        throw Exception(data?['message'] ?? 'Upload failed');
      }

      final uploadedUrl = data['url']?.toString() ?? '';
      // ✅ STRICT validation — refuse to save invalid URL
      if (!_isValidDocUrl(uploadedUrl)) {
        throw Exception("Server returned an invalid document URL");
      }

      final doc = _UploadedDoc(
        key: docName,
        label: docName,
        url: uploadedUrl,
        publicId: data['public_id']?.toString(),
        fileName: fileName,
        fileSizeKb: (fileBytes.length / 1024).round(),
        resourceType: data['resource_type']?.toString() ?? 'raw',
        uploadedAt: DateTime.now(),
      );

      setState(() {
        _uploadedDocs[docName] = doc;
        _isUploadingDoc[docName] = false;
      });

      if (mounted) {
        showMessage(context, "✅ Document uploaded!", isError: false);
      }
    } catch (e) {
      debugPrint("❌ Upload failed for $docName: $e");
      if (mounted) {
        setState(() => _isUploadingDoc[docName] = false);
        showMessage(
          context,
          "Failed to upload document: ${_cleanErr(e)}",
          isError: true,
        );
      }
    }
  }

  void _removeDocument(String docName) {
    setState(() {
      _uploadedDocs.remove(docName);
      _isUploadingDoc[docName] = false;
    });
    showMessage(context, "Document removed");
  }

  String _cleanErr(dynamic e) {
    return e.toString().replaceAll('Exception:', '').trim();
  }

  // ==================== VALIDATION ====================
  String? _getFieldValue(String key) {
    final controller = _controllers[key];
    return controller?.text.trim();
  }

  bool _isFormValid() {
    if (_selectedSubType == null) return false;

    // All required text fields must be filled
    for (final field in _selectedSubType!.requiredFields) {
      if (_isAutoFilledField(field.key)) continue;
      if (field.required) {
        final value = _getFieldValue(field.key);
        if (value == null || value.isEmpty) return false;
      }
    }

    // All required documents must be uploaded AND have valid URL
    for (final doc in _selectedSubType!.requiredDocuments) {
      final uploaded = _uploadedDocs[doc];
      if (uploaded == null) return false;
      if (!_isValidDocUrl(uploaded.url)) return false;
    }

    return true;
  }

  // ==================== SUBMIT WITH PAYMENT ====================
  Future<void> _submitApplicationWithPayment() async {
    if (!_isFormValid()) {
      showMessage(
        context,
        "Please fill all required fields and upload documents",
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ---------- Build form fields ----------
      final Map<String, dynamic> formFields = {};
      for (final field in _selectedSubType!.requiredFields) {
        if (_isAutoFilledField(field.key)) continue;
        formFields[field.key] = _getFieldValue(field.key) ?? '';
      }

      // ---------- Build documents map (STRICT) ----------
      // Only valid, non-deleted docs are included.
      final Map<String, String> documentsMap = {};
      final Map<String, Map<String, dynamic>> documentMeta = {};

      _uploadedDocs.forEach((key, doc) {
        if (_isValidDocUrl(doc.url)) {
          documentsMap[key] = doc.url;
          documentMeta[key] = {
            'url': doc.url,
            'public_id': doc.publicId,
            'name': doc.fileName,
            'size_kb': doc.fileSizeKb,
            'resource_type': doc.resourceType,
            'uploaded_at': doc.uploadedAt.toIso8601String(),
          };
        }
      });

      final Map<String, dynamic> formData = {
        'user_email': _userEmail,
        'user_name': _userName,
        'user_mobile': _userMobile,
        'service_type': _selectedService!.id,
        'service_sub_type': _selectedSubType!.id,
        'service_name': _selectedService!.name,
        'sub_service_name': _selectedSubType!.name,
        'application_type': 'online_service',
        'fields': formFields,
        'documents': documentsMap,
        'document_meta': documentMeta, // ✅ rich metadata
      };

      // ---------- Create Razorpay order ----------
      final response = await DioClient.dio.post(
        '/payment/razorpay/create-order',
        data: {
          "amount": _serviceFee,
          "payment_type": "service",
          "service_id": _selectedService!.id,
          "service_type": _selectedService!.name,
          "sub_type_id": _selectedSubType!.id,
          "sub_service_name": _selectedSubType!.name,
          "form_data": formData,
          "user_email": _userEmail,
          "user_name": _userName,
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        final paymentId =
            response.data['payment_id'] ?? response.data['application_id'];
        final orderId = response.data['order_id'];
        final amount = response.data['amount'] ?? _serviceFee;

        _paymentId = paymentId;
        _razorpayOrderId = orderId;

        final paymentResult = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PaymentScreen(
            serviceId: _selectedService!.id,
            serviceType: _selectedService!.name,
            serviceSubType: _selectedSubType!.id,
            subServiceName: _selectedSubType!.name,
            formData: formData,
            userEmail: _userEmail,
            userName: _userName,
            userMobile: _userMobile,
            amount: amount is int ? amount : _serviceFee,
            categoryUsed: "service",
            paymentId: paymentId,
            expiresAt: DateTime.now().add(const Duration(minutes: 15)),
            onPaymentSuccess: () {
              _paymentCompleted = true;
            },
            paymentType: PaymentType.service,
          ),
        );

        if (paymentResult == true && mounted) {
          await _showAISuccessDialog();
          _resetForm();
        }
      } else {
        showMessage(
          context,
          response.data['message'] ?? "Payment initialization failed",
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("❌ Submit failed: $e");
      if (mounted) {
        showMessage(
          context,
          "Failed to submit: ${_cleanErr(e)}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedService = null;
      _selectedSubType = null;
      _currentStep = 0;
      _resetSelections();
    });
  }

  // ==================== AI SUCCESS DIALOG ====================
  Future<void> _showAISuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                "Application Submitted! 🎉",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your service application has been submitted successfully. Payment verified.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      "AI Verified",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_userDetailsLoaded) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(),
                ),
              ),
              if (_currentStep == 2) _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildServiceSelection();
      case 1:
        return _buildSubTypeSelection();
      case 2:
        return _buildForm();
      default:
        return _buildServiceSelection();
    }
  }

  // ==================== AI LOADING SCREEN ====================
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder(
                duration: const Duration(seconds: 2),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
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
                            color:
                                const Color(0xFF6C63FF).withOpacity(0.3),
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
                  );
                },
              ),
              const SizedBox(height: 30),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ).createShader(bounds),
                child: const Text(
                  "AI is loading services...",
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

  // ==================== DESIGN HELPERS ====================
  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, IconData icon, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 30,
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Apply for Service",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getHeaderSubtitle(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderSubtitle() {
    switch (_currentStep) {
      case 0:
        return "Choose a service to apply for";
      case 1:
        return _selectedService?.name ?? "Select sub-service";
      case 2:
        return _selectedSubType?.name ?? "Fill application form";
      default:
        return "Choose a service to apply";
    }
  }

  // ==================== STEP INDICATOR ====================
  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepItem(0, "Service", Icons.category),
          _buildStepItem(1, "Sub-Type", Icons.list_alt),
          _buildStepItem(2, "Form", Icons.edit_note),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String label, IconData icon) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: GestureDetector(
        onTap: step < _currentStep ? _goBack : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isCurrent
                ? const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  )
                : null,
            color: isCurrent ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isCurrent
                    ? Colors.white
                    : (isActive ? const Color(0xFF6C63FF) : Colors.grey),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? Colors.white
                      : (isActive ? const Color(0xFF6C63FF) : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== STEP 1: SERVICE SELECTION ====================
  Widget _buildServiceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserDetailsCard(),
        const SizedBox(height: 16),
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                "Select Service",
                Icons.apps,
                subtitle:
                    "Choose from ${_allServices.length} available services",
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _allServices.length,
                itemBuilder: (context, index) =>
                    _buildServiceCard(_allServices[index]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(ServiceType service) {
    final color = _getServiceColor(service.id);
    return GestureDetector(
      onTap: () => _selectService(service),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  service.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                service.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${service.subTypes.length} types",
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== USER DETAILS CARD ====================
  Widget _buildUserDetailsCard() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                "Your Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 10, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      "Auto-Fetched",
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReadOnlyRow(Icons.person_outline, "Name", _userName),
          const SizedBox(height: 8),
          _buildReadOnlyRow(Icons.email_outlined, "Email", _userEmail),
          const SizedBox(height: 8),
          _buildReadOnlyRow(
            Icons.phone_outlined,
            "Mobile",
            _userMobile.isNotEmpty ? "+91$_userMobile" : "Not available",
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? "Not available" : value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==================== STEP 2: SUB-TYPE SELECTION ====================
  Widget _buildSubTypeSelection() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "${_selectedService!.icon}  ${_selectedService!.name}",
            Icons.list_alt,
            subtitle: _selectedService!.description,
          ),
          const SizedBox(height: 12),
          ..._selectedService!.subTypes.map(
            (subType) => _buildSubTypeCard(subType),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTypeCard(ServiceSubType subType) {
    final color = _getServiceColor(_selectedService!.id);
    return GestureDetector(
      onTap: () => _selectSubType(subType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _selectedService!.icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subType.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subType.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${subType.requiredFields.length} fields",
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${subType.requiredDocuments.length} docs",
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 3: FORM ====================
  Widget _buildForm() {
    final fields = _selectedSubType!.requiredFields
        .where((field) => !_isAutoFilledField(field.key))
        .toList();

    final documents = _selectedSubType!.requiredDocuments;

    return Column(
      children: [
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                "Additional Information",
                Icons.info_outline,
                subtitle:
                    "Name, Email, Mobile are auto-filled from your account",
              ),
              if (fields.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      "No additional fields required for this service",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ...fields.map((field) => _buildFormField(field)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                "Required Documents",
                Icons.upload_file,
                subtitle: "Upload the following documents",
              ),
              const SizedBox(height: 8),
              ...documents.map((doc) => _buildDocumentUpload(doc)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFeeCard(),
      ],
    );
  }

  Widget _buildFormField(RequiredField field) {
    TextEditingController? controller = _controllers[field.key];
    if (controller == null) {
      controller = TextEditingController();
      _controllers[field.key] = controller;
    }

    if (field.type == FieldType.dropdown) {
      return _buildDropdownField(field, controller);
    }

    if (field.type == FieldType.date) {
      return _buildDateField(field, controller);
    }

    return _buildAITextField(
      controller,
      field.required ? "${field.label} *" : field.label,
      keyboardType: _getKeyboardType(field.type),
      prefixIcon: _getFieldIcon(field.type),
      hintText: field.hintText,
    );
  }

  // ==================== AI TEXT FIELD ====================
  Widget _buildAITextField(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hintText,
    IconData? prefixIcon,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.black87),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            hintText: hintText ?? (label.contains('*') ? null : "Optional"),
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey.shade600, size: 20)
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  // ==================== AI DROPDOWN FIELD ====================
  Widget _buildDropdownField(
      RequiredField field, TextEditingController controller) {
    final options = _getDropdownOptions(field.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          value: controller.text.isNotEmpty ? controller.text : null,
          decoration: InputDecoration(
            labelText: field.required ? "${field.label} *" : field.label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Icon(
              Icons.arrow_drop_down,
              color: Colors.grey.shade600,
            ),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: const TextStyle(color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              controller.text = value ?? '';
            });
          },
          isExpanded: true,
        ),
      ),
    );
  }

  // ==================== AI DATE FIELD ====================
  Widget _buildDateField(
      RequiredField field, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: field.required ? "${field.label} *" : field.label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(Icons.calendar_today,
                color: Colors.grey.shade600, size: 18),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Icon(Icons.event,
                color: Colors.grey.shade400, size: 18),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            );
            if (picked != null && mounted) {
              controller.text =
                  "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  // ==================== DOCUMENT UPLOAD ====================
  Widget _buildDocumentUpload(String docName) {
    final uploadedDoc = _uploadedDocs[docName];
    final isUploaded = uploadedDoc != null;
    final isUploading = _isUploadingDoc[docName] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUploaded
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.grey.shade50, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded ? Colors.green.shade300 : Colors.grey.shade300,
          width: isUploaded ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUploaded
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded
                  ? Colors.green.shade700
                  : Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  docName,
                  style: TextStyle(
                    fontWeight:
                        isUploaded ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    color: isUploaded
                        ? Colors.green.shade900
                        : Colors.black87,
                  ),
                ),
                if (uploadedDoc != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "${uploadedDoc.fileName} • ${uploadedDoc.fileSizeKb} KB",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (isUploading) ...[
                  const SizedBox(height: 2),
                  const Text(
                    "Uploading...",
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ],
              ],
            ),
          ),
          if (isUploaded)
            InkWell(
              onTap: () => _removeDocument(docName),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.red.shade700,
                  size: 16,
                ),
              ),
            )
          else if (isUploading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton(
              onPressed: () => _pickDocument(docName),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Upload",
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== FEE CARD ====================
  Widget _buildFeeCard() {
    return _buildGlassContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.currency_rupee,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Service Fee",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  "Pay securely via Razorpay",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "₹$_serviceFee",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BOTTOM BAR ====================
  Widget _buildBottomBar() {
    final isComplete = _isFormValid();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      isComplete
                          ? Icons.check_circle
                          : Icons.info_outline,
                      size: 14,
                      color: isComplete ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isComplete
                            ? "Ready to submit"
                            : "Fill all required fields",
                        style: TextStyle(
                          fontSize: 12,
                          color: isComplete ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isComplete
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [Colors.grey.shade400, Colors.grey.shade500],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isComplete
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed:
                  (isComplete && !_isSubmitting)
                      ? _submitApplicationWithPayment
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      children: [
                        Icon(Icons.payment, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "Pay & Submit",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.auto_awesome, size: 12),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== UTILITY METHODS ====================
  TextInputType _getKeyboardType(FieldType type) {
    switch (type) {
      case FieldType.number:
        return TextInputType.number;
      case FieldType.email:
        return TextInputType.emailAddress;
      case FieldType.phone:
        return TextInputType.phone;
      default:
        return TextInputType.text;
    }
  }

  IconData _getFieldIcon(FieldType type) {
    switch (type) {
      case FieldType.number:
        return Icons.numbers;
      case FieldType.email:
        return Icons.email_outlined;
      case FieldType.phone:
        return Icons.phone_outlined;
      case FieldType.password:
        return Icons.lock_outline;
      case FieldType.date:
        return Icons.calendar_today;
      default:
        return Icons.edit;
    }
  }

  List<String> _getDropdownOptions(String key) {
    switch (key) {
      case 'gender':
        return ['Male', 'Female', 'Other', 'Prefer not to say'];
      case 'caste':
        return ['General/UR', 'OBC', 'SC', 'ST', 'EWS'];
      case 'disability_type':
        return [
          'Physical',
          'Visual',
          'Hearing',
          'Speech',
          'Mental',
          'Learning'
        ];
      case 'marital_status':
        return ['Unmarried', 'Married', 'Divorced', 'Widowed'];
      default:
        return [];
    }
  }

  Color _getServiceColor(String serviceId) {
    switch (serviceId) {
      case 'pan':
        return Colors.orange;
      case 'aadhar':
        return Colors.blue;
      case 'epf':
        return Colors.green;
      case 'passport':
        return Colors.deepPurple;
      case 'driving_license':
        return Colors.cyan;
      case 'voter_id':
        return Colors.red;
      case 'ration_card':
        return Colors.indigo;
      case 'income_certificate':
        return Colors.teal;
      case 'caste_certificate':
        return Colors.deepOrange;
      case 'domicile':
        return Colors.brown;
      case 'disability':
        return Colors.pink;
      case 'bonafide':
        return Colors.purple;
      case 'gap_certificate':
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }
}

// ============================================================
// LOCAL MODEL — Document with full metadata
// ============================================================
class _UploadedDoc {
  final String key;
  final String label;
  final String url;
  final String? publicId;
  final String fileName;
  final int fileSizeKb;
  final String resourceType;
  final DateTime uploadedAt;

  _UploadedDoc({
    required this.key,
    required this.label,
    required this.url,
    this.publicId,
    required this.fileName,
    required this.fileSizeKb,
    required this.resourceType,
    required this.uploadedAt,
  });
}