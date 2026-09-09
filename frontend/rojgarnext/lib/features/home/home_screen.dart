// lib/features/home/home_screen.dart
// ✅ AI-Powered Mobile Home Page with Center Login/Register Buttons
// ✅ Web/Desktop: Full home page with all features

import 'dart:math' as math; // ✅ ADD THIS IMPORT
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';
import 'package:dio/dio.dart';
import 'package:rojgarnext/core/widgets/platform_aware.dart';
import 'package:rojgarnext/core/utils/platform_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isBackendHealthy = false;
  bool _checkingBackend = true;
  String? _backendError;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _slideAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkBackendHealth() async {
    setState(() {
      _checkingBackend = true;
      _backendError = null;
    });

    try {
      final Dio dio = Dio(BaseOptions(
        baseUrl: 'http://localhost:8000',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));

      final Response response = await dio.get('/api/v1/');

      if (response.statusCode == 200) {
        _isBackendHealthy = true;
      } else {
        _isBackendHealthy = false;
        _backendError = "Backend returned status: ${response.statusCode}";
      }
    } on DioException catch (e) {
      _isBackendHealthy = false;

      if (e.type == DioExceptionType.connectionTimeout) {
        _backendError = "Connection timeout. Backend not responding.";
      } else if (e.type == DioExceptionType.connectionError) {
        _backendError =
            "Cannot connect to backend. Is it running on port 8000?";
      } else if (e.response?.statusCode == 404) {
        _backendError =
            "Backend API endpoint not found. Please check backend configuration.";
      } else {
        _backendError = "Backend error: ${e.message}";
      }
    } catch (e) {
      _isBackendHealthy = false;
      _backendError = "Unexpected error: $e";
    } finally {
      if (mounted) {
        setState(() => _checkingBackend = false);
      }
    }
  }

  void _navigateToLoginTab() {
    context.push('${AppRoutes.auth}?tab=0');
  }

  void _navigateToRegisterTab() {
    context.push('${AppRoutes.auth}?tab=1');
  }

  // ==================== BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    final bool isWeb = PlatformUtils.isWeb;

    if (isWeb) {
      return _buildWebHomePage();
    } else {
      return _buildMobileHomePage();
    }
  }

  // ==================== AI-POWERED MOBILE HOME PAGE ====================
  Widget _buildMobileHomePage() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFF0A0E27),
              Color(0xFF1A1A4E),
              Color(0xFF2D1B69),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ==================== BACKGROUND ANIMATED PARTICLES ====================
              Positioned.fill(
                child: _buildParticleBackground(),
              ),

              // ==================== MAIN CONTENT ====================
              Column(
                children: [
                  // ==================== TOP BAR ====================
                  _buildTopBar(),

                  // ==================== BACKEND STATUS ====================
                  if (!_isBackendHealthy && !_checkingBackend && _backendError != null)
                    _buildBackendStatus(),

                  if (_checkingBackend)
                    _buildCheckingStatus(),

                  // ==================== CENTER CONTENT ====================
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ==================== AI HERO ANIMATION ====================
                            _buildAIHeroSection(),

                            const SizedBox(height: 30),

                            // ==================== AI FEATURES BADGES ====================
                            _buildAIFeaturesBadges(),

                            const SizedBox(height: 30),

                            // ==================== TAGLINE ====================
                            _buildTagline(),

                            const SizedBox(height: 35),

                            // ==================== LOGIN & REGISTER BUTTONS SIDE BY SIDE ====================
                            _buildLoginRegisterButtons(),

                            const SizedBox(height: 20),

                            // ==================== AI POWERED BADGE ====================
                            _buildAIPoweredBadge(),
                          ],
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

  // ==================== AI HERO SECTION ====================
  Widget _buildAIHeroSection() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Column(
              children: [
                // ==================== AI GLOWING CIRCLE WITH ICON ====================
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.blue.shade300.withValues(alpha: 0.4),
                        Colors.purple.shade400.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      radius: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.2),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glowing ring
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          gradient: SweepGradient(
                            colors: [
                              Colors.blue.withValues(alpha: 0.5),
                              Colors.purple.withValues(alpha: 0.5),
                              Colors.cyan.withValues(alpha: 0.5),
                              Colors.blue.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF0A0E27),
                          ),
                        ),
                      ),
                      // AI Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.purple.shade400,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 45,
                          color: Colors.white,
                        ),
                      ),
                      // Pulsing dots
                      ...List.generate(12, (index) {
                        final angle = index * 30 * 3.14159 / 180;
                        final radius = 80.0;
                        return Positioned(
                          left: 80 + radius * 0.7 * math.cos(angle) - 4,
                          top: 80 + radius * 0.7 * math.sin(angle) - 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withValues(alpha: 0.6 + 0.4 * (index / 12)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ==================== AI TITLE ====================
                const Text(
                  "AI-Powered Career",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 6),

                // ==================== AI SUBTITLE ====================
                Text(
                  "Find Your Dream Job with",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 4),

                // ==================== AI HIGHLIGHT ====================
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400.withValues(alpha: 0.3),
                        Colors.purple.shade400.withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "RojgarNext AI",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan.shade300,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== AI FEATURES BADGES ====================
  Widget _buildAIFeaturesBadges() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _slideAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _slideAnimation.value)),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildAIBadge(Icons.auto_awesome, "AI Matching", Colors.blue),
                _buildAIBadge(Icons.analytics, "Smart Insights", Colors.purple),
                _buildAIBadge(Icons.trending_up, "Career Growth", Colors.cyan),
                _buildAIBadge(Icons.security, "Secure", Colors.green),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAGLINE ====================
  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Text(
              "🚀 Join 50,000+ professionals\nusing AI to find their dream jobs",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.6,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== LOGIN & REGISTER BUTTONS (SIDE BY SIDE) ====================
  Widget _buildLoginRegisterButtons() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // ==================== LOGIN BUTTON ====================
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _navigateToLoginTab,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.blue.withValues(alpha: 0.3),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // ==================== REGISTER BUTTON ====================
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _navigateToRegisterTab,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        side: const BorderSide(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        elevation: 4,
                        shadowColor: Colors.purple.withValues(alpha: 0.3),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.app_registration, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Register",
                            style: TextStyle(
                              fontSize: 15,
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
          ),
        );
      },
    );
  }

  // ==================== AI POWERED BADGE ====================
  Widget _buildAIPoweredBadge() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value * 0.7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.purple.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyan.shade300,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "⚡ AI-Powered • Smart Matching • Secure",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== TOP BAR ====================
  Widget _buildTopBar() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.white, Colors.white70],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.work_outline,
                    color: Color(0xFF1E3A8A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "RojgarNext",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "AI",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== BACKGROUND PARTICLES ====================
  Widget _buildParticleBackground() {
    return CustomPaint(
      painter: _ParticlePainter(),
      size: Size.infinite,
    );
  }

  // ==================== BACKEND STATUS WIDGETS ====================
  Widget _buildBackendStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _checkBackendHealth,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "⚠️ $_backendError",
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.refresh, size: 14, color: Colors.red.shade200),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckingStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Text(
              "Connecting...",
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== WEB HOME PAGE (Full) ====================
  Widget _buildWebHomePage() {
    final Size size = MediaQuery.of(context).size;
    final bool isMobile = size.width <= 600;
    final bool isTablet = size.width > 600 && size.width <= 900;
    final bool isDesktop = size.width > 900;

    final double heroFontSize = isDesktop ? 52 : (isTablet ? 44 : 36);
    final double subtitleFontSize = isDesktop ? 18 : 16;
    final double descriptionFontSize = isDesktop ? 16 : 14;

    final platformColor = PlatformAware.platformColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E3A8A),
              const Color(0xFF3B82F6),
              platformColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 60 : (isTablet ? 40 : 20),
                        vertical: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.white, Colors.white70],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.work_outline,
                                  color: Color(0xFF1E3A8A),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Text(
                                "RojgarNext",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (kIsWeb)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    "🌐 Web",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (isDesktop || isTablet)
                            Row(
                              children: [
                                _buildWebGlassButton(
                                  text: "Login",
                                  icon: Icons.login,
                                  isOutlined: true,
                                  onTap: _navigateToLoginTab,
                                ),
                                const SizedBox(width: 12),
                                _buildWebGlassButton(
                                  text: "Register",
                                  icon: Icons.app_registration,
                                  isOutlined: false,
                                  onTap: _navigateToRegisterTab,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              if (!_isBackendHealthy && !_checkingBackend && _backendError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: _checkBackendHealth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "⚠️ $_backendError",
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.refresh, size: 14, color: Colors.red.shade200),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_checkingBackend)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Connecting...",
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 80 : (isTablet ? 50 : 24),
                          vertical: isDesktop ? 60 : 40,
                        ),
                        child: Column(
                          children: [
                            TweenAnimationBuilder<double>(
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
                              child: Text(
                                "Find Your Dream Job",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: heroFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "AI-Powered Job Portal with Smart Matching",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Thousands of jobs from top companies waiting for you",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: descriptionFontSize,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 48),

                            if (!isMobile)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildWebGradientButton(
                                    text: "Get Started",
                                    icon: Icons.arrow_forward,
                                    onTap: _navigateToRegisterTab,
                                    width: 200,
                                  ),
                                  const SizedBox(width: 20),
                                  OutlinedButton.icon(
                                    onPressed: _navigateToLoginTab,
                                    icon: const Icon(Icons.login),
                                    label: const Text("Login"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildWebStatCard("10K+", "Active Jobs", Icons.work, Colors.blue),
                            _buildWebStatCard("5K+", "Companies", Icons.business, Colors.green),
                            _buildWebStatCard("50K+", "Users", Icons.people, Colors.purple),
                            _buildWebStatCard("1K+", "Placements", Icons.celebration, Colors.orange),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          children: [
                            const Text(
                              "Powered by Advanced AI",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Revolutionary features to accelerate your career",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 48),
                            Wrap(
                              spacing: 24,
                              runSpacing: 24,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildWebAIFeatureCard(
                                  icon: Icons.auto_awesome,
                                  title: "AI Career Analysis",
                                  description: "Get personalized career insights",
                                  color: Colors.purple,
                                  gradientColors: [Colors.purple, Colors.pink],
                                ),
                                _buildWebAIFeatureCard(
                                  icon: Icons.search,
                                  title: "Smart Job Matching",
                                  description: "AI-powered job recommendations",
                                  color: Colors.blue,
                                  gradientColors: [Colors.blue, Colors.cyan],
                                ),
                                _buildWebAIFeatureCard(
                                  icon: Icons.assignment_turned_in,
                                  title: "Resume Scoring",
                                  description: "AI evaluates your resume",
                                  color: Colors.teal,
                                  gradientColors: [Colors.teal, Colors.green],
                                ),
                                _buildWebAIFeatureCard(
                                  icon: Icons.insights,
                                  title: "Career Growth",
                                  description: "Predict your career trajectory",
                                  color: Colors.orange,
                                  gradientColors: [Colors.orange, Colors.red],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          children: [
                            const Text(
                              "How RojgarNext Works",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Your journey to the perfect job in 4 simple steps",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 48),
                            Wrap(
                              spacing: 30,
                              runSpacing: 30,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildWebStepCard("1", "Create Profile", Icons.person_add),
                                _buildWebStepCard("2", "AI Analysis", Icons.auto_awesome),
                                _buildWebStepCard("3", "Smart Matching", Icons.sync),
                                _buildWebStepCard("4", "Apply & Grow", Icons.trending_up),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.25),
                              Colors.white.withValues(alpha: 0.13),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.format_quote, size: 50, color: Colors.white70),
                            const SizedBox(height: 20),
                            const Text(
                              "RojgarNext helped me find my dream job in just 2 weeks!",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: Colors.white, height: 1.5),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "- Rahul Sharma",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Software Engineer at Google",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                (index) => const Icon(Icons.star, color: Colors.amber, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withValues(alpha: 0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Ready to Start Your Career Journey?",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Join thousands of successful job seekers",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            _buildWebGradientButton(
                              text: "Get Started Now",
                              icon: Icons.rocket_launch,
                              onTap: _navigateToRegisterTab,
                              width: 250,
                              fontSize: 16,
                            ),
                          ],
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.only(top: 40),
                        padding: const EdgeInsets.all(30),
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.26),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.work_outline, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "RojgarNext",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (kIsWeb)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      "🌐 Web App",
                                      style: TextStyle(fontSize: 10, color: Colors.white70),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 20,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildWebFooterLink("About Us"),
                                _buildWebFooterLink("Contact"),
                                _buildWebFooterLink("Privacy Policy"),
                                _buildWebFooterLink("Terms of Service"),
                                _buildWebFooterLink("Help Center"),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "© 2025 RojgarNext. All rights reserved.",
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Find Your Dream Job with AI-Powered Career Guidance",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== WEB UI COMPONENTS ====================
  Widget _buildWebGlassButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: isOutlined ? null : const LinearGradient(
          colors: [Colors.white, Colors.white70],
        ),
        border: isOutlined ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: isOutlined ? Colors.white : const Color(0xFF1E3A8A)),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isOutlined ? Colors.white : const Color(0xFF1E3A8A),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : Colors.white,
          foregroundColor: isOutlined ? Colors.white : const Color(0xFF1E3A8A),
          elevation: isOutlined ? 0 : 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  Widget _buildWebGradientButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    double width = double.infinity,
    double fontSize = 15,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Colors.white70],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
        label: Text(
          text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  Widget _buildWebStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.26),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWebAIFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStepCard(String step, String title, IconData icon) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Icon(icon, size: 32, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFooterLink(String text) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

// ==================== PARTICLE BACKGROUND PAINTER ====================
class _ParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2 + 1;
      final opacity = random.nextDouble() * 0.3 + 0.1;
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}