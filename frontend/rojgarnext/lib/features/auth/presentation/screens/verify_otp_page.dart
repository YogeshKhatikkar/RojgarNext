// lib/features/auth/presentation/screens/verify_otp_page.dart
// COMPLETELY REDESIGNED - NO WHITE LINE EVER - CUSTOM OTP FIELDS

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/auth/presentation/controllers/auth_controller.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  final String mobile;

  const VerifyOtpPage({super.key, required this.email, required this.mobile});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final List<TextEditingController> _emailOtpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _mobileOtpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _emailFocusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _mobileFocusNodes =
      List.generate(6, (_) => FocusNode());

  int _timerSeconds = 60;
  Timer? _countdownTimer;
  bool _canResend = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _timerSeconds = 60;
    _canResend = false;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String _getEmailOtp() {
    return _emailOtpControllers.map((c) => c.text).join();
  }

  String _getMobileOtp() {
    return _mobileOtpControllers.map((c) => c.text).join();
  }

  void _clearOtps() {
    for (var controller in _emailOtpControllers) {
      controller.clear();
    }
    for (var controller in _mobileOtpControllers) {
      controller.clear();
    }
  }

  Future<void> _resendOtp() async {
    if (!mounted) return;
    final authController = Provider.of<AuthController>(context, listen: false);
    try {
      await authController.resendEmailOtp(widget.email);
      await authController.resendMobileOtp(widget.mobile);
      if (mounted) {
        _startResendTimer();
        _clearOtps();
        showMessage(context, "OTP Resent Successfully! 📩", isError: false);
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.toString().replaceAll("Exception:", "").trim(),
          isError: true,
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!mounted) return;
    final String emailOtp = _getEmailOtp();
    final String mobileOtp = _getMobileOtp();

    if (emailOtp.isEmpty || mobileOtp.isEmpty) {
      showMessage(context, "Please enter both OTPs", isError: true);
      return;
    }
    if (emailOtp.length != 6 || mobileOtp.length != 6) {
      showMessage(context, "Please enter valid 6-digit OTPs", isError: true);
      return;
    }

    setState(() => _isVerifying = true);
    final AuthController auth =
        Provider.of<AuthController>(context, listen: false);

    try {
      await auth.verifyEmailOtp(widget.email, emailOtp);
      await auth.verifyMobileOtp(widget.mobile, mobileOtp);
      if (!mounted) return;
      showMessage(
        context,
        "Account Verified Successfully! 🎉 Please login to continue.",
        isError: false,
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go(AppRoutes.auth);
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll("Exception:", "").trim();
        if (errorMessage.toLowerCase().contains("expired")) {
          errorMessage = "OTP has expired. Please request a new one.";
        } else if (errorMessage.toLowerCase().contains("invalid")) {
          errorMessage = "Invalid OTP. Please check and try again.";
        } else if (errorMessage.toLowerCase().contains("attempt")) {
          errorMessage = "Too many failed attempts. Please request a new OTP.";
        }
        showMessage(context, errorMessage, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var controller in _emailOtpControllers) {
      controller.dispose();
    }
    for (var controller in _mobileOtpControllers) {
      controller.dispose();
    }
    for (var node in _emailFocusNodes) {
      node.dispose();
    }
    for (var node in _mobileFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final isLoading = auth.isLoading || _isVerifying;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildAnimatedHeader(),
                  const SizedBox(height: 24),
                  _buildContactCard(),
                  const SizedBox(height: 32),
                  _buildOtpSection(
                    title: "📧 Email Verification Code",
                    controllers: _emailOtpControllers,
                    focusNodes: _emailFocusNodes,
                    isLoading: isLoading,
                    hint: "Enter 6-digit code sent to your email",
                  ),
                  const SizedBox(height: 28),
                  _buildOtpSection(
                    title: "📱 Mobile Verification Code",
                    controllers: _mobileOtpControllers,
                    focusNodes: _mobileFocusNodes,
                    isLoading: isLoading,
                    hint: "Enter 6-digit code sent to your mobile",
                  ),
                  const SizedBox(height: 32),
                  _buildVerifyButton(isLoading),
                  const SizedBox(height: 20),
                  _buildResendSection(),
                  const SizedBox(height: 24),
                  _buildHelpText(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withAlpha(26), Colors.white.withAlpha(13)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withAlpha(51)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.purpleAccent]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.blueAccent.withAlpha(77), blurRadius: 20),
                ],
              ),
              child: const Icon(Icons.mark_email_read,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Verify Your Account",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Enter the verification codes sent to your email and mobile",
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
                      fontSize: 14,
                      height: 1.4,
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

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildContactItem(
              icon: Icons.email_outlined,
              label: "Email",
              value: widget.email,
              color: Colors.blueAccent,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withAlpha(26),
          ),
          Expanded(
            child: _buildContactItem(
              icon: Icons.phone_android_outlined,
              label: "Mobile",
              value: "+91${widget.mobile}",
              color: Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildOtpSection({
    required String title,
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required bool isLoading,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.purpleAccent]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // CUSTOM OTP FIELD - NO WHITE LINE EVER
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withAlpha(13),
                Colors.white.withAlpha(26),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(51)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return _buildOtpBox(
                controller: controllers[index],
                focusNode: focusNodes[index],
                onChanged: (value) {
                  if (value.length == 1 && index < 5) {
                    FocusScope.of(context).requestFocus(focusNodes[index + 1]);
                  } else if (value.isEmpty && index > 0) {
                    FocusScope.of(context).requestFocus(focusNodes[index - 1]);
                  }
                },
                isLoading: isLoading,
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildOtpBox({
    required TextEditingController controller,
    required FocusNode focusNode,
    required Function(String) onChanged,
    required bool isLoading,
  }) {
    return SizedBox(
      width: 50,
      height: 55,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: !isLoading,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white.withAlpha(20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withAlpha(51),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.blueAccent,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildVerifyButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withAlpha(77),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, size: 22),
                      SizedBox(width: 10),
                      Text(
                        "Verify & Complete Registration",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Center(
      child: _canResend
          ? GestureDetector(
              onTap: _resendOtp,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withAlpha(51)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Resend OTP",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Resend in ${_timerSeconds}s",
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withAlpha(51)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Development Mode: Use OTP 123456 for testing",
              style: TextStyle(color: Colors.amber.shade200, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
