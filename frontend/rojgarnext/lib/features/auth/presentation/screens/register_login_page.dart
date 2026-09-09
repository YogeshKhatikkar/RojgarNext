// lib/features/auth/presentation/screens/register_login_page.dart
// ✅ COMPLETE FIXED VERSION - MPIN Login Button Always Visible

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/auth/presentation/controllers/auth_controller.dart';
import 'package:rojgarnext/features/auth/presentation/screens/change_password_screen.dart';
import 'package:rojgarnext/features/auth/presentation/screens/fingerprint_setup_page.dart';
import 'package:rojgarnext/features/common/widgets/internet_checker.dart';

class RegisterLoginPage extends StatefulWidget {
  final String? initialTab;

  const RegisterLoginPage({super.key, this.initialTab});

  @override
  State<RegisterLoginPage> createState() => _RegisterLoginPageState();
}

class _RegisterLoginPageState extends State<RegisterLoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _loginMethodIndex = 0;

  // Controllers
  final loginEmailCtrl = TextEditingController();
  final loginPasswordCtrl = TextEditingController();
  final mpinEmailCtrl = TextEditingController();
  final pinCtrl = TextEditingController();

  final registerNameCtrl = TextEditingController();
  final registerEmailCtrl = TextEditingController();
  final registerMobileCtrl = TextEditingController();
  final registerPasswordCtrl = TextEditingController();

  bool showPassword = false;
  bool showRegisterPassword = false;

  // Password Strength
  bool hasUpper = false;
  bool hasLower = false;
  bool hasNumber = false;
  bool hasSymbol = false;
  bool isLongEnough = false;

  late AuthController _authController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    registerPasswordCtrl.addListener(_checkPasswordStrength);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialTab != null) {
        final tabIndex = int.tryParse(widget.initialTab!);
        if (tabIndex == 1) {
          _tabController.animateTo(1);
        } else if (tabIndex == 0) {
          _tabController.animateTo(0);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _authController.initialize(
        onShowMessage: (message, {isError = false}) {
          if (mounted) {
            showMessage(context, message, isError: isError);
          }
        },
      );
    });
  }

  void _checkPasswordStrength() {
    if (!mounted) return;
    final p = registerPasswordCtrl.text;
    setState(() {
      hasUpper = p.contains(RegExp(r'[A-Z]'));
      hasLower = p.contains(RegExp(r'[a-z]'));
      hasNumber = p.contains(RegExp(r'[0-9]'));
      hasSymbol = p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      isLongEnough = p.length >= 8;
    });
  }

  bool _isPasswordValid() =>
      hasUpper && hasLower && hasNumber && hasSymbol && isLongEnough;

  void _safeShowMessage(String message, {bool isError = false}) {
    if (mounted) {
      showMessage(context, message, isError: isError);
    }
  }

  @override
  void dispose() {
    loginEmailCtrl.dispose();
    loginPasswordCtrl.dispose();
    mpinEmailCtrl.dispose();
    pinCtrl.dispose();
    registerNameCtrl.dispose();
    registerEmailCtrl.dispose();
    registerMobileCtrl.dispose();
    registerPasswordCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32,
                    vertical: 20,
                  ),
                  child: Container(
                    width: isMobile ? double.infinity : 440,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withAlpha(26),
                          Colors.white.withAlpha(13)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withAlpha(51)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildTabBar(),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: _tabController.index == 0 ? 650 : 540,
                          child: TabBarView(
                            controller: _tabController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildLoginTab(auth),
                              _buildRegisterTab(auth),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ✅ Internet Connection Checker - Shows Offline Message
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: InternetChecker(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.work_outline,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "RojgarNext",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Find Your Dream Job",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withAlpha(179),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: "Login"),
          Tab(text: "Register"),
        ],
      ),
    );
  }

  // ================= LOGIN TAB =================
  Widget _buildLoginTab(AuthController auth) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            children: [
              _buildLoginMethodChip(
                index: 0,
                label: "Email",
                icon: Icons.email_outlined,
                selectedIndex: _loginMethodIndex,
                onTap: () => setState(() => _loginMethodIndex = 0),
              ),
              _buildLoginMethodChip(
                index: 1,
                label: "MPIN",
                icon: Icons.pin,
                selectedIndex: _loginMethodIndex,
                onTap: () => setState(() => _loginMethodIndex = 1),
              ),
              _buildLoginMethodChip(
                index: 2,
                label: "Fingerprint",
                icon: Icons.fingerprint,
                selectedIndex: _loginMethodIndex,
                onTap: () => setState(() => _loginMethodIndex = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: _getLoginContent(auth),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginMethodChip({
    required int index,
    required String label,
    required IconData icon,
    required int selectedIndex,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withAlpha(51) : Colors.transparent,
            borderRadius: BorderRadius.circular(36),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getLoginContent(AuthController auth) {
    if (_loginMethodIndex == 0) return _buildEmailPasswordLogin(auth);
    if (_loginMethodIndex == 1) return _buildMpinLogin(auth);
    return _buildBiometricLogin(auth);
  }

  // ==================== EMAIL PASSWORD LOGIN SECTION ====================
  Widget _buildEmailPasswordLogin(AuthController auth) {
    return Column(
      children: [
        _buildTextField(loginEmailCtrl, "Email Address", Icons.email_outlined),
        const SizedBox(height: 12),
        _buildPasswordField(loginPasswordCtrl, "Password", Icons.lock_outline),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              final email = loginEmailCtrl.text.trim();
              if (email.isEmpty) {
                _safeShowMessage("Please enter your email first", isError: true);
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(
                    isForgotFlow: true,
                    isEmbedded: false,
                  ),
                  settings: RouteSettings(arguments: email),
                ),
              );
            },
            child: const Text(
              "Forgot Password?",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _ModernButton(
          text: "Login",
          isLoading: auth.isLoading,
          onTap: () {
            final email = loginEmailCtrl.text.trim();
            final password = loginPasswordCtrl.text.trim();

            if (email.isEmpty) {
              _safeShowMessage("Please enter your email address", isError: true);
              return;
            }
            if (password.isEmpty) {
              _safeShowMessage("Please enter your password", isError: true);
              return;
            }
            if (!email.contains('@') || !email.contains('.')) {
              _safeShowMessage("Please enter a valid email address", isError: true);
              return;
            }
            if (password.length < 6) {
              _safeShowMessage("Password must be at least 6 characters", isError: true);
              return;
            }

            auth.login(email, password, context);
          },
        ),
      ],
    );
  }

  // ==================== MPIN LOGIN SECTION - FIXED ====================
  Widget _buildMpinLogin(AuthController auth) {
    final TextEditingController localPinCtrl = TextEditingController();
    bool obscurePin = true;

    return StatefulBuilder(
      builder: (context, setMpinState) {
        // ✅ FIXED: Button is ALWAYS visible, enabled when pin is complete
        final bool isPinComplete = localPinCtrl.text.length == 6;

        return Column(
          children: [
            _buildTextField(mpinEmailCtrl, "Email Address", Icons.email_outlined),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withAlpha(13),
                    Colors.white.withAlpha(26)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(51)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blueAccent, Colors.purpleAccent],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pin, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Enter 6-Digit MPIN",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final String text = localPinCtrl.text;
                          final bool isFilled = index < text.length;
                          final String displayChar =
                              obscurePin ? '•' : (isFilled ? text[index] : '');

                          return Container(
                            width: 42,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                Text(
                                  isFilled ? displayChar : '',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isFilled ? Colors.white : Colors.transparent,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blueAccent.withAlpha(128),
                                        Colors.blueAccent,
                                        Colors.blueAccent.withAlpha(128),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      _buildNumberPad(
                        onNumberPressed: (number) {
                          String current = localPinCtrl.text;
                          if (current.length < 6) {
                            String newValue = current + number;
                            setMpinState(() {
                              localPinCtrl.text = newValue;
                              pinCtrl.text = newValue;
                            });
                          }
                        },
                        onDeletePressed: () {
                          String current = localPinCtrl.text;
                          if (current.isNotEmpty) {
                            String newValue = current.substring(0, current.length - 1);
                            setMpinState(() {
                              localPinCtrl.text = newValue;
                              pinCtrl.text = newValue;
                            });
                          }
                        },
                        onClearPressed: () {
                          setMpinState(() {
                            localPinCtrl.clear();
                            pinCtrl.clear();
                          });
                        },
                        obscurePin: obscurePin,
                        onToggleObscure: () {
                          setMpinState(() {
                            obscurePin = !obscurePin;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withAlpha(26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.security, size: 14, color: Colors.blueAccent),
                            SizedBox(width: 6),
                            Text(
                              "Secure MPIN Login",
                              style: TextStyle(fontSize: 11, color: Colors.blueAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ✅ FIXED: Login button ALWAYS visible, enabled when pin is complete
            _ModernButton(
              text: "Login with MPIN",
              isLoading: auth.isLoading,
              // ✅ FIXED: Button is enabled when email is filled AND pin is complete
              onTap: () {
                final email = mpinEmailCtrl.text.trim();
                final pin = localPinCtrl.text.trim();
                if (email.isEmpty || pin.length != 6) {
                  _safeShowMessage("Please enter email and 6-digit MPIN", isError: true);
                  return;
                }
                pinCtrl.text = pin;
                auth.loginWithMpin(email, pin, context);
              },
            ),
          ],
        );
      },
    );
  }

  // ==================== NUMBER PAD WIDGET ====================
  Widget _buildNumberPad({
    required Function(String) onNumberPressed,
    required VoidCallback onDeletePressed,
    required VoidCallback onClearPressed,
    required bool obscurePin,
    required VoidCallback onToggleObscure,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('1', onNumberPressed),
            _buildNumberButton('2', onNumberPressed),
            _buildNumberButton('3', onNumberPressed),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('4', onNumberPressed),
            _buildNumberButton('5', onNumberPressed),
            _buildNumberButton('6', onNumberPressed),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('7', onNumberPressed),
            _buildNumberButton('8', onNumberPressed),
            _buildNumberButton('9', onNumberPressed),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildIconButton(
              icon: obscurePin ? Icons.visibility_off : Icons.visibility,
              onPressed: onToggleObscure,
              label: obscurePin ? "Show" : "Hide",
            ),
            _buildNumberButton('0', onNumberPressed),
            _buildIconButton(
              icon: Icons.backspace,
              onPressed: onDeletePressed,
              label: "Del",
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onClearPressed,
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text("CLEAR ALL"),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number, Function(String) onPressed) {
    return SizedBox(
      width: 60,
      height: 50,
      child: Material(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onPressed(number),
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? label,
  }) {
    return SizedBox(
      width: 60,
      height: 50,
      child: Material(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 24),
              if (label != null)
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BIOMETRIC LOGIN SECTION ====================
  Widget _buildBiometricLogin(AuthController auth) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withAlpha(26), Colors.white.withAlpha(13)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.fingerprint,
            size: 80,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Use Fingerprint",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Touch sensor to login instantly",
          style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildBiometricStatusInfo(),
        const SizedBox(height: 20),
        _ModernButton(
          text: "Login with Fingerprint",
          isLoading: auth.isLoading,
          onTap: () {
            auth.checkAndHandleBiometricLogin(context);
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<bool>(
          future: SecureStorage.isBiometricEnabled(),
          builder: (context, snapshot) {
            final isEnabled = snapshot.data ?? false;
            return FutureBuilder<String?>(
              future: SecureStorage.getEmail(),
              builder: (context, emailSnapshot) {
                final hasEmail = emailSnapshot.data != null && emailSnapshot.data!.isNotEmpty;
                
                if (isEnabled && hasEmail) {
                  return const SizedBox.shrink();
                }
                
                String buttonText = "🔐 Enable Fingerprint Login";
                if (!hasEmail) {
                  buttonText = "📧 Login with Email & Password first";
                }
                
                return TextButton(
                  onPressed: () async {
                    if (!hasEmail) {
                      _safeShowMessage(
                        "Please login with email & password first to enable biometric.",
                        isError: true,
                      );
                      return;
                    }
                    
                    final email = await SecureStorage.getEmail();
                    if (email != null && email.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FingerprintSetupPage(email: email),
                        ),
                      );
                    } else {
                      _safeShowMessage(
                        "Please login with email & password first to enable biometric.",
                        isError: true,
                      );
                    }
                  },
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      color: !hasEmail ? Colors.grey : Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBiometricStatusInfo() {
    return FutureBuilder<bool>(
      future: SecureStorage.isBiometricEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;
        
        return FutureBuilder<String?>(
          future: SecureStorage.getEmail(),
          builder: (context, emailSnapshot) {
            final hasEmail = emailSnapshot.data != null && emailSnapshot.data!.isNotEmpty;
            
            String statusText;
            Color statusColor;
            IconData statusIcon;
            
            if (!hasEmail) {
              statusText = "ℹ️ Please login with Email & Password first";
              statusColor = Colors.orange;
              statusIcon = Icons.info_outline;
            } else if (isEnabled) {
              statusText = "✅ Fingerprint login is ready";
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
            } else {
              statusText = "ℹ️ Enable fingerprint in Settings → Biometric Login first";
              statusColor = Colors.orange;
              statusIcon = Icons.fingerprint;
            }
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== REGISTER TAB ====================
  Widget _buildRegisterTab(AuthController auth) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildTextField(registerNameCtrl, "Full Name", Icons.person_outline,
              isRequired: true),
          const SizedBox(height: 12),
          _buildTextField(
              registerEmailCtrl, "Email Address", Icons.email_outlined,
              isRequired: true),
          const SizedBox(height: 12),
          _buildTextField(
              registerMobileCtrl, "Mobile Number", Icons.phone_android_outlined,
              isRequired: true),
          const SizedBox(height: 16),
          _buildPasswordField(
              registerPasswordCtrl, "Password", Icons.lock_outline,
              isRequired: true),
          const SizedBox(height: 12),
          _PasswordStrengthRow(
            hasUpper: hasUpper,
            hasLower: hasLower,
            hasNumber: hasNumber,
            hasSymbol: hasSymbol,
            isLongEnough: isLongEnough,
          ),
          const SizedBox(height: 24),
          _ModernButton(
            text: "Create Account",
            isLoading: auth.isLoading,
            onTap: () {
              final name = registerNameCtrl.text.trim();
              final email = registerEmailCtrl.text.trim();
              final mobile = registerMobileCtrl.text.trim();
              final password = registerPasswordCtrl.text.trim();

              if (name.isEmpty) {
                _safeShowMessage("Please enter your full name", isError: true);
                return;
              }
              if (email.isEmpty) {
                _safeShowMessage("Please enter your email address", isError: true);
                return;
              }
              if (mobile.isEmpty) {
                _safeShowMessage("Please enter your mobile number", isError: true);
                return;
              }
              if (password.isEmpty) {
                _safeShowMessage("Please enter a password", isError: true);
                return;
              }
              if (mobile.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
                _safeShowMessage("Mobile number must be 10 digits", isError: true);
                return;
              }
              if (!_isPasswordValid()) {
                _safeShowMessage(
                  "Password must contain:\n• Min 8 chars\n• 1 Uppercase\n• 1 Lowercase\n• 1 Number\n• 1 Special Character",
                  isError: true,
                );
                return;
              }

              auth.register({
                "name": name,
                "email": email,
                "mobile": mobile,
                "password": password,
              }, context);
            },
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isRequired = false,
  }) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withAlpha(128), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        filled: true,
        fillColor: Colors.white.withAlpha(26),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withAlpha(51)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildPasswordField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isRequired = false,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool obscure = (hint == "Password" && !showPassword) ||
            (hint != "Password" && !showRegisterPassword);
        return TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withAlpha(128), fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.white70, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.white70,
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  if (hint == "Password") {
                    showPassword = !showPassword;
                  } else {
                    showRegisterPassword = !showRegisterPassword;
                  }
                });
              },
            ),
            filled: true,
            fillColor: Colors.white.withAlpha(26),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withAlpha(51)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        );
      },
    );
  }
}

// ==================== PASSWORD STRENGTH WIDGET ====================
class _PasswordStrengthRow extends StatelessWidget {
  final bool hasUpper, hasLower, hasNumber, hasSymbol, isLongEnough;
  const _PasswordStrengthRow({
    required this.hasUpper,
    required this.hasLower,
    required this.hasNumber,
    required this.hasSymbol,
    required this.isLongEnough,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StrengthItem("At least 8 characters", isLongEnough),
          const SizedBox(height: 3),
          _StrengthItem("One uppercase letter", hasUpper),
          const SizedBox(height: 3),
          _StrengthItem("One lowercase letter", hasLower),
          const SizedBox(height: 3),
          _StrengthItem("One number", hasNumber),
          const SizedBox(height: 3),
          _StrengthItem("One special character", hasSymbol),
        ],
      ),
    );
  }
}

class _StrengthItem extends StatelessWidget {
  final String text;
  final bool valid;
  const _StrengthItem(this.text, this.valid);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          valid ? Icons.check_circle : Icons.cancel,
          color: valid ? Colors.greenAccent : Colors.redAccent,
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: valid ? Colors.greenAccent : Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ==================== MODERN BUTTON - FIXED ====================
class _ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;

  const _ModernButton({
    required this.text,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.white, Colors.white70],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF1E3A8A),
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}