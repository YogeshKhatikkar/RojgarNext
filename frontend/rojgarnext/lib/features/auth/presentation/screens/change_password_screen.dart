// lib/features/auth/presentation/screens/change_password_screen.dart
// ✅ AI‑BASED MODERN DESIGN (gradient, glass containers, loading animation)
// ✅ FIXED: Email OTP + Mobile OTP are both sent on initial load
// ✅ FIXED: Manual mobile entry triggers mobile OTP sending
// ✅ FULLY UPDATED – no logic skipped

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/features/auth/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isForgotFlow;
  final bool isEmbedded;

  const ChangePasswordScreen({
    super.key,
    this.isForgotFlow = false,
    this.isEmbedded = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _disposed = false;

  String _emailOtp = '';
  String _mobileOtp = '';

  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  final _manualMobileCtrl = TextEditingController();

  bool _otpVerified = false;
  bool _isLoading = false;
  bool _isResending = false;
  bool _isVerifying = false;
  bool _isUpdating = false;
  bool _showNew = false;
  bool _showConfirm = false;

  int _timerSecs = 60;
  Timer? _timer;
  bool _canResend = false;

  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  bool _isLong = false;

  String? _email;
  String? _mobile;
  bool _mobileMissing = false;

  final _emailPinKey = GlobalKey(debugLabel: 'emailPin');
  final _mobilePinKey = GlobalKey(debugLabel: 'mobilePin');

  @override
  void initState() {
    super.initState();
    _newPwCtrl.addListener(_strengthCheck);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndSend());
  }

  void _strengthCheck() {
    if (_disposed) return;
    final p = _newPwCtrl.text;
    setState(() {
      _hasUpper = p.contains(RegExp(r'[A-Z]'));
      _hasLower = p.contains(RegExp(r'[a-z]'));
      _hasNumber = p.contains(RegExp(r'[0-9]'));
      _hasSymbol = p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _isLong = p.length >= 8;
    });
  }

  bool get _pwValid =>
      _hasUpper && _hasLower && _hasNumber && _hasSymbol && _isLong;

  // ============================================================
  // INIT – SEND OTPs TO BOTH EMAIL AND MOBILE
  // ============================================================
  Future<void> _initAndSend() async {
    setState(() {
      _isLoading = true;
      _mobileMissing = false;
    });
    if (widget.isForgotFlow && mounted) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _email = args;
      }
    }
    _email ??= await SecureStorage.getEmail();
    if (_email == null || _email!.isEmpty) {
      if (mounted) {
        _showSnack('Email not found. Please login again.', isError: true);
      }
      setState(() => _isLoading = false);
      return;
    }
    await _sendOtps(); // renamed from _sendOtp
  }

  // ============================================================
  // SEND BOTH OTPs (EMAIL + MOBILE) ON INITIAL LOAD
  // ============================================================
  Future<void> _sendOtps() async {
    try {
      // 1. Trigger email OTP via forgotPassword
      final result = await AuthService.forgotPassword(_email!);
      final mobileFromBackend = result['mobile']?.toString();

      if (mobileFromBackend != null && mobileFromBackend.isNotEmpty) {
        await SecureStorage.setMobile(mobileFromBackend);
        _mobile = mobileFromBackend;
        _mobileMissing = false;

        // 2. Immediately send mobile OTP
        try {
          await AuthService.resendResetMobileOtp(_mobile!);
        } catch (e) {
          // Mobile OTP send failed – show warning but continue
          if (mounted) {
            _showSnack('Mobile OTP send failed: $e', isError: true);
          }
        }
      } else {
        _mobileMissing = true;
        _mobile = null;
        // Email OTP was already sent; we'll ask user to enter mobile manually
        if (mounted) {
          _showSnack(
            'Mobile number not found. Please enter it manually to receive OTP.',
            isError: true,
          );
        }
      }

      _startTimer();
      setState(() {});
    } catch (e) {
      if (e.toString().contains('Mobile number not found')) {
        // Backend returned a specific error – treat as missing mobile
        _mobileMissing = true;
        _mobile = null;
        _startTimer();
        setState(() {});
        if (mounted) {
          _showSnack(
            'Mobile number not found. Please enter it manually.',
            isError: true,
          );
        }
      } else {
        if (mounted) _showSnack(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // MANUAL MOBILE ENTRY – SAVE & SEND OTP
  // ============================================================
  Future<void> _saveManualMobile() async {
    final enteredMobile = _manualMobileCtrl.text.trim();
    if (enteredMobile.isEmpty) {
      _showSnack('Please enter your mobile number', isError: true);
      return;
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(enteredMobile)) {
      _showSnack('Enter a valid 10-digit mobile number', isError: true);
      return;
    }
    await SecureStorage.setMobile(enteredMobile);
    _mobile = enteredMobile;
    _mobileMissing = false;
    try {
      await AuthService.resendResetMobileOtp(enteredMobile);
      _showSnack('OTP sent to your mobile number');
    } catch (e) {
      _showSnack('Failed to send OTP: ${e.toString()}', isError: true);
    }
    setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timerSecs = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      setState(() {
        if (_timerSecs <= 1) {
          _canResend = true;
          t.cancel();
        } else {
          _timerSecs--;
        }
      });
    });
  }

  // ============================================================
  // RESEND – BOTH OTPs
  // ============================================================
  Future<void> _resend() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      await AuthService.resendResetEmailOtp(_email!);
      if (_mobile != null && _mobile!.isNotEmpty) {
        await AuthService.resendResetMobileOtp(_mobile!);
      } else {
        _mobileMissing = true;
        _showSnack(
          'Mobile number missing. Please enter it manually.',
          isError: true,
        );
      }
      _startTimer();
      _emailOtp = '';
      _mobileOtp = '';
      setState(() {});
      if (mounted) _showSnack('OTP resent successfully');
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_emailOtp.length != 6 || _mobileOtp.length != 6) {
      _showSnack('Enter both 6‑digit OTPs', isError: true);
      return;
    }

    String? mobileToUse = _mobile;
    if (mobileToUse == null || mobileToUse.isEmpty) {
      mobileToUse = await SecureStorage.getMobile();
      if (mobileToUse == null || mobileToUse.isEmpty) {
        _mobileMissing = true;
        _showSnack(
          'Mobile number missing. Please enter it manually.',
          isError: true,
        );
        return;
      }
      _mobile = mobileToUse;
    }

    setState(() => _isVerifying = true);
    try {
      await AuthService.verifyResetEmail({'email': _email!, 'otp': _emailOtp});
      await AuthService.verifyResetMobile({
        'mobile': mobileToUse,
        'otp': _mobileOtp,
      });
      setState(() => _otpVerified = true);
      _showSnack('OTP Verified Successfully! ✅');
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_newPwCtrl.text != _confirmPwCtrl.text) {
      _showSnack('Passwords do not match!', isError: true);
      return;
    }
    if (!_pwValid) {
      _showSnack(
        'Password must have 8+ chars, uppercase, lowercase, number, special char',
        isError: true,
      );
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await AuthService.resetPassword({
        'email': _email!,
        'new_password': _newPwCtrl.text.trim(),
      });

      _showSnack('Password reset successfully! 🎉');
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      setState(() => _otpVerified = false);

      if (widget.isForgotFlow) {
        await SecureStorage.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "✅ Password changed! Please login with your new password."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            while (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            context.go(AppRoutes.auth);
          }
        }
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _manualMobileCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD – AI‑BASED MODERN UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStepIndicator(),
          const SizedBox(height: 20),
          if (!_otpVerified) _buildOtpSection() else _buildNewPasswordSection(),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (widget.isEmbedded) return body;
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(child: body),
      ),
    );
  }

  // ============================================================
  // AI‑BASED DESIGN COMPONENTS
  // ============================================================

  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
      ),
    );
  }

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
                  );
                },
              ),
              const SizedBox(height: 30),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ).createShader(bounds),
                child: const Text(
                  "AI is loading your security...",
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

  Widget _buildHeader() {
    return Container(
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
            child: Icon(
              widget.isForgotFlow ? Icons.lock_reset : Icons.lock,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isForgotFlow ? 'Reset Password' : 'Change Password',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _otpVerified
                      ? 'Set your new password'
                      : 'Verify your identity with OTP',
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
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

  Widget _buildAITextField(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
    int maxLines = 1,
    String? hintText,
    IconData? prefixIcon,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    bool showToggle = false,
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
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            hintText: hintText ?? (required ? null : "Optional"),
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey.shade600, size: 20)
                : null,
            suffixIcon: showToggle
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.transparent,
          ),
          validator: (value) => required && (value == null || value.isEmpty) ? "Required" : null,
        ),
      ),
    );
  }

  // ============================================================
  // STEP INDICATOR
  // ============================================================
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepItem('1. Verify OTP', !_otpVerified),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 2,
            color: _otpVerified ? Colors.green : Colors.grey.shade300,
          ),
        ),
        const SizedBox(width: 8),
        _buildStepItem('2. New Password', _otpVerified),
      ],
    );
  }

  Widget _buildStepItem(String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              )
            : null,
        color: active ? null : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? Colors.white : Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // ============================================================
  // OTP SECTION
  // ============================================================
  Widget _buildOtpSection() {
    final busy = _isVerifying || _isUpdating;
    return Column(
      children: [
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader("Contact Details", Icons.contact_mail,
                  subtitle: "OTP will be sent to these"),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _email ?? 'Loading...',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_mobileMissing)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Text(
                        'Mobile number not found. Please enter manually.',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAITextField(
                            _manualMobileCtrl,
                            'Enter 10-digit mobile',
                            keyboardType: TextInputType.phone,
                            required: true,
                            prefixIcon: Icons.phone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveManualMobile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                )
              else if (_mobile != null && _mobile!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '+91$_mobile',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader("Enter OTP", Icons.verified,
                  subtitle: "We sent OTPs to your email and mobile"),
              const Text('Email OTP', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildPinCodeField(
                key: _emailPinKey,
                onChanged: (v) => setState(() => _emailOtp = v),
                enabled: !busy && !_mobileMissing,
              ),
              const SizedBox(height: 16),
              const Text('Mobile OTP', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildPinCodeField(
                key: _mobilePinKey,
                onChanged: (v) => setState(() => _mobileOtp = v),
                enabled: !busy && !_mobileMissing,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
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
                  child: ElevatedButton(
                    onPressed: (busy || _mobileMissing) ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check_circle, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Verify & Continue',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: _canResend && !_mobileMissing
                    ? TextButton(
                        onPressed: _isResending ? null : _resend,
                        child: _isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Resend OTP',
                                style: TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      )
                    : Text(
                        'Resend OTP in $_timerSecs seconds',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinCodeField({
    required GlobalKey key,
    required ValueChanged<String> onChanged,
    required bool enabled,
  }) {
    return PinCodeTextField(
      key: key,
      appContext: context,
      length: 6,
      keyboardType: TextInputType.number,
      enabled: enabled,
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(12),
        fieldHeight: 54,
        fieldWidth: 46,
        activeColor: const Color(0xFF6C63FF),
        selectedColor: const Color(0xFF6C63FF),
        inactiveColor: Colors.grey.shade400,
        activeFillColor: Colors.white,
        inactiveFillColor: Colors.transparent,
        selectedFillColor: Colors.white,
      ),
      onChanged: onChanged,
    );
  }

  // ============================================================
  // NEW PASSWORD SECTION
  // ============================================================
  Widget _buildNewPasswordSection() {
    final busy = _isUpdating;
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("New Password", Icons.lock_outline,
              subtitle: "Create a strong password"),
          _buildAITextField(
            _newPwCtrl,
            'New Password',
            required: true,
            obscureText: !_showNew,
            showToggle: true,
            onToggleObscure: () => setState(() => _showNew = !_showNew),
            prefixIcon: Icons.lock,
          ),
          const SizedBox(height: 8),
          _buildPasswordStrength(),
          const SizedBox(height: 16),
          _buildAITextField(
            _confirmPwCtrl,
            'Confirm New Password',
            required: true,
            obscureText: !_showConfirm,
            showToggle: true,
            onToggleObscure: () => setState(() => _showConfirm = !_showConfirm),
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Container(
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
              child: ElevatedButton(
                onPressed: (busy || !_pwValid) ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: busy
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.save, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrength() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Requirements',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _buildRequirement('At least 8 characters', _isLong),
          _buildRequirement('One uppercase letter', _hasUpper),
          _buildRequirement('One lowercase letter', _hasLower),
          _buildRequirement('One number', _hasNumber),
          _buildRequirement('One special character', _hasSymbol),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            color: ok ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: ok ? Colors.green : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}