// lib/features/auth/presentation/screens/fingerprint_setup_page.dart
// COMPLETE FIXED VERSION - NEVER RESETS BIOMETRIC DATA

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/auth/presentation/controllers/auth_controller.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';

// ==================== BIOMETRIC HELPER ====================
class _BiometricHelper {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint("Biometric isDeviceSupported error: $e");
      return false;
    }
  }

  static Future<bool> get canCheckBiometrics async {
    if (kIsWeb) return false;
    try {
      final available = await _localAuth.getAvailableBiometrics();
      debugPrint("Available biometrics: $available");
      return available.isNotEmpty;
    } catch (e) {
      debugPrint("Biometric canCheckBiometrics error: $e");
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint("Biometric getAvailableBiometrics error: $e");
      return [];
    }
  }

  static Future<bool> authenticate({
    required String localizedReason,
  }) async {
    if (kIsWeb) return false;
    try {
      debugPrint("🔐 Starting biometric authentication...");
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      debugPrint("🔐 Biometric authentication result: $authenticated");
      return authenticated;
    } catch (e) {
      debugPrint("❌ Biometric authentication error: $e");
      return false;
    }
  }
}

// ==================== MAIN FINGERPRINT SETUP PAGE ====================
class FingerprintSetupPage extends StatefulWidget {
  final String email;
  const FingerprintSetupPage({super.key, required this.email});

  @override
  State<FingerprintSetupPage> createState() => _FingerprintSetupPageState();
}

class _FingerprintSetupPageState extends State<FingerprintSetupPage> {
  bool _isBiometricAvailable = false;
  bool _isDeviceSupported = false;
  bool _isLoading = true;
  bool _isBiometricEnabled = false;
  bool _hasExistingBiometric = false;
  String _errorMessage = '';
  String _biometricTypeName = 'Fingerprint';
  String _deviceInfo = '';
  String _availabilityMessage = '';
  bool _isEnrolling = false;
  bool _isWeb = false;

  @override
  void initState() {
    super.initState();
    _isWeb = kIsWeb;
    _checkBiometricAvailability();
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    if (_isWeb) {
      if (mounted) setState(() => _deviceInfo = 'Web Browser');
      return;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        if (mounted) {
          setState(() => _deviceInfo = '${androidInfo.manufacturer} ${androidInfo.model}');
        }
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        if (mounted) {
          setState(() => _deviceInfo = '${iosInfo.name} (iOS ${iosInfo.systemVersion})');
        }
      } else {
        if (mounted) setState(() => _deviceInfo = 'Mobile Device');
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
      if (mounted) setState(() => _deviceInfo = 'Mobile Device');
    }
  }

  Future<void> _checkBiometricAvailability() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (_isWeb) {
        if (mounted) {
          setState(() {
            _isDeviceSupported = false;
            _isBiometricAvailable = false;
            _availabilityMessage = 'Biometric authentication is not supported on web browsers.';
            _biometricTypeName = 'Biometric';
          });
        }
      } else {
        _isDeviceSupported = await _BiometricHelper.isDeviceSupported();
        debugPrint('📱 Device supports biometrics: $_isDeviceSupported');

        if (_isDeviceSupported) {
          _isBiometricAvailable = await _BiometricHelper.canCheckBiometrics;
          debugPrint('🔐 Biometrics available: $_isBiometricAvailable');

          if (_isBiometricAvailable) {
            final availableBiometrics = await _BiometricHelper.getAvailableBiometrics();
            debugPrint('📱 Available biometrics: $availableBiometrics');

            if (availableBiometrics.contains(BiometricType.face)) {
              _biometricTypeName = 'Face ID';
            } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
              _biometricTypeName = 'Fingerprint';
            } else if (availableBiometrics.contains(BiometricType.iris)) {
              _biometricTypeName = 'Iris Scan';
            } else {
              _biometricTypeName = 'Biometric';
            }
            _availabilityMessage = '$_biometricTypeName is available on your device';
          } else {
            _availabilityMessage = 'No $_biometricTypeName enrolled. Please add $_biometricTypeName in device settings.';
          }
        } else {
          _availabilityMessage = 'Biometric authentication is not supported on this device.';
        }
      }

      final isEnabled = await SecureStorage.isBiometricEnabled();
      if (mounted) {
        setState(() {
          _isBiometricEnabled = isEnabled && !_isWeb && _isBiometricAvailable;
          _hasExistingBiometric = isEnabled && !_isWeb && _isBiometricAvailable;
        });
      }

      debugPrint('✅ Biometric check - Supported: $_isDeviceSupported, '
          'Available: $_isBiometricAvailable, Type: $_biometricTypeName, Enabled: $_isBiometricEnabled');
    } catch (e) {
      debugPrint('❌ Biometric check error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error checking biometrics: $e';
          _availabilityMessage = 'Could not check biometric availability. Please check device settings.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== TOGGLE BIOMETRIC - NEVER RESETS DATA ====================
  Future<void> _toggleBiometric(bool value) async {
    if (!mounted) return;

    if (_isWeb) {
      if (mounted) {
        showMessage(
          context,
          "Fingerprint login is not available on web browsers. Please use mobile app.",
          isError: true,
        );
      }
      if (mounted) setState(() => _isBiometricEnabled = false);
      return;
    }

    // ============================================================
    // ✅ CASE 1: DISABLING BIOMETRIC - User explicitly turns OFF
    // ============================================================
    if (!value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Disable Fingerprint Login"),
          content: const Text(
            "Are you sure you want to disable fingerprint login?\n\n"
            "You can enable it again later from settings.\n\n"
            "✅ Your fingerprint data will NOT be deleted.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Disable"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        if (!mounted) return;
        setState(() => _isLoading = true);
        try {
          await _clearBiometricFromBackend();
          await SecureStorage.disableBiometric();
          if (mounted) {
            setState(() {
              _isBiometricEnabled = false;
              _hasExistingBiometric = false;
            });
            showMessage(
              context,
              "$_biometricTypeName login disabled successfully.",
              isError: false,
            );
          }
        } catch (e) {
          if (mounted) {
            showMessage(
              context,
              "Failed to disable biometric: $e",
              isError: true,
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
      return;
    }

    // ============================================================
    // ✅ CASE 2: ENABLING BIOMETRIC - User explicitly turns ON
    // ============================================================
    if (!_isBiometricAvailable) {
      if (mounted) {
        showMessage(
          context,
          _availabilityMessage,
          isError: true,
        );
      }
      if (mounted) setState(() => _isBiometricEnabled = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final didAuthenticate = await _BiometricHelper.authenticate(
        localizedReason: 'Set up $_biometricTypeName login for RojgarNext',
      );

      if (!didAuthenticate) {
        if (mounted) {
          showMessage(
            context,
            "Authentication failed. Please try again.",
            isError: true,
          );
        }
        if (mounted) setState(() => _isBiometricEnabled = false);
        return;
      }

      await _saveBiometricToBackend();
      await SecureStorage.setBiometricEnabled(true);

      if (mounted) {
        setState(() {
          _isBiometricEnabled = true;
          _hasExistingBiometric = true;
        });
        showMessage(
            context,
            "🔐 $_biometricTypeName Login Enabled Successfully!\n\n"
            "✅ Your fingerprint will NEVER be deleted on logout.",
            isError: false,
          );
        
        await Future.delayed(const Duration(seconds: 1));
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      debugPrint("❌ Biometric setup error: $e");
      if (mounted) {
        showMessage(
          context,
          "Biometric setup failed: ${e.toString().replaceAll('Exception:', '')}",
          isError: true,
        );
      }
      if (mounted) setState(() => _isBiometricEnabled = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== SAVE BIOMETRIC TO BACKEND - FIXED ====================
  Future<void> _saveBiometricToBackend() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) throw Exception("No authentication token found");

      // ✅ FIXED: Get correct biometric type (lowercase)
      final biometricType = await _getBiometricType();
      final deviceId = await _getDeviceId();

      debugPrint("📤 Sending biometric enable request for: ${widget.email}");
      debugPrint("   Biometric Type: $biometricType");
      debugPrint("   Device Info: $_deviceInfo");
      debugPrint("   Device ID: $deviceId");

      final requestData = {
        "email": widget.email,
        "device_info": _deviceInfo,
        "device_id": deviceId,
        "biometric_type": biometricType, // ✅ Now sends correct lowercase value
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/enable-biometric'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("✅ Biometric saved to backend successfully");
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? "Failed to save biometric to backend");
      }
    } catch (e) {
      debugPrint("❌ Error saving biometric to backend: $e");
      throw Exception("Could not save biometric to server: $e");
    }
  }

  // ✅ FIXED: Returns correct lowercase values expected by backend schema
  Future<String> _getBiometricType() async {
    try {
      if (_isWeb) {
        return "fingerprint";
      }

      final localAuth = LocalAuthentication();
      final isSupported = await localAuth.isDeviceSupported();
      if (!isSupported) {
        return "fingerprint";
      }

      final available = await localAuth.getAvailableBiometrics();
      debugPrint("📱 Available biometrics: $available");

      // ✅ Map to exact lowercase values expected by backend
      if (available.contains(BiometricType.fingerprint)) {
        return "fingerprint";
      }
      if (available.contains(BiometricType.face)) {
        return "face";
      }
      if (available.contains(BiometricType.iris)) {
        return "iris";
      }
      
      return "fingerprint";
    } catch (e) {
      debugPrint("❌ Error getting biometric type: $e");
      return "fingerprint";
    }
  }

  Future<String> _getDeviceId() async {
    try {
      if (_isWeb) {
        return "web_${DateTime.now().millisecondsSinceEpoch}";
      }
      final deviceInfo = DeviceInfoPlugin();
      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // ==================== CLEAR BIOMETRIC FROM BACKEND ====================
  Future<void> _clearBiometricFromBackend() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) return;

      final requestData = {
        "email": widget.email,
        "is_biometric_enabled": false,
      };

      debugPrint("📤 Sending biometric disable request for: ${widget.email}");

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/disable-biometric'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Biometric cleared from backend");
      }
    } catch (e) {
      debugPrint("❌ Error clearing biometric from backend: $e");
    }
  }

  // ==================== FINGERPRINT LOGIN ====================
  Future<void> _loginWithFingerprint() async {
    if (_isWeb) {
      if (mounted) {
        showMessage(
          context,
          "Fingerprint login is not available on web browsers.",
          isError: true,
        );
      }
      return;
    }

    if (!_isBiometricEnabled || !_hasExistingBiometric) {
      if (mounted) {
        showMessage(
          context,
          "Fingerprint login is not enabled. Please enable it using the toggle above.",
          isError: true,
        );
      }
      return;
    }

    if (!_isBiometricAvailable) {
      if (mounted) {
        showMessage(
          context,
          _availabilityMessage,
          isError: true,
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isEnrolling = true);

    try {
      final didAuthenticate = await _BiometricHelper.authenticate(
        localizedReason: 'Verify your fingerprint to login to RojgarNext',
      );

      if (didAuthenticate) {
        final authController = Provider.of<AuthController>(context, listen: false);
        await authController.biometricLogin(context);
      } else {
        if (mounted) {
          showMessage(
            context,
            "Authentication cancelled or failed.",
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Biometric login error: $e");
      if (mounted) {
        showMessage(
          context,
          "Biometric login failed: ${e.toString().replaceAll('Exception:', '')}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  Future<void> _removeAndClearBiometric() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Fingerprint Login"),
        content: const Text(
          "Are you sure you want to remove your fingerprint login?\n\n"
          "You will need to set it up again to use fingerprint login.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await _clearBiometricFromBackend();
        await SecureStorage.disableBiometric();
        if (mounted) {
          setState(() {
            _isBiometricEnabled = false;
            _hasExistingBiometric = false;
          });
          showMessage(
            context,
            "$_biometricTypeName login removed successfully.",
            isError: false,
          );
        }
      } catch (e) {
        if (mounted) {
          showMessage(
            context,
            "Failed to remove biometric: $e",
            isError: true,
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometricIcon = _biometricTypeName == 'Face ID'
        ? Icons.face
        : (_biometricTypeName == 'Iris Scan'
            ? Icons.visibility
            : Icons.fingerprint);

    if (_isLoading) {
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
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Checking biometric settings..."),
              ],
            ),
          ),
        ),
      );
    }

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
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(biometricIcon),
                  const SizedBox(height: 30),
                  _buildToggleCard(biometricIcon),
                  const SizedBox(height: 24),
                  if (!_isWeb && _isBiometricEnabled && _hasExistingBiometric)
                    _buildFingerprintLoginButton(biometricIcon),
                  const SizedBox(height: 24),
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  if (_errorMessage.isNotEmpty) _buildErrorWidget(),
                  if (!_isWeb && _isBiometricEnabled && _hasExistingBiometric)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildRemoveButton(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader(IconData biometricIcon) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Colors.purpleAccent],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withAlpha(77),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Icon(
                _isBiometricEnabled && !_isWeb
                    ? Icons.check_circle
                    : biometricIcon,
                size: 80,
                color: Colors.white.withAlpha(230),
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withAlpha(26), Colors.white.withAlpha(13)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withAlpha(51)),
        ),
        child: Column(
          children: [
            Text(
              _isWeb
                  ? "Biometric Login"
                  : (_isBiometricEnabled
                      ? "$_biometricTypeName Login Enabled"
                      : "Enable $_biometricTypeName Login"),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isWeb
                  ? "Biometric login is not available on web browsers"
                  : (_isBiometricEnabled && _hasExistingBiometric
                      ? "Your $_biometricTypeName is currently enabled"
                      : _isBiometricEnabled && !_hasExistingBiometric
                          ? "Set up your $_biometricTypeName for quick & secure login"
                          : "Enable $_biometricTypeName for faster and more secure login"),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(204),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ON/OFF TOGGLE CARD ====================
  Widget _buildToggleCard(IconData biometricIcon) {
    final bool isAvailable =
        !_isWeb && _isDeviceSupported && _isBiometricAvailable;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _isBiometricEnabled && !_isWeb
                ? Colors.green.withAlpha(26)
                : Colors.white.withAlpha(13),
            Colors.white.withAlpha(26),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isBiometricEnabled && !_isWeb
              ? Colors.green.withAlpha(102)
              : Colors.white.withAlpha(51),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isBiometricEnabled && !_isWeb
                          ? Colors.green.withAlpha(26)
                          : Colors.white.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      biometricIcon,
                      color: _isBiometricEnabled && !_isWeb
                          ? Colors.green
                          : Colors.white70,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$_biometricTypeName Login",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isBiometricEnabled && !_isWeb
                              ? Colors.green
                              : Colors.white,
                        ),
                      ),
                      Text(
                        _isWeb
                            ? "Not available on web"
                            : (isAvailable
                                ? (_isBiometricEnabled && _hasExistingBiometric
                                    ? "Quick login with your $_biometricTypeName"
                                    : _isBiometricEnabled &&
                                            !_hasExistingBiometric
                                        ? "Tap to set up your $_biometricTypeName"
                                        : "Enable $_biometricTypeName for faster login")
                                : "Biometric not available on this device"),
                        style: TextStyle(
                          fontSize: 13,
                          color: _isBiometricEnabled && !_isWeb
                              ? Colors.green.shade300
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isWeb && isAvailable)
                Transform.scale(
                  scale: 1.2,
                  child: Switch(
                    value: _isBiometricEnabled,
                    onChanged: _toggleBiometric,
                    activeThumbColor: Colors.green,
                    activeTrackColor: Colors.green.shade200,
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.shade800,
                  ),
                )
              else if (!_isWeb)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isWeb ? "Web Not Supported" : "Not Available",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
          if (!_isWeb &&
              _isBiometricEnabled &&
              _hasExistingBiometric &&
              isAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(biometricIcon, color: Colors.green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "$_biometricTypeName is enabled. You can use it for quick login.\n\n"
                        "✅ Your fingerprint will NEVER be deleted on logout.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isWeb &&
              _isBiometricEnabled &&
              !_hasExistingBiometric &&
              isAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(biometricIcon, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Toggle ON to set up your $_biometricTypeName",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isWeb && !isAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _availabilityMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
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

  // ==================== FINGERPRINT LOGIN BUTTON ====================
  Widget _buildFingerprintLoginButton(IconData biometricIcon) {
    return Column(
      children: [
        const Divider(color: Colors.white24),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _isEnrolling ? null : _loginWithFingerprint,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withAlpha(77),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _isEnrolling
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    biometricIcon,
                    size: 48,
                    color: Colors.white,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isEnrolling
              ? "Verifying..."
              : "Tap to Login with $_biometricTypeName",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withAlpha(204),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security, size: 14, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                "Secure Biometric Authentication",
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== INFO CARD ====================
  Widget _buildInfoCard() {
    final bool isAvailable =
        !_isWeb && _isDeviceSupported && _isBiometricAvailable;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(13), Colors.white.withAlpha(26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(51)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.phone_android,
            "Platform",
            _isWeb ? "Web Browser" : "Mobile Device",
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            _biometricTypeName == 'Face ID' ? Icons.face : Icons.fingerprint,
            "Biometric",
            _isWeb
                ? "Not Available on Web"
                : (isAvailable
                    ? "$_biometricTypeName Available ✓"
                    : "Not Available"),
            color: _isWeb
                ? Colors.orange
                : (isAvailable ? Colors.green : Colors.red),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.security,
            "Status",
            _isWeb
                ? "Web Not Supported"
                : (_isBiometricEnabled ? "Enabled ✓" : "Disabled"),
            color: _isWeb
                ? Colors.orange
                : (_isBiometricEnabled ? Colors.green : Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(102)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _removeAndClearBiometric,
        icon: const Icon(Icons.delete_outline, size: 20),
        label: const Text(
          "Remove Fingerprint Login",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }
}