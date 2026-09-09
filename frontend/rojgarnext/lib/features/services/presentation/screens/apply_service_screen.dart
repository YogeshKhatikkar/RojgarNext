// lib/features/services/presentation/screens/apply_service_screen.dart
// ✅ COMPLETE FIXED VERSION - Opens Payment Screen as Popup Dialog

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/services/data/service_repository.dart';
import 'package:rojgarnext/features/services/models/service_types.dart';
import 'package:rojgarnext/features/payment/presentation/screens/payment_screen.dart';
import 'package:rojgarnext/features/payment/presentation/payment.dart' show PaymentType;

class ApplyServiceScreen extends StatefulWidget {
  const ApplyServiceScreen({super.key});

  @override
  State<ApplyServiceScreen> createState() => _ApplyServiceScreenState();
}

class _ApplyServiceScreenState extends State<ApplyServiceScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;

  String _userEmail = '';
  String _userName = '';
  String _userMobile = '';
  bool _userDetailsLoaded = false;

  ServiceType? _selectedService;
  ServiceSubType? _selectedSubType;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _filePaths = {};
  final Map<String, Uint8List> _fileBytes = {};
  final Map<String, bool> _documentsUploaded = {};
  final Map<String, String> _documentUrls = {};

  String? _paymentId;
  int _serviceFee = 100;
  bool _paymentCompleted = false;
  String? _razorpayOrderId;

  final List<ServiceType> _allServices = ServiceRepository.getAllServices();

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _initializeForm();
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
        return;
      }

      final response = await DioClient.dio.get('/auth/me');
      if (mounted && response.data is Map) {
        final data = response.data;
        final userData = data['data'] as Map? ?? data;

        _userEmail = userData['email']?.toString() ?? '';
        _userName = userData['name']?.toString() ?? _userEmail.split('@').first;
        _userMobile = userData['mobile']?.toString() ?? '';
        _userDetailsLoaded = true;

        if (_userEmail.isNotEmpty) await SecureStorage.setEmail(_userEmail);
        if (_userName.isNotEmpty) await SecureStorage.setName(_userName);
        if (_userMobile.isNotEmpty) await SecureStorage.setMobile(_userMobile);

        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("❌ Error loading user details: $e");
    }
  }

  void _initializeForm() {
    if (_selectedSubType != null) {
      for (var field in _selectedSubType!.requiredFields) {
        if (field.key == 'full_name' || field.key == 'name' ||
            field.key == 'email' || field.key == 'mobile' ||
            field.key == 'phone') {
          continue;
        }
        _controllers[field.key] = TextEditingController();
      }
      for (var doc in _selectedSubType!.requiredDocuments) {
        _documentsUploaded[doc] = false;
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ==================== SELECTION METHODS ====================

  void _selectService(ServiceType service) {
    setState(() {
      _selectedService = service;
      _selectedSubType = null;
      _controllers.clear();
      _filePaths.clear();
      _fileBytes.clear();
      _documentsUploaded.clear();
      _documentUrls.clear();
      _paymentCompleted = false;
      _paymentId = null;
      _razorpayOrderId = null;
    });
  }

  void _selectSubType(ServiceSubType subType) {
    setState(() {
      _selectedSubType = subType;
      _controllers.clear();
      _filePaths.clear();
      _fileBytes.clear();
      _documentsUploaded.clear();
      _documentUrls.clear();
      _paymentCompleted = false;
      _paymentId = null;
      _razorpayOrderId = null;
    });
    _initializeForm();
  }

  // ==================== DOCUMENT HANDLING ====================

  Future<void> _pickDocument(String docName) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && mounted) {
        final file = result.files.first;
        setState(() {
          _filePaths[docName] = file.name;
          _fileBytes[docName] = file.bytes!;
          _documentsUploaded[docName] = true;
          _documentUrls[docName] = '';
        });

        await _uploadDocumentToCloudinary(docName, file.bytes!, file.name);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Error picking file: $e", isError: true);
      }
    }
  }

  Future<void> _uploadDocumentToCloudinary(String docName, Uint8List fileBytes, String fileName) async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        throw Exception("No authentication token found");
      }

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'document_type': docName,
      });

      final response = await DioClient.dio.post(
        '/user/upload-document',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
        ),
      );

      if (mounted && response.data['success'] == true) {
        final url = response.data['url'] as String? ?? '';
        setState(() {
          _documentUrls[docName] = url;
        });
        showMessage(context, "✅ Document uploaded successfully!", isError: false);
      } else {
        throw Exception("Upload failed: ${response.data['message']}");
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to upload document: $e", isError: true);
      }
    }
  }

  void _removeDocument(String docName) {
    setState(() {
      _filePaths.remove(docName);
      _fileBytes.remove(docName);
      _documentsUploaded[docName] = false;
      _documentUrls.remove(docName);
    });
  }

  void _showDocumentPicker(String docName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Upload Document",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              docName,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickDocument(docName);
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Select File"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FORM VALIDATION ====================

  String? _getFieldValue(String key) {
    final controller = _controllers[key];
    return controller?.text.trim();
  }

  bool _isFormValid() {
    if (_selectedSubType == null) return false;

    for (var field in _selectedSubType!.requiredFields) {
      if (field.key == 'full_name' || field.key == 'name' ||
          field.key == 'email' || field.key == 'mobile' ||
          field.key == 'phone') {
        continue;
      }
      if (field.required) {
        final value = _getFieldValue(field.key);
        if (value == null || value.isEmpty) return false;
      }
    }

    for (var doc in _selectedSubType!.requiredDocuments) {
      if (!(_documentsUploaded[doc] ?? false)) return false;
    }

    return true;
  }

  // ==================== SUBMIT APPLICATION ====================

  Future<void> _submitApplicationWithPayment() async {
    if (!_isFormValid()) {
      showMessage(context, "Please fill all required fields and upload documents", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> formData = {
        'user_email': _userEmail,
        'user_name': _userName,
        'user_mobile': _userMobile,
        'service_type': _selectedService!.id,
        'service_sub_type': _selectedSubType!.id,
        'service_name': _selectedService!.name,
        'sub_service_name': _selectedSubType!.name,
        'application_type': 'online_service',
        'fields': {},
        'documents': _documentUrls,
      };

      for (var field in _selectedSubType!.requiredFields) {
        if (field.key == 'full_name' || field.key == 'name' ||
            field.key == 'email' || field.key == 'mobile' ||
            field.key == 'phone') {
          continue;
        }
        formData['fields'][field.key] = _getFieldValue(field.key) ?? '';
      }

      debugPrint("📤 Submitting service application...");
      debugPrint("   Service: ${_selectedService!.name} - ${_selectedSubType!.name}");
      debugPrint("   Amount: ₹$_serviceFee");
      debugPrint("   User: $_userEmail");

      // ✅ Create Razorpay order via backend
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
        final paymentId = response.data['payment_id'] ?? response.data['application_id'];
        final orderId = response.data['order_id'];
        final amount = response.data['amount'] ?? _serviceFee;

        _paymentId = paymentId;
        _razorpayOrderId = orderId;

        debugPrint("✅ Order created successfully!");
        debugPrint("   Order ID: $orderId");
        debugPrint("   Payment ID: $paymentId");
        debugPrint("   Amount: ₹$amount");

        // ✅ OPEN PAYMENT SCREEN AS POPUP DIALOG
        final paymentResult = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PaymentScreen(
            // ✅ SERVICE PAYMENT FIELDS
            serviceId: _selectedService!.id,
            serviceType: _selectedService!.name,
            serviceSubType: _selectedSubType!.id,
            subServiceName: _selectedSubType!.name,
            formData: formData,
            userEmail: _userEmail,
            userName: _userName,
            userMobile: _userMobile,
            
            // ✅ COMMON FIELDS
            amount: amount is int ? amount : _serviceFee,
            categoryUsed: "service",
            paymentId: paymentId,
            expiresAt: DateTime.now().add(const Duration(minutes: 15)),
            onPaymentSuccess: () {
              debugPrint("✅ Service Payment success callback triggered!");
              _paymentCompleted = true;
            },
            paymentType: PaymentType.service,
          ),
        );

        if (paymentResult == true && mounted) {
          showMessage(context, "✅ Service application submitted! Payment verified.");
          
          // Reset form
          setState(() {
            _selectedService = null;
            _selectedSubType = null;
            _controllers.clear();
            _filePaths.clear();
            _fileBytes.clear();
            _documentsUploaded.clear();
            _documentUrls.clear();
            _paymentCompleted = false;
            _paymentId = null;
            _razorpayOrderId = null;
          });
        }
      } else {
        showMessage(
          context,
          response.data['message'] ?? "Payment initialization failed",
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to submit: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_userDetailsLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Apply for Service"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedService != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedService = null;
                  _selectedSubType = null;
                  _controllers.clear();
                  _filePaths.clear();
                  _fileBytes.clear();
                  _documentsUploaded.clear();
                  _documentUrls.clear();
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserDetailsCard(),
            const SizedBox(height: 16),
            if (_selectedService == null) _buildServiceSelection(),
            if (_selectedService != null && _selectedSubType == null) _buildSubTypeSelection(),
            if (_selectedSubType != null) _buildForm(),
          ],
        ),
      ),
    );
  }

  // ==================== USER DETAILS CARD ====================

  Widget _buildUserDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                "Your Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Auto-Fetched",
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReadOnlyRow(Icons.person, "Full Name", _userName),
          const SizedBox(height: 8),
          _buildReadOnlyRow(Icons.email, "Email", _userEmail),
          const SizedBox(height: 8),
          _buildReadOnlyRow(Icons.phone, "Mobile", _userMobile.isNotEmpty ? "+91$_userMobile" : "Not available"),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade200.withAlpha(51),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: Colors.blue),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "These details are from your login account and cannot be changed here",
                    style: TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? "Not available" : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==================== SERVICE SELECTION ====================

  Widget _buildServiceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select a Service",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          "Choose the service you want to apply for",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _allServices.length,
          itemBuilder: (context, index) {
            final service = _allServices[index];
            return _buildSmallServiceCard(service);
          },
        ),
      ],
    );
  }

  Widget _buildSmallServiceCard(ServiceType service) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _selectService(service),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: _getServiceGradient(service.id),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getServiceColor(service.id).withAlpha(38),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    service.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                service.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _getServiceColor(service.id).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  service.subTypes.length > 1 ? "${service.subTypes.length}" : "1",
                  style: TextStyle(
                    fontSize: 9,
                    color: _getServiceColor(service.id),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SUB-TYPE SELECTION ====================

  Widget _buildSubTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selectedService = null),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "${_selectedService!.icon} ${_selectedService!.name}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _selectedService!.description,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        ..._selectedService!.subTypes.map(
          (subType) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getServiceColor(_selectedService!.id).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedService!.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              title: Text(
                subType.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                subType.description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectSubType(subType),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== APPLICATION FORM ====================

  Widget _buildForm() {
    final fields = _selectedSubType!.requiredFields.where((field) {
      return field.key != 'full_name' && field.key != 'name' &&
          field.key != 'email' && field.key != 'mobile' &&
          field.key != 'phone';
    }).toList();

    final documents = _selectedSubType!.requiredDocuments;
    final isComplete = _isFormValid();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selectedSubType = null),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_selectedService!.icon} ${_selectedSubType!.name}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _selectedSubType!.description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 32),

        const Text(
          "Additional Information",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          "Your Name, Email, and Mobile are auto-filled from your account",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ...fields.map((field) => _buildFormField(field)),
        const SizedBox(height: 24),

        const Text(
          "Required Documents",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "Upload the following documents",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ...documents.map((doc) => _buildDocumentUpload(doc)),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.currency_rupee, color: Colors.orange),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Service Fee",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    "₹$_serviceFee",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: (isComplete && !_isSubmitting) ? _submitApplicationWithPayment : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isComplete ? Colors.green : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    "Pay with Razorpay",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        if (!isComplete)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Please fill all required fields and upload all required documents",
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 30),
      ],
    );
  }

  // ==================== FORM FIELDS ====================

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: field.type == FieldType.password,
        keyboardType: _getKeyboardType(field.type),
        decoration: InputDecoration(
          labelText: field.required ? "${field.label} *" : field.label,
          hintText: field.hintText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: (value) {
          if (field.required && (value == null || value.isEmpty)) {
            return "This field is required";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField(RequiredField field, TextEditingController controller) {
    final options = _getDropdownOptions(field.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null,
        hint: Text(field.label),
        decoration: InputDecoration(
          labelText: field.required ? "${field.label} *" : field.label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            controller.text = value ?? '';
          });
        },
        validator: (value) {
          if (field.required && (value == null || value.isEmpty)) {
            return "Please select an option";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField(RequiredField field, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: field.required ? "${field.label} *" : field.label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
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
          }
        },
        validator: (value) {
          if (field.required && (value == null || value.isEmpty)) {
            return "Please select a date";
          }
          return null;
        },
      ),
    );
  }

  List<String> _getDropdownOptions(String key) {
    switch (key) {
      case 'gender':
        return ['Male', 'Female', 'Other', 'Prefer not to say'];
      case 'caste':
        return ['General/UR', 'OBC', 'SC', 'ST', 'EWS'];
      case 'disability_type':
        return ['Physical', 'Visual', 'Hearing', 'Speech', 'Mental', 'Learning'];
      default:
        return [];
    }
  }

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

  // ==================== DOCUMENT UPLOAD ====================

  Widget _buildDocumentUpload(String docName) {
    final isUploaded = _documentsUploaded[docName] ?? false;
    final fileName = _filePaths[docName];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUploaded ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded ? Colors.green : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUploaded ? Colors.green.shade200 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded ? Colors.green : Colors.grey,
              size: 20,
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
                    fontWeight: isUploaded ? FontWeight.bold : FontWeight.normal,
                    color: isUploaded ? Colors.green : Colors.grey.shade700,
                  ),
                ),
                if (fileName != null)
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (isUploaded)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
              onPressed: () => _removeDocument(docName),
            )
          else
            ElevatedButton(
              onPressed: () => _showDocumentPicker(docName),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Upload"),
            ),
        ],
      ),
    );
  }

  // ==================== UTILITY METHODS ====================

  Color _getServiceColor(String serviceId) {
    switch (serviceId) {
      case 'pan': return Colors.orange;
      case 'aadhar': return Colors.blue;
      case 'epf': return Colors.green;
      case 'passport': return Colors.deepPurple;
      case 'driving_license': return Colors.cyan;
      case 'voter_id': return Colors.red;
      case 'ration_card': return Colors.indigo;
      case 'income_certificate': return Colors.teal;
      case 'caste_certificate': return Colors.deepOrange;
      case 'domicile': return Colors.brown;
      case 'disability': return Colors.pink;
      case 'bonafide': return Colors.purple;
      case 'gap_certificate': return Colors.amber;
      default: return Colors.blueGrey;
    }
  }

  Gradient _getServiceGradient(String serviceId) {
    final color = _getServiceColor(serviceId);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color.withAlpha(204), color.withAlpha(77)],
    );
  }
}

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