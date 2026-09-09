// lib/features/auth/presentation/screens/change_password_screen.dart
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
    await _sendOtp();
  }

  Future<void> _sendOtp() async {
    try {
      final result = await AuthService.forgotPassword(_email!);
      final mobileFromBackend = result['mobile']?.toString();
      if (mobileFromBackend != null && mobileFromBackend.isNotEmpty) {
        await SecureStorage.setMobile(mobileFromBackend);
        _mobile = mobileFromBackend;
        _mobileMissing = false;
      } else {
        _mobileMissing = true;
        _mobile = null;
      }
      _startTimer();
      setState(() {});
    } catch (e) {
      if (e.toString().contains('Mobile number not found')) {
        _mobileMissing = true;
        _mobile = null;
        _startTimer();
        setState(() {});
      } else {
        if (mounted) _showSnack(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        // Clear any existing tokens
        await SecureStorage.clear();

        if (mounted) {
          // Show success message
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
            // ✅ Navigate to login page
            // This will clear the entire navigation stack and go to auth page
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

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || _isVerifying || _isUpdating;
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isForgotFlow ? 'Reset Password' : 'Change Password',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _stepBar(),
          const SizedBox(height: 24),
          if (!_otpVerified) _otpSection(busy) else _newPwSection(busy),
        ],
      ),
    );
    if (widget.isEmbedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isForgotFlow ? 'Forgot Password' : 'Change Password',
        ),
        backgroundColor: Colors.blueAccent,
      ),
      body: body,
    );
  }

  Widget _stepBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _stepBtn('1. Verify OTP', !_otpVerified)),
          Expanded(child: _stepBtn('2. New Password', _otpVerified)),
        ],
      ),
    );
  }

  Widget _stepBtn(String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: active ? Colors.blueAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? Colors.white : Colors.grey.shade600,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _otpSection(bool busy) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📧 Email: ${_email ?? "Loading..."}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (_mobileMissing)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Mobile number not found in our records.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manualMobileCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'Enter 10-digit mobile number',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveManualMobile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                )
              else if (_mobile != null && _mobile!.isNotEmpty)
                Text(
                  '📱 Mobile: +91$_mobile',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Email OTP', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        PinCodeTextField(
          key: _emailPinKey,
          appContext: context,
          length: 6,
          keyboardType: TextInputType.number,
          enabled: !busy && !_mobileMissing,
          pinTheme: _pinTheme(),
          onChanged: (value) {
            setState(() => _emailOtp = value);
          },
        ),
        const SizedBox(height: 20),
        const Text('Mobile OTP', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        PinCodeTextField(
          key: _mobilePinKey,
          appContext: context,
          length: 6,
          keyboardType: TextInputType.number,
          enabled: !busy && !_mobileMissing,
          pinTheme: _pinTheme(),
          onChanged: (value) {
            setState(() => _mobileOtp = value);
          },
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (busy || _mobileMissing) ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: busy
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Verify & Continue',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 16),
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
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                )
              : Text(
                  'Resend OTP in $_timerSecs seconds',
                  style: const TextStyle(color: Colors.grey),
                ),
        ),
      ],
    );
  }

  Widget _newPwSection(bool busy) {
    return Column(
      children: [
        TextField(
          controller: _newPwCtrl,
          obscureText: !_showNew,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_showNew ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _showNew = !_showNew),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        _PwStrength(
          hasUpper: _hasUpper,
          hasLower: _hasLower,
          hasNumber: _hasNumber,
          hasSymbol: _hasSymbol,
          isLong: _isLong,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmPwCtrl,
          obscureText: !_showConfirm,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _showConfirm ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _showConfirm = !_showConfirm),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (busy || !_pwValid) ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: busy
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  PinTheme _pinTheme() {
    return PinTheme(
      shape: PinCodeFieldShape.box,
      borderRadius: BorderRadius.circular(10),
      fieldHeight: 54,
      fieldWidth: 46,
      activeColor: Colors.blueAccent,
      selectedColor: Colors.blueAccent,
      inactiveColor: Colors.grey.shade400,
      activeFillColor: Colors.white,
      inactiveFillColor: Colors.transparent,
      selectedFillColor: Colors.white,
    );
  }
}

class _PwStrength extends StatelessWidget {
  final bool hasUpper;
  final bool hasLower;
  final bool hasNumber;
  final bool hasSymbol;
  final bool isLong;

  const _PwStrength({
    required this.hasUpper,
    required this.hasLower,
    required this.hasNumber,
    required this.hasSymbol,
    required this.isLong,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Item('At least 8 characters', isLong),
        _Item('One uppercase letter', hasUpper),
        _Item('One lowercase letter', hasLower),
        _Item('One number', hasNumber),
        _Item('One special character', hasSymbol),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  final String text;
  final bool ok;

  const _Item(this.text, this.ok);

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
