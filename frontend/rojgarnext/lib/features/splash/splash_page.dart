// lib/features/splash/splash_page.dart - OPTIMIZED

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/routes/app_routes.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/widgets/platform_aware.dart';
import '../../features/user/data/user_service.dart';
import '../../features/user/AI/user_ai_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // ✅ Start initialization immediately
    _initializeApp();
  }

  // ✅ Optimized: Show splash for at least 800ms (fast but not too fast)
  Future<void> _initializeApp() async {
    if (!mounted) return;

    // ✅ Check token
    final token = await SecureStorage.getToken();

    // ✅ Wait at least 800ms for splash to show (good UX)
    final startTime = DateTime.now().millisecondsSinceEpoch;

    if (token == null || token.isEmpty) {
      // No token, go to home page
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
      if (elapsed < 800) {
        await Future.delayed(Duration(milliseconds: 800 - elapsed));
      }
      if (mounted) context.go(AppRoutes.home);
      return;
    }

    // ✅ Pre-load data in background
    _preloadDashboardData();

    // Get role
    final role = await SecureStorage.getRole();
    final roleLower = role?.toLowerCase() ?? "user";

    // ✅ Ensure minimum splash time
    final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
    if (elapsed < 800) {
      await Future.delayed(Duration(milliseconds: 800 - elapsed));
    }

    if (!mounted) return;

    // ✅ Navigate
    switch (roleLower) {
      case "superadmin":
        context.go(AppRoutes.superAdminDashboard);
        break;
      case "admin":
        context.go(AppRoutes.adminDashboard);
        break;
      case "customadmin":
        context.go(AppRoutes.customAdminDashboard);
        break;
      default:
        context.go(AppRoutes.userDashboard);
    }
  }

  // ✅ Background pre-loading
  Future<void> _preloadDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('dashboard_cache');

      if (cached != null) {
        if (kDebugMode) debugPrint("📦 Dashboard cache already exists");
        return;
      }

      if (kDebugMode) debugPrint("📦 Pre-loading dashboard data...");

      final results = await Future.wait([
        UserService.getProfileWithApplications(),
        UserAIService.getCareerAnalysis(),
        UserAIService.getJobRecommendations(limit: 5),
      ]);

      final profileWithApps = results[0];
      final careerAnalysis = results[1];
      final jobsData = results[2];

      List<dynamic> recommendations = [];
      final dataValue = jobsData['data'];
      if (dataValue is List) {
        recommendations = dataValue;
      } else if (dataValue is List<dynamic>) {
        recommendations = dataValue;
      }

      final profileData = profileWithApps['profile'] ?? {};
      final appliedCount = profileWithApps['total_applications'] ?? 0;
      final completion = careerAnalysis['profile_completion_percentage'] ??
          careerAnalysis['overall_score'] ?? 0;

      final cacheData = {
        'profile': profileData,
        'careerAnalysis': careerAnalysis,
        'jobRecommendations': recommendations,
        'appliedJobsCount': appliedCount,
        'profileCompletion': completion,
        'userName': await SecureStorage.getName() ?? 'User',
      };

      await prefs.setString('dashboard_cache', jsonEncode(cacheData));
      await prefs.setInt('dashboard_cache_time', DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode) debugPrint("✅ Dashboard data pre-loaded and cached!");
    } catch (e) {
      if (kDebugMode) debugPrint("⚠️ Pre-load failed: $e");
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformColor = PlatformAware.platformColor;
    final bool isWeb = PlatformAware.isWeb;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF1E3A8A), platformColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.work_outline,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "RojgarNext",
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Find Your Dream Job",
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  if (isWeb)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        "🌐 Web Platform",
                        style: TextStyle(fontSize: 14, color: Colors.white60),
                      ),
                    ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Loading...",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}