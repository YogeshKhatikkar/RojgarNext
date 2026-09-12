// lib/features/payment/presentation/screens/payment_screen.dart
// ✅ COMPLETE - Works on both Web and Mobile
// ✅ NEW: Shows full fee breakdown (App Fee + GST + Service Charge = Total)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/payment/razorpay_service.dart';
import 'package:rojgarnext/features/payment/presentation/payment.dart';

class PaymentScreen extends StatefulWidget {
  // Job-specific fields
  final String? jobId;
  final String? jobTitle;
  final String? organization;

  // Service-specific fields
  final String? serviceId;
  final String? serviceType;
  final String? serviceSubType;
  final Map<String, dynamic>? formData;
  final String? subServiceName;
  final String? userEmail;
  final String? userName;
  final String? userMobile;

  // Common fields
  final int amount;
  final String categoryUsed;
  final String paymentId;
  final DateTime expiresAt;
  final VoidCallback onPaymentSuccess;
  final PaymentType paymentType;

  // ✅ NEW: Fee breakdown fields
  final int? applicationFee;
  final int? gstAmount;
  final int? serviceCharge;

  const PaymentScreen({
    super.key,
    this.jobId,
    this.jobTitle,
    this.organization,
    this.serviceId,
    this.serviceType,
    this.serviceSubType,
    this.formData,
    this.subServiceName,
    this.userEmail,
    this.userName,
    this.userMobile,
    required this.amount,
    required this.categoryUsed,
    required this.paymentId,
    required this.expiresAt,
    required this.onPaymentSuccess,
    required this.paymentType,
    // ✅ NEW
    this.applicationFee,
    this.gstAmount,
    this.serviceCharge,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late Timer _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Duration _timeLeft = Duration.zero;

  bool _isRazorpayLoading = false;
  bool _isPaymentCompleted = false;
  bool _isProcessingSuccess = false;
  bool _isDisposed = false;

  String? _razorpayOrderId;
  String? _razorpayKeyId;
  String? _razorpayPaymentId;
  String? _razorpaySignature;
  String? _applicationId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateTimeLeft();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeLeft();
      if (_timeLeft.isNegative) {
        timer.cancel();
        _pulseController.stop();
        if (mounted && !_isDisposed) {
          _handleExpiration();
        }
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _countdownTimer.cancel();
    _pulseController.dispose();
    RazorpayService.instance.dispose();
    super.dispose();
  }

  void _updateTimeLeft() {
    if (_isDisposed) return;
    final now = DateTime.now();
    final remaining = widget.expiresAt.difference(now);
    if (mounted) {
      setState(() {
        _timeLeft = remaining.isNegative ? Duration.zero : remaining;
      });
    }
  }

  String _formatTimeLeft() {
    if (_timeLeft.isNegative) return "Expired";
    final minutes = _timeLeft.inMinutes;
    final seconds = _timeLeft.inSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  void _handleExpiration() {
    if (_isDisposed || !mounted) return;
    _showMessage("⚠️ Payment session has expired. Please try again.",
        isError: true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isDisposed) {
        Navigator.pop(context, false);
      }
    });
  }

  Future<void> _createRazorpayOrder() async {
    if (!mounted || _isDisposed) return;

    setState(() {
      _isRazorpayLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint("💰 Creating Razorpay order...");
      debugPrint("   Amount: ${widget.amount}");
      debugPrint("   Platform: ${kIsWeb ? 'Web' : 'Mobile'}");
      debugPrint("   Payment Type: ${widget.paymentType}");

      final Map<String, dynamic> requestData = {
        "amount": widget.amount,
        "payment_type":
            widget.paymentType == PaymentType.job ? "job" : "service",
      };

      if (widget.paymentType == PaymentType.job) {
        if (widget.jobId == null) throw Exception("Job ID is required");
        requestData["job_id"] = widget.jobId;
        if (widget.jobTitle != null)
          requestData["job_title"] = widget.jobTitle;
        if (widget.organization != null)
          requestData["organization"] = widget.organization;
        // ✅ Send fee breakdown
        if (widget.applicationFee != null)
          requestData["application_fee"] = widget.applicationFee;
        if (widget.gstAmount != null)
          requestData["gst_amount"] = widget.gstAmount;
        if (widget.serviceCharge != null)
          requestData["service_charge"] = widget.serviceCharge;
      } else {
        if (widget.serviceId == null || widget.serviceSubType == null) {
          throw Exception("Service ID and Sub Type are required");
        }
        requestData["service_id"] = widget.serviceId;
        requestData["service_type"] = widget.serviceType;
        requestData["sub_type_id"] = widget.serviceSubType;
        requestData["sub_service_name"] = widget.subServiceName;
        if (widget.formData != null)
          requestData["form_data"] = widget.formData;
        if (widget.userEmail != null)
          requestData["user_email"] = widget.userEmail;
        if (widget.userName != null)
          requestData["user_name"] = widget.userName;
      }

      final response = await DioClient.dio.post(
        '/payment/razorpay/create-order',
        data: requestData,
      );

      if (!mounted || _isDisposed) return;

      debugPrint("📥 Order Response: ${response.data}");

      if (response.data['success'] == true) {
        _razorpayOrderId = response.data['order_id']?.toString();
        _razorpayKeyId = response.data['key_id']?.toString();
        _applicationId = response.data['payment_id']?.toString() ??
            response.data['application_id']?.toString() ??
            widget.paymentId;

        if (_razorpayOrderId == null || _razorpayOrderId!.isEmpty) {
          throw Exception("Order ID is missing from response");
        }

        if (_razorpayKeyId == null || _razorpayKeyId!.isEmpty) {
          throw Exception("Key ID is missing from response");
        }

        debugPrint("✅ Order created successfully!");
        debugPrint("   Order ID: $_razorpayOrderId");
        debugPrint("   Key ID: $_razorpayKeyId");

        if (mounted) {
          _showMessage("Opening payment gateway...");
        }

        await RazorpayService.instance.initiatePayment(
          amount: widget.amount,
          orderId: _razorpayOrderId!,
          keyId: _razorpayKeyId!,
          userEmail: widget.userEmail ?? '',
          userName: widget.userName ?? 'User',
          userMobile: widget.userMobile ?? '',
          onSuccess: (Map<String, dynamic> paymentResponse) {
            debugPrint("✅ Razorpay SUCCESS callback triggered");
            _handleRazorpaySuccess(paymentResponse);
          },
          onError: (String error) {
            debugPrint("❌ Razorpay ERROR callback triggered: $error");
            _handleRazorpayError({'message': error});
          },
          onExternalWallet: () {
            debugPrint("ℹ️ Razorpay External Wallet callback triggered");
            _showMessage(
                "External wallet selected. Please complete payment in the app.");
          },
        );
      } else {
        final errorMsg =
            response.data['message'] ?? "Failed to create payment order";
        debugPrint("❌ Order creation failed: $errorMsg");
        _showMessage(errorMsg, isError: true);
        setState(() => _isRazorpayLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error creating Razorpay order: $e");
      if (mounted && !_isDisposed) {
        _showMessage(
            "Error: ${e.toString().replaceAll('Exception:', '').trim()}",
            isError: true);
        setState(() => _isRazorpayLoading = false);
      }
    }
  }

  void _handleRazorpaySuccess(Map<String, dynamic> response) {
    debugPrint("✅ RAZORPAY SUCCESS RESPONSE: $response");

    _razorpayPaymentId = response['razorpay_payment_id']?.toString();
    _razorpayOrderId =
        response['razorpay_order_id']?.toString() ?? _razorpayOrderId;
    _razorpaySignature = response['razorpay_signature']?.toString();

    _verifyRazorpayPayment();
  }

  void _handleRazorpayError(Map<String, dynamic> response) {
    debugPrint("❌ RAZORPAY ERROR: $response");
    if (mounted && !_isDisposed) {
      setState(() => _isRazorpayLoading = false);
      final errorMsg = response['message']?.toString() ??
          response['description']?.toString() ??
          'Payment failed. Please try again.';
      _showMessage(errorMsg, isError: true);
    }
  }

  Future<void> _verifyRazorpayPayment() async {
    try {
      debugPrint("🔐 Verifying Razorpay payment with backend...");

      final Map<String, dynamic> requestData = {
        "razorpay_payment_id": _razorpayPaymentId,
        "razorpay_order_id": _razorpayOrderId,
        "razorpay_signature": _razorpaySignature,
        "application_id": _applicationId ?? widget.paymentId,
        "amount": widget.amount,
      };

      if (widget.paymentType == PaymentType.job) {
        requestData["job_id"] = widget.jobId;
      } else {
        requestData["service_id"] = widget.serviceId;
        requestData["service_type"] = widget.serviceType;
        requestData["sub_type_id"] = widget.serviceSubType;
      }

      final response = await DioClient.dio.post(
        '/payment/razorpay/verify-payment',
        data: requestData,
      );

      if (!mounted || _isDisposed) return;

      debugPrint("📥 Verification response: ${response.data}");

      if (response.data['payment_verified'] == true) {
        _isPaymentCompleted = true;
        _applicationId = response.data['application_id']?.toString() ??
            response.data['id']?.toString() ??
            _applicationId;
        await _handlePaymentSuccess();
      } else {
        final errorMsg =
            response.data['message'] ?? "Payment verification failed.";
        _showMessage(errorMsg, isError: true);
        setState(() => _isRazorpayLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Verification error: $e");
      if (mounted && !_isDisposed) {
        _showMessage(
            "Payment verification failed. Please contact support.",
            isError: true);
        setState(() => _isRazorpayLoading = false);
      }
    }
  }

  Future<void> _handlePaymentSuccess() async {
    if (_isProcessingSuccess || _isDisposed) return;
    _isProcessingSuccess = true;
    _pulseController.stop();

    if (!mounted) return;

    debugPrint("=" * 60);
    debugPrint("✅ PAYMENT SUCCESS - Processing...");
    debugPrint("   Payment ID: ${widget.paymentId}");
    debugPrint("   Amount: ₹${widget.amount}");
    debugPrint("   Platform: ${kIsWeb ? 'Web' : 'Mobile'}");
    debugPrint("=" * 60);

    try {
      widget.onPaymentSuccess();

      if (mounted && !_isDisposed) {
        _showMessage("✅ Payment Successful!");
      }

      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted && !_isDisposed) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("❌ Error in payment success handler: $e");
      if (mounted && !_isDisposed) {
        _showMessage(
            "Payment successful but status update failed. Please check your applications.",
            isError: true);
        Navigator.pop(context, true);
      }
    } finally {
      if (!_isDisposed) _isProcessingSuccess = false;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted || _isDisposed) return;
    showMessage(context, message, isError: isError);
  }

  Future<void> _showCancelConfirmation() async {
    if (_isDisposed || !mounted) return;

    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cancel Payment"),
        content: const Text(
            "Are you sure you want to cancel? Your application will not be submitted."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Stay"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
    if (shouldClose == true && mounted && !_isDisposed) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _timeLeft.isNegative;
    final timeColor =
        _timeLeft.inMinutes < 2 && !isExpired ? Colors.red : Colors.blue;

    String displayTitle = widget.paymentType == PaymentType.job
        ? widget.jobTitle ?? "Job Application"
        : widget.subServiceName ?? widget.serviceType ?? "Service";

    String displaySubtitle = widget.paymentType == PaymentType.job
        ? widget.organization ?? ""
        : "Service Fee";

    final bool canPay =
        !_isPaymentCompleted && !isExpired && !_isRazorpayLoading;

    // ✅ Get fee breakdown from widget or fallback
    final appFee = widget.applicationFee ?? 0;
    final gst = widget.gstAmount ?? 0;
    final serviceCharge = widget.serviceCharge ?? 0;
    final hasBreakdown = appFee > 0 || gst > 0 || serviceCharge > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop && !_isDisposed) {
          await _showCancelConfirmation();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.92,
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.security,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Secure Payment",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(displayTitle,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis),
                          if (displaySubtitle.isNotEmpty)
                            Text(displaySubtitle,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showCancelConfirmation,
                      icon: const Icon(Icons.close, size: 24),
                      tooltip: "Cancel Payment",
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ✅ NEW: Fee Breakdown Section
                if (hasBreakdown) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long,
                                size: 18, color: Color(0xFF6C63FF)),
                            SizedBox(width: 8),
                            Text(
                              "Fee Breakdown",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Application Fee
                        if (appFee > 0)
                          _buildBreakdownRow(
                            "Application Fees",
                            appFee,
                            Colors.teal,
                          ),
                        if (appFee > 0) const SizedBox(height: 8),
                        // GST
                        if (gst > 0)
                          _buildBreakdownRow(
                            "GST (18%)",
                            gst,
                            Colors.orange,
                          ),
                        if (gst > 0) const SizedBox(height: 8),
                        // Service Charge
                        if (serviceCharge > 0)
                          _buildBreakdownRow(
                            "Service Charge",
                            serviceCharge,
                            Colors.purple,
                          ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        // Total
                        Row(
                          children: [
                            const Icon(Icons.payments,
                                size: 18, color: Color(0xFF1E3A8A)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Total Payable",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                            Text(
                              "₹${widget.amount}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Amount Display
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text("Amount to Pay",
                          style: TextStyle(
                              fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        "₹${widget.amount}",
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.paymentType == PaymentType.job
                              ? widget.categoryUsed.toUpperCase()
                              : "Service Fee",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Timer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: timeColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: timeColor.withAlpha(76)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer, size: 20, color: timeColor),
                      const SizedBox(width: 8),
                      Text(
                        "Expires in: ${_formatTimeLeft()}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: timeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 12),

                // Payment Completed
                if (_isPaymentCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Payment Completed Successfully!",
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Pay Button
                if (!_isPaymentCompleted && !isExpired)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: canPay ? _createRazorpayOrder : null,
                      icon: _isRazorpayLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payment, size: 24),
                      label: Text(
                        _isRazorpayLoading
                            ? "Processing..."
                            : kIsWeb
                                ? "Pay ₹${widget.amount} (Web)"
                                : "Pay ₹${widget.amount}",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Platform Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        kIsWeb ? Icons.web : Icons.phone_android,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isExpired
                              ? "Payment session expired. Please go back and try again."
                              : (kIsWeb
                                  ? "🌐 Web: Razorpay checkout will open in a popup"
                                  : "📱 Mobile: Secure Razorpay payment"),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel Button
                TextButton(
                  onPressed: _showCancelConfirmation,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Cancel Payment"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Fee breakdown row helper
  Widget _buildBreakdownRow(String label, int amount, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
        Text(
          "₹$amount",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}