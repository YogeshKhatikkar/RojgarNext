// lib/features/jobs/presentation/screens/job_detail_screen.dart
// ✅ AI‑BASED MODERN DESIGN – Light gradient, glass cards, brand colors
// ✅ ULTRA‑FAST – Cached profile, instant load, background refresh
// ✅ AI LOADING ANIMATION with animated auto_awesome icon
// ✅ FULLY FUNCTIONAL – All original logic preserved
// ✅ FIXED: Added missing _sectionHeader method
// ✅ FIXED: User category properly loaded and passed to payment screen
// ✅ FIXED: Disability check FIRST, then category (PWD priority)
// ✅ NEW: Service Charge + GST added to application fees
// ✅ NEW: Total fees = Application Fees + GST (18%) + Service Charge (₹50)
// ✅ NEW: Payment screen receives total amount with full breakdown
// ✅ NEW: PDF links, images, and ALL file types open in FileViewerScreen
// ✅ NEW: Enhanced file type detection for external URLs and Google Drive

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/widgets/file_viewer_screen.dart';
import 'package:rojgarnext/features/payment/presentation/screens/payment_screen.dart';
import 'package:rojgarnext/features/payment/presentation/payment.dart'
    show PaymentType;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// AI SERVICE
// ============================================================
class AIJobDetailService {
  static double calculateMatchScore(
      Map<String, dynamic> job, Map<String, dynamic> userProfile) {
    if (userProfile.isEmpty) return 65 + (job['_id'].hashCode % 20);
    double score = 50;
    final userSkills = userProfile['skills'] ?? [];
    final jobSkills = job['required_skills'] ?? [];
    if (userSkills.isNotEmpty && jobSkills.isNotEmpty) {
      final matchCount = userSkills
          .where((s) => jobSkills.any((js) =>
              js['name']?.toString().toLowerCase() ==
              s.toString().toLowerCase()))
          .length;
      score += (matchCount / jobSkills.length) * 20;
    }
    final userExp = userProfile['total_experience_years'] ?? 0;
    final jobExpMin = job['experience_min_years'] ?? 0;
    final jobExpMax = job['experience_max_years'] ?? 99;
    if (userExp >= jobExpMin && userExp <= jobExpMax) score += 10;
    final userEdu =
        userProfile['highest_education']?.toString().toLowerCase() ?? '';
    final jobEdu =
        job['required_qualification']?.toString().toLowerCase() ?? '';
    if (userEdu.isNotEmpty &&
        jobEdu.isNotEmpty &&
        (jobEdu.contains(userEdu) || userEdu.contains(jobEdu))) {
      score += 10;
    }
    return score.clamp(30, 98).toDouble();
  }

  static List<String> getInsights(Map<String, dynamic> job) {
    List<String> insights = [];
    if (job['salary_min'] != null && job['salary_max'] != null) {
      final avg = (job['salary_min'] + job['salary_max']) ~/ 2;
      insights.add("💰 ₹${(avg / 100000).toStringAsFixed(1)}L avg salary");
    }
    if (job['experience_min_years'] != null &&
        job['experience_max_years'] != null) {
      insights.add(
          "🎓 ${job['experience_min_years']}-${job['experience_max_years']} yrs exp");
    }
    if (job['total_posts'] != null) {
      insights.add("👥 ${job['total_posts']} vacancies");
    }
    if (job['required_skills'] != null &&
        (job['required_skills'] as List).isNotEmpty) {
      insights.add("🛠️ ${(job['required_skills'] as List).length} skills");
    }
    if (job['benefits'] != null && (job['benefits'] as List).isNotEmpty) {
      insights.add("🎁 ${(job['benefits'] as List).length} benefits");
    }
    if (job['is_fully_remote'] == true) {
      insights.add("🏠 Remote");
    } else if (job['is_hybrid'] == true) {
      insights.add("🔄 Hybrid");
    }
    return insights;
  }
}

// ============================================================
// FEE BREAKDOWN MODEL
// ============================================================
class FeeBreakdown {
  final int applicationFee;
  final int gstAmount;
  final int serviceCharge;
  final int totalFee;

  FeeBreakdown({
    required this.applicationFee,
    required this.gstAmount,
    required this.serviceCharge,
    required this.totalFee,
  });

  /// Calculate fee breakdown with 18% GST and fixed service charge
  factory FeeBreakdown.calculate({
    required int applicationFee,
    double gstPercent = 18.0,
    int serviceCharge = 50,
  }) {
    final int gstAmount = ((applicationFee * gstPercent) / 100).round();
    final int totalFee = applicationFee + gstAmount + serviceCharge;
    return FeeBreakdown(
      applicationFee: applicationFee,
      gstAmount: gstAmount,
      serviceCharge: serviceCharge,
      totalFee: totalFee,
    );
  }

  @override
  String toString() {
    return 'FeeBreakdown(app: ₹$applicationFee, gst: ₹$gstAmount, '
        'service: ₹$serviceCharge, total: ₹$totalFee)';
  }
}

// ============================================================
// FILE TYPE DETECTOR (Local helper for job detail screen)
// ============================================================
class _JobFileTypeDetector {
  static const Set<String> imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'wbmp', 'ico', 'tiff', 'tif', 'svg',
  };
  static const Set<String> pdfExtensions = {'pdf'};

  static String getExtension(String urlOrName) {
    if (urlOrName.isEmpty) return '';
    try {
      final clean = urlOrName.split('?').first.split('#').first;
      final segments = clean.split('/');
      final last = segments.isNotEmpty ? segments.last : clean;
      if (last.contains('.')) {
        return last.split('.').last.toLowerCase().trim();
      }
    } catch (e) {
      debugPrint('Extension parse error: $e');
    }
    return '';
  }

  static bool isPdf(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();

    // 1. Check explicit type
    if (explicitType != null) {
      final t = explicitType.toLowerCase();
      if (t == 'pdf' || t.contains('pdf')) return true;
    }

    // 2. Check file extension
    final ext = getExtension(url);
    if (pdfExtensions.contains(ext)) return true;

    // 3. Check URL patterns
    if (lower.contains('/raw/upload/')) return true;
    if (lower.contains('/raw/authenticated/')) return true;
    if (lower.contains('.pdf')) return true;
    if (lower.contains('application/pdf')) return true;
    if (lower.contains('/pdf/')) return true;
    if (lower.contains('type=pdf')) return true;
    if (lower.contains('format=pdf')) return true;

    // 4. Google Docs PDF export
    if (lower.contains('docs.google.com') && lower.contains('export=pdf')) {
      return true;
    }

    return false;
  }

  static bool isImage(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();

    // 1. Check explicit type
    if (explicitType != null) {
      final t = explicitType.toLowerCase();
      if (t == 'image' || t.contains('image')) return true;
    }

    // 2. Check file extension
    final ext = getExtension(url);
    if (imageExtensions.contains(ext)) return true;

    // 3. Don't classify as image if it's PDF
    if (isPdf(url, explicitType: explicitType)) return false;

    // 4. Cloudinary image patterns
    if (lower.contains('cloudinary.com') &&
        (lower.contains('/image/upload/') ||
         lower.contains('/image/authenticated/'))) {
      return true;
    }

    // 5. Common image URL patterns
    if (lower.contains('image/')) return true;
    if (lower.contains('img/')) return true;
    if (lower.contains('photo/')) return true;
    if (lower.contains('picture/')) return true;

    return false;
  }

  static bool isGoogleDrive(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('drive.google.com') ||
        lower.contains('docs.google.com');
  }

  /// ✅ Get best file type string for FileViewerScreen
  static String detectFileType(String url, {String? explicitType}) {
    if (url.isEmpty) return 'unknown';

    if (isPdf(url, explicitType: explicitType)) return 'pdf';
    if (isImage(url, explicitType: explicitType)) return 'image';
    if (isGoogleDrive(url)) return 'gdrive';

    final ext = getExtension(url);
    if (ext.isNotEmpty) {
      // Return the extension as the type for better handling
      switch (ext) {
        case 'doc':
        case 'docx':
          return 'word';
        case 'xls':
        case 'xlsx':
          return 'excel';
        case 'ppt':
        case 'pptx':
          return 'powerpoint';
        case 'txt':
        case 'log':
        case 'md':
        case 'json':
        case 'xml':
          return 'text';
        case 'mp4':
        case 'avi':
        case 'mkv':
        case 'mov':
          return 'video';
        case 'mp3':
        case 'wav':
        case 'aac':
          return 'audio';
        default:
          return ext;
      }
    }

    return 'unknown';
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================
class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onBack;
  final VoidCallback? onApplicationSubmitted;

  const JobDetailScreen({
    super.key,
    required this.job,
    this.onBack,
    this.onApplicationSubmitted,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // STATE VARIABLES
  // ============================================================
  bool _isApplyingOnWebsite = false;
  bool _isApplyingWithUs = false;
  bool _isSaved = false;
  bool _hasApplied = false;
  bool _isCheckingApplied = true;
  bool _isPaymentProcessing = false;

  String? _officialNotificationUrl;
  String? _advertisementUrl;
  String? _advertisementDownloadUrl;
  bool _hasOfficialNotification = false;
  bool _hasAdvertisement = false;
  bool _isOfficialNotificationPdf = false;
  bool _isAdvertisementPdf = false;
  bool _isImageFile = false;
  bool _isGoogleDriveLink = false;
  bool _isPrivateCloudinaryFile = false;

  // ✅ User category - properly loaded from profile
  String? _userCategory;
  bool _isLoadingCategory = true;
  String? _userCategoryDisplayName;

  // ✅ NEW: Disability status - checked FIRST before category
  bool _isDisabled = false;
  String? _disabilityPercentage;
  String? _disabilityCategory;
  bool _isLoadingDisability = true;

  // AI
  double _matchScore = 0.0;
  List<String> _insights = [];
  Map<String, dynamic> _userProfile = {};

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ============================================================
  // FEE CONSTANTS
  // ============================================================
  static const double GST_PERCENT = 18.0;
  static const int SERVICE_CHARGE = 50;

  // ============================================================
  // LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _loadUserProfile();
    _checkIfAlreadyApplied();
    _checkIfSaved();
    _loadNotificationData();
    _loadUserProfileData(); // ✅ Loads BOTH disability AND category

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ============================================================
  // ✅ LOAD USER PROFILE - Disability + Category
  // ============================================================
  Future<void> _loadUserProfileData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCategory = true;
      _isLoadingDisability = true;
    });

    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        // Not logged in - defaults
        if (mounted) {
          setState(() {
            _isDisabled = false;
            _userCategory = 'general/ur';
            _userCategoryDisplayName = 'General/UR';
            _isLoadingCategory = false;
            _isLoadingDisability = false;
          });
        }
        debugPrint("👤 No token - Default: Not Disabled, General/UR");
        return;
      }

      // ✅ Fetch full profile
      final response = await DioClient.dio.get('/user/full-profile');

      if (!mounted) return;

      Map<String, dynamic> profile = {};

      if (response.data is Map) {
        if (response.data.containsKey('data') && response.data['data'] is Map) {
          profile = response.data['data'] as Map<String, dynamic>;
        } else {
          profile = response.data as Map<String, dynamic>;
        }
      }

      // ============================================================
      // ✅ STEP 1: CHECK DISABILITY FIRST (PRIORITY)
      // ============================================================
      bool isDisabled = false;
      String? disabilityPercentage;
      String? disabilityCategory;

      // Check nested disability object
      final disabilityObj = profile['disability'] as Map<String, dynamic>?;
      if (disabilityObj != null) {
        final isDisabledValue = disabilityObj['is_disabled'];
        if (isDisabledValue is bool) {
          isDisabled = isDisabledValue;
        } else if (isDisabledValue is String) {
          isDisabled = isDisabledValue.toLowerCase() == 'true' ||
              isDisabledValue == 'yes';
        } else if (isDisabledValue is int) {
          isDisabled = isDisabledValue == 1;
        }

        disabilityPercentage =
            disabilityObj['disability_percentage']?.toString();
        disabilityCategory = disabilityObj['disability_category']?.toString();
      }

      // Fallback: check top-level fields (legacy data)
      if (!isDisabled) {
        final isDisableTop = profile['is_disable'];
        if (isDisableTop is bool) {
          isDisabled = isDisableTop;
        } else if (isDisableTop is String) {
          isDisabled =
              isDisableTop.toLowerCase() == 'true' || isDisableTop == 'yes';
        } else if (isDisableTop is int) {
          isDisabled = isDisableTop == 1;
        }

        if (disabilityPercentage == null) {
          disabilityPercentage = profile['disability_percentage']?.toString();
        }
        if (disabilityCategory == null) {
          disabilityCategory = profile['disability_category']?.toString();
        }
      }

      // Fallback: check physically_challenged
      if (!isDisabled) {
        final physicallyChallenged =
            profile['physically_challenged']?.toString().toLowerCase();
        if (physicallyChallenged == 'yes' || physicallyChallenged == 'true') {
          isDisabled = true;
        }
      }

      debugPrint("♿ Disability Status: $isDisabled");
      debugPrint("   Percentage: $disabilityPercentage");
      debugPrint("   Category: $disabilityCategory");

      // ============================================================
      // ✅ STEP 2: GET CATEGORY (only matters if NOT disabled)
      // ============================================================
      String? category = profile['category']?.toString();

      if (category == null || category.isEmpty) {
        final basicDetails = profile['basic_details'] as Map<String, dynamic>?;
        if (basicDetails != null) {
          category = basicDetails['category']?.toString();
        }
      }

      if (category == null || category.isEmpty) {
        final personalInfo = profile['personal_info'] as Map<String, dynamic>?;
        if (personalInfo != null) {
          category = personalInfo['category']?.toString();
        }
      }

      debugPrint("📋 Raw user category: '$category'");

      // Normalize category
      String normalizedCategory = _normalizeCategory(category);
      String displayName = _getCategoryDisplayName(category);

      if (mounted) {
        setState(() {
          _isDisabled = isDisabled;
          _disabilityPercentage = disabilityPercentage;
          _disabilityCategory = disabilityCategory;
          _userCategory = normalizedCategory;
          _userCategoryDisplayName = displayName;
          _isLoadingCategory = false;
          _isLoadingDisability = false;
        });
      }

      // ✅ Log final effective payment category
      debugPrint("=" * 60);
      debugPrint("💳 EFFECTIVE PAYMENT CATEGORY:");
      if (_isDisabled) {
        debugPrint("   ♿ PWD (Disabled User)");
        debugPrint("   → Will use PWD fee from job");
      } else {
        debugPrint("   👤 $_userCategoryDisplayName ($normalizedCategory)");
        debugPrint("   → Will use category fee from job");
      }
      debugPrint("=" * 60);
    } catch (e) {
      debugPrint("❌ Error loading user profile data: $e");
      if (mounted) {
        setState(() {
          _isDisabled = false;
          _userCategory = 'general/ur';
          _userCategoryDisplayName = 'General/UR';
          _isLoadingCategory = false;
          _isLoadingDisability = false;
        });
      }
    }
  }

  // ✅ Normalize category to match fee keys in job data
  String _normalizeCategory(String? category) {
    if (category == null || category.isEmpty) {
      return 'general/ur';
    }

    final lowerCategory = category.toLowerCase().trim();

    if (lowerCategory.contains('general') ||
        lowerCategory == 'ur' ||
        lowerCategory == 'unreserved') {
      return 'general/ur';
    }
    if (lowerCategory.contains('obc')) {
      return 'obc';
    }
    if (lowerCategory.contains('sc') && !lowerCategory.contains('scheduled')) {
      return 'sc';
    }
    if (lowerCategory.contains('st') && !lowerCategory.contains('scheduled')) {
      return 'st';
    }
    if (lowerCategory.contains('ews')) {
      return 'ews';
    }
    if (lowerCategory.contains('pwd') ||
        lowerCategory.contains('ph') ||
        lowerCategory.contains('disabled')) {
      return 'pwd';
    }
    if (lowerCategory.contains('female') || lowerCategory.contains('woman')) {
      return 'female';
    }
    if (lowerCategory.contains('esm') ||
        lowerCategory.contains('ex-serviceman')) {
      return 'esm';
    }

    return 'general/ur';
  }

  // ✅ Get display name for category
  String _getCategoryDisplayName(String? category) {
    if (category == null || category.isEmpty) {
      return 'General/UR';
    }

    final lowerCategory = category.toLowerCase().trim();

    if (lowerCategory.contains('general') || lowerCategory == 'ur') {
      return 'General/UR';
    }
    if (lowerCategory.contains('obc')) {
      return 'OBC';
    }
    if (lowerCategory.contains('sc')) {
      return 'SC';
    }
    if (lowerCategory.contains('st')) {
      return 'ST';
    }
    if (lowerCategory.contains('ews')) {
      return 'EWS';
    }
    if (lowerCategory.contains('pwd') || lowerCategory.contains('ph')) {
      return 'PWD';
    }
    if (lowerCategory.contains('female')) {
      return 'Female';
    }
    if (lowerCategory.contains('esm')) {
      return 'ESM';
    }

    return category;
  }

  // ============================================================
  // DATA LOADING
  // ============================================================
  Future<void> _loadUserProfile() async {
    try {
      final token = await SecureStorage.getToken();
      if (token != null) {
        final response = await DioClient.dio.get('/user/full-profile');
        if (response.data is Map) {
          final data = response.data;
          if (data.containsKey('data') && data['data'] is Map) {
            _userProfile = data['data'];
            _matchScore = AIJobDetailService.calculateMatchScore(
                widget.job, _userProfile);
            _insights = AIJobDetailService.getInsights(widget.job);
            if (mounted) setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile for AI: $e');
    }
  }

  void _loadNotificationData() {
    final officialUrl = widget.job['official_notification_url'];
    if (officialUrl != null && officialUrl.toString().isNotEmpty) {
      _officialNotificationUrl = officialUrl.toString();
      _hasOfficialNotification = true;
      _isOfficialNotificationPdf = _JobFileTypeDetector.isPdf(
        _officialNotificationUrl!,
        explicitType: 'pdf',
      );
    }

    final advUrl = widget.job['advertisement_url'];
    if (advUrl != null && advUrl.toString().isNotEmpty) {
      _advertisementUrl = advUrl.toString();
      _hasAdvertisement = true;
      _advertisementDownloadUrl = widget.job['advertisement_download_url'];
      _isPrivateCloudinaryFile = widget.job['advertisement_is_public'] == false &&
          _advertisementUrl!.contains('cloudinary.com');

      final urlLower = _advertisementUrl!.toLowerCase();
      _isAdvertisementPdf = _JobFileTypeDetector.isPdf(_advertisementUrl!);
      _isImageFile = _JobFileTypeDetector.isImage(_advertisementUrl!);
      _isGoogleDriveLink = _JobFileTypeDetector.isGoogleDrive(_advertisementUrl!);
    }
  }

  Future<void> _checkIfAlreadyApplied() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _hasApplied = false;
          _isCheckingApplied = false;
        });
      }
      return;
    }
    try {
      final response = await DioClient.dio.get('/jobs/my-applications');
      if (!mounted) return;
      final applications = response.data['applications'] ?? [];
      final jobId = widget.job['_id'].toString();
      final alreadyApplied = applications.any((app) {
        final appJobId = app['job_id']?.toString() ?? '';
        return appJobId == jobId;
      });
      if (mounted) {
        setState(() {
          _hasApplied = alreadyApplied;
          _isCheckingApplied = false;
        });
      }
    } catch (e) {
      debugPrint('Check applied error: $e');
      if (mounted) {
        setState(() {
          _hasApplied = false;
          _isCheckingApplied = false;
        });
      }
    }
  }

  Future<void> _checkIfSaved() async {
    final token = await SecureStorage.getToken();
    if (token == null) return;
    try {
      final response = await DioClient.dio.get('/jobs/my-applications');
      if (mounted) {
        final savedApps = response.data['applications'] ?? [];
        setState(() {
          _isSaved = savedApps.any((app) => app['job_id'] == widget.job['_id']);
        });
      }
    } catch (e) {
      debugPrint('Check saved error: $e');
    }
  }

  // ============================================================
  // ✅ FEE HELPERS - Disability FIRST, then Category
  // ============================================================

  /// ✅ MAIN METHOD: Get the effective category key for payment
  /// Priority: 1) Disabled → 'pwd' 2) User category → normalized
  String _getEffectivePaymentCategory() {
    // ✅ RULE 1: If user is disabled, ALWAYS use PWD fee
    if (_isDisabled) {
      debugPrint("♿ User is DISABLED → Using 'pwd' category");
      return 'pwd';
    }

    // ✅ RULE 2: Otherwise, use user's category
    final category = _userCategory ?? 'general/ur';
    debugPrint("👤 User NOT disabled → Using '$category' category");
    return category;
  }

  /// ✅ Get display name for the effective payment category
  String _getEffectivePaymentCategoryDisplay() {
    if (_isDisabled) {
      return 'PWD (Disabled)';
    }
    return _userCategoryDisplayName ?? 'General/UR';
  }

  /// ✅ Check if user is paying as PWD (for badge display)
  bool _isPayingAsPwd() {
    return _isDisabled;
  }

  /// ✅ Get the fee for the effective category (PWD if disabled, else user category)
  int _getCategoryFee(Map<String, dynamic> fees) {
    if (fees == null || fees.isEmpty) return 0;

    // ✅ CRITICAL: Get effective category (PWD if disabled)
    final effectiveCategory = _getEffectivePaymentCategory();

    debugPrint("=" * 60);
    debugPrint("💰 FEE CALCULATION");
    debugPrint("   User Disabled: $_isDisabled");
    debugPrint("   User Category: $_userCategory ($_userCategoryDisplayName)");
    debugPrint("   Effective Category: $effectiveCategory");
    debugPrint("   Available Fee Keys: ${fees.keys.toList()}");
    debugPrint("=" * 60);

    int? fee;

    // ✅ Try exact match with effective category
    if (fees.containsKey(effectiveCategory)) {
      final value = fees[effectiveCategory];
      if (value is int) {
        fee = value;
      } else if (value is String) {
        fee = int.tryParse(value);
      }
      debugPrint("   ✅ Exact match '$effectiveCategory': ₹$fee");
    }

    // ✅ If no exact match, try alternative keys
    if (fee == null || fee <= 0) {
      final alternativeKeys = _getAlternativeFeeKeys(effectiveCategory);
      debugPrint("   Trying alternatives: $alternativeKeys");

      for (final altKey in alternativeKeys) {
        if (fees.containsKey(altKey)) {
          final value = fees[altKey];
          if (value is int) {
            fee = value;
          } else if (value is String) {
            fee = int.tryParse(value);
          }
          debugPrint("   ✅ Alternative '$altKey' match: ₹$fee");
          if (fee != null && fee > 0) break;
        }
      }
    }

    // ✅ If disabled but no PWD fee found, fallback to user's category fee
    if ((fee == null || fee <= 0) && _isDisabled) {
      final fallbackCategory = _userCategory ?? 'general/ur';
      debugPrint(
          "   ⚠️ No PWD fee found, falling back to user category: $fallbackCategory");

      if (fees.containsKey(fallbackCategory)) {
        final value = fees[fallbackCategory];
        if (value is int) {
          fee = value;
        } else if (value is String) {
          fee = int.tryParse(value);
        }
      }

      // Try alternatives for fallback category
      if (fee == null || fee <= 0) {
        final altKeys = _getAlternativeFeeKeys(fallbackCategory);
        for (final altKey in altKeys) {
          if (fees.containsKey(altKey)) {
            final value = fees[altKey];
            if (value is int) {
              fee = value;
            } else if (value is String) {
              fee = int.tryParse(value);
            }
            if (fee != null && fee > 0) break;
          }
        }
      }
    }

    // ✅ Final fallback to general/ur
    if (fee == null || fee <= 0) {
      final generalValue = fees['general/ur'] ??
          fees['general'] ??
          fees['general_ur'] ??
          fees['ur'];
      if (generalValue is int) {
        fee = generalValue;
      } else if (generalValue is String) {
        fee = int.tryParse(generalValue);
      }
      debugPrint("   🔄 Final fallback (general/ur): ₹$fee");
    }

    final finalFee = (fee != null && fee > 0) ? fee : 0;
    debugPrint("=" * 60);
    debugPrint("   💰 FINAL FEE: ₹$finalFee for category: $effectiveCategory");
    debugPrint("=" * 60);

    return finalFee;
  }

  // ✅ Get alternative fee keys for a category
  List<String> _getAlternativeFeeKeys(String category) {
    switch (category.toLowerCase()) {
      case 'general/ur':
        return ['general', 'ur', 'general_ur', 'unreserved', 'open'];
      case 'obc':
        return ['obc', 'other_backward', 'other_backward_class', 'obc_ncl'];
      case 'sc':
        return ['sc', 'scheduled_caste', 'scheduled caste', 'scheduledcaste'];
      case 'st':
        return ['st', 'scheduled_tribe', 'scheduled tribe', 'scheduledtribe'];
      case 'ews':
        return [
          'ews',
          'economically_weaker',
          'economically_weaker_section',
          'economicallyweakersection'
        ];
      case 'pwd':
        return [
          'pwd',
          'ph',
          'physically_handicapped',
          'disabled',
          'divyangjan',
          'physically_challenged',
          'handicapped',
          'differently_abled',
          'person_with_disability',
          'disability'
        ];
      case 'female':
        return ['female', 'women', 'woman', 'girl'];
      case 'esm':
        return [
          'esm',
          'ex_serviceman',
          'ex-serviceman',
          'exserviceman',
          'ex_service'
        ];
      default:
        return ['general/ur', 'general', 'ur'];
    }
  }

  /// ✅ Get user category for display (with PWD priority)
  String _getUserCategoryForDisplay() {
    if (_isDisabled) {
      if (_disabilityPercentage != null && _disabilityPercentage!.isNotEmpty) {
        return 'PWD ($_disabilityPercentage%)';
      }
      if (_disabilityCategory != null && _disabilityCategory!.isNotEmpty) {
        return 'PWD ($_disabilityCategory)';
      }
      return 'PWD (Disabled)';
    }
    return _userCategoryDisplayName ?? 'General/UR';
  }

  // ============================================================
  // ✅ NEW: FEE BREAKDOWN CALCULATION
  // ============================================================
  FeeBreakdown _calculateFeeBreakdown() {
    final hasFees = _hasApplicationFees();
    final fees = _getApplicationFees();
    final applicationFee = hasFees ? _getCategoryFee(fees) : 0;

    // ✅ If no application fee exists, total is just service charge
    if (applicationFee <= 0) {
      return FeeBreakdown(
        applicationFee: 0,
        gstAmount: 0,
        serviceCharge: SERVICE_CHARGE,
        totalFee: SERVICE_CHARGE,
      );
    }

    return FeeBreakdown.calculate(
      applicationFee: applicationFee,
      gstPercent: GST_PERCENT,
      serviceCharge: SERVICE_CHARGE,
    );
  }

  // ============================================================
  // DATE FORMATTERS
  // ============================================================
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatPostedDate() {
    final postDate = widget.job['post_date'];
    if (postDate != null && postDate.toString().isNotEmpty) {
      return _formatDate(postDate);
    }
    final createdAt = widget.job['created_at'];
    if (createdAt != null && createdAt.toString().isNotEmpty) {
      return _formatDate(createdAt);
    }
    return 'Recently';
  }

  // ============================================================
  // GETTER METHODS
  // ============================================================
  String _getJobLocation() {
    final jobLoc = widget.job['job_location'];
    if (jobLoc != null && jobLoc['location_name'] != null) {
      return jobLoc['location_name'].toString();
    }
    if (widget.job['location'] != null &&
        widget.job['location'].toString().isNotEmpty) {
      return widget.job['location'].toString();
    }
    return 'Not specified';
  }

  String _getSalaryDisplay() {
    final minSal = widget.job['salary_min'];
    final maxSal = widget.job['salary_max'];
    if (minSal != null && maxSal != null) {
      return "₹${minSal ~/ 100000}-${maxSal ~/ 100000} LPA";
    }
    if (minSal != null) {
      return "From ₹${minSal ~/ 100000} LPA";
    }
    if (maxSal != null) {
      return "Up to ₹${maxSal ~/ 100000} LPA";
    }
    return 'Not disclosed';
  }

  String _getLastDate() {
    final lastDate = widget.job['last_date'];
    if (lastDate != null && lastDate.toString().isNotEmpty) {
      return _formatDate(lastDate);
    }
    return '';
  }

  String _getApplicationStartDate() {
    if (widget.job['application_start_date'] != null &&
        widget.job['application_start_date'].toString().isNotEmpty) {
      return _formatDate(widget.job['application_start_date']);
    }
    return '';
  }

  String _getApplicationEndDate() {
    if (widget.job['application_end_date'] != null &&
        widget.job['application_end_date'].toString().isNotEmpty) {
      return _formatDate(widget.job['application_end_date']);
    }
    return '';
  }

  String _getQualificationDisplay() {
    final reqQual = widget.job['required_qualification'];
    if (reqQual != null && reqQual.toString().isNotEmpty) {
      return reqQual.toString();
    }
    final qualification = widget.job['qualification'];
    if (qualification != null && qualification.toString().isNotEmpty) {
      return qualification.toString();
    }
    return 'Any Graduate';
  }

  String _getExperience() {
    final minExp = widget.job['experience_min_years'];
    final maxExp = widget.job['experience_max_years'];
    if (minExp != null && maxExp != null) {
      return '$minExp - $maxExp years';
    }
    if (minExp != null) {
      return '$minExp+ years';
    }
    return 'Fresher';
  }

  String _getAgeLimit() {
    final minAge = widget.job['age_min_years'];
    final maxAge = widget.job['age_max_years'];
    if (minAge != null && maxAge != null) {
      return '$minAge - $maxAge years';
    }
    if (minAge != null) {
      return '$minAge+ years';
    }
    if (maxAge != null) {
      return 'Up to $maxAge years';
    }
    return 'Not specified';
  }

  String _getTotalVacancies() {
    if (widget.job['total_posts'] != null) {
      return widget.job['total_posts'].toString();
    }
    return 'Not specified';
  }

  String _getApplicationMode() {
    if (widget.job['application_mode'] != null &&
        widget.job['application_mode'].toString().isNotEmpty) {
      return widget.job['application_mode'].toString();
    }
    return 'Online';
  }

  String _getGenderPreference() {
    if (widget.job['gender_preference'] != null &&
        widget.job['gender_preference'].toString().isNotEmpty) {
      return widget.job['gender_preference'].toString();
    }
    return 'Any';
  }

  String _getWorkSchedule() {
    if (widget.job['work_schedule'] != null &&
        widget.job['work_schedule'].toString().isNotEmpty) {
      return widget.job['work_schedule'].toString();
    }
    return 'Full Time';
  }

  String _getShift() {
    if (widget.job['shift'] != null &&
        widget.job['shift'].toString().isNotEmpty) {
      return widget.job['shift'].toString();
    }
    return 'Day Shift';
  }

  String _getWorkingDays() {
    if (widget.job['working_days'] != null &&
        widget.job['working_days'].toString().isNotEmpty) {
      return widget.job['working_days'].toString();
    }
    return 'Monday to Friday';
  }

  String _getJobLevel() {
    if (widget.job['job_level'] != null &&
        widget.job['job_level'].toString().isNotEmpty) {
      return widget.job['job_level'].toString().toUpperCase();
    }
    return 'MID';
  }

  String _getCategory() {
    if (widget.job['category'] != null &&
        widget.job['category'].toString().isNotEmpty) {
      return widget.job['category'].toString();
    }
    return 'General';
  }

  String _getUrgencyLevel() {
    if (widget.job['urgency_level'] != null &&
        widget.job['urgency_level'].toString().isNotEmpty) {
      return widget.job['urgency_level'].toString();
    }
    return 'Normal';
  }

  bool _hasValidWebsiteUrl() {
    final websiteUrl = widget.job['website_url'];
    if (websiteUrl != null &&
        websiteUrl.toString().isNotEmpty &&
        websiteUrl.toString().trim() != '#' &&
        websiteUrl.toString().trim() != '') {
      return true;
    }
    return false;
  }

  bool _hasApplyWithUsLink() {
    final hasApplyWithUs = widget.job['has_apply_with_us'] == true;
    final applyUrl = widget.job['apply_with_us_url'];
    if (hasApplyWithUs &&
        applyUrl != null &&
        applyUrl.toString().isNotEmpty &&
        applyUrl.toString().trim() != '#') {
      return true;
    }
    final applyLink = widget.job['apply_link'];
    if (applyLink != null &&
        applyLink.toString().isNotEmpty &&
        applyLink.toString().trim() != '#') {
      return true;
    }
    return false;
  }

  String _getWebsiteUrl() {
    final websiteUrl = widget.job['website_url'];
    if (websiteUrl != null &&
        websiteUrl.toString().isNotEmpty &&
        websiteUrl.toString().trim() != '#') {
      return websiteUrl.toString().trim();
    }
    return '';
  }

  bool _hasApplicationFees() {
    return widget.job['has_application_fees'] == true &&
        widget.job['application_fees'] != null &&
        (widget.job['application_fees'] as Map).isNotEmpty;
  }

  Map<String, dynamic> _getApplicationFees() {
    if (_hasApplicationFees()) {
      return Map<String, dynamic>.from(widget.job['application_fees']);
    }
    return {};
  }

  bool _hasAnyNotification() {
    return _hasOfficialNotification || _hasAdvertisement;
  }

  Color _getJobTypeColor(String? type) {
    switch (type) {
      case 'private':
        return const Color(0xFF6C63FF);
      case 'remote':
        return Colors.purple;
      case 'government':
        return Colors.green;
      case 'hybrid':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getJobTypeIcon(String? type) {
    switch (type) {
      case 'private':
        return Icons.business_center;
      case 'remote':
        return Icons.wifi;
      case 'government':
        return Icons.account_balance;
      case 'hybrid':
        return Icons.sync;
      default:
        return Icons.work;
    }
  }

  IconData _getAdvertisementIcon() {
    if (_isAdvertisementPdf) return Icons.picture_as_pdf;
    if (_isImageFile) return Icons.image;
    if (_isGoogleDriveLink) return Icons.cloud_queue;
    if (_isPrivateCloudinaryFile) return Icons.lock;
    return Icons.link;
  }

  String _getAdvertisementSubtitle() {
    if (_isAdvertisementPdf) return "PDF Document - Click to view";
    if (_isImageFile) return "Image File - Click to view";
    if (_isGoogleDriveLink) return "Google Drive Link - Click to open";
    if (_isPrivateCloudinaryFile) return "🔒 Secure PDF - Private Document";
    return "External Link - Click to open";
  }

  String _getAdvertisementButtonText() {
    if (_isAdvertisementPdf) return "View Advertisement PDF";
    if (_isImageFile) return "View Advertisement Image";
    if (_isGoogleDriveLink) return "Open Google Drive Link";
    if (_isPrivateCloudinaryFile) return "Open Secure PDF";
    return "Open Advertisement Link";
  }

  List<dynamic> _getMultiplePosts() {
    final posts = widget.job['multiple_posts'];
    if (posts != null && posts is List) {
      return posts;
    }
    return [];
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  Future<void> _applyOnWebsite() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      _showSnackBar("Please login to apply", isError: true);
      return;
    }
    setState(() => _isApplyingOnWebsite = true);
    try {
      String applyUrl = _getWebsiteUrl();
      if (applyUrl.isEmpty) {
        _showSnackBar("Apply link not available", isError: true);
        return;
      }
      if (!applyUrl.startsWith('http')) {
        applyUrl = 'https://$applyUrl';
      }
      final Uri url = Uri.parse(applyUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        _showSnackBar("Opening application page...");
      } else {
        _showSnackBar("Could not open link", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => _isApplyingOnWebsite = false);
    }
  }

  // ============================================================
  // ✅ APPLY WITH US - PASSES TOTAL FEES TO PAYMENT SCREEN
  // ============================================================
  Future<void> _applyWithUs() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      _showSnackBar("Please login to apply", isError: true);
      return;
    }
    if (_hasApplied) {
      _showSnackBar("⚠️ Already applied", isError: true);
      return;
    }
    if (_isPaymentProcessing) return;

    setState(() {
      _isApplyingWithUs = true;
      _isPaymentProcessing = true;
    });

    try {
      final jobId = widget.job['_id'].toString();

      try {
        final checkResponse = await DioClient.dio.get('/jobs/my-applications');
        if (checkResponse.data is Map) {
          final applications = checkResponse.data['applications'] ?? [];
          final alreadyApplied =
              applications.any((app) => app['job_id'].toString() == jobId);
          if (alreadyApplied) {
            if (mounted) {
              setState(() => _hasApplied = true);
              _showSnackBar("Already applied", isError: true);
            }
            return;
          }
        }
      } catch (e) {
        debugPrint("Error checking application status: $e");
      }

      final freshJobResponse = await DioClient.dio.get('/jobs/$jobId');
      Map<String, dynamic> freshJob = freshJobResponse.data;
      if (freshJobResponse.data.containsKey('data')) {
        freshJob = freshJobResponse.data['data'];
      }

      final hasFees = freshJob['has_application_fees'] == true;
      final fees = freshJob['application_fees'];

      debugPrint("=" * 60);
      debugPrint("💳 PAYMENT INITIATION");
      debugPrint("   Has Fees: $hasFees");
      debugPrint("   User Disabled: $_isDisabled");
      debugPrint("   User Category: $_userCategory");
      debugPrint("   Effective Category: ${_getEffectivePaymentCategory()}");
      debugPrint("=" * 60);

      // ✅ Always calculate fee breakdown (even if no app fees, service charge applies)
      final feeBreakdown = _calculateFeeBreakdown();

      debugPrint("=" * 60);
      debugPrint("💰 FEE BREAKDOWN");
      debugPrint("   Application Fee: ₹${feeBreakdown.applicationFee}");
      debugPrint("   GST (${GST_PERCENT.toInt()}%): ₹${feeBreakdown.gstAmount}");
      debugPrint("   Service Charge: ₹${feeBreakdown.serviceCharge}");
      debugPrint("   TOTAL: ₹${feeBreakdown.totalFee}");
      debugPrint("=" * 60);

      if (feeBreakdown.totalFee <= 0) {
        _showSnackBar("Invalid fee amount", isError: true);
        return;
      }

      // ✅ Get the effective category key and display name
      final categoryKey = _getEffectivePaymentCategory();
      final categoryDisplayName = _getEffectivePaymentCategoryDisplay();

      final orderResponse = await DioClient.dio.post(
        '/payment/razorpay/create-order',
        data: {
          "amount": feeBreakdown.totalFee,
          "payment_type": "job",
          "job_id": jobId,
          "job_title": widget.job['post_name'] ?? 'Job',
          "organization": widget.job['organization'] ?? 'Company',
          // ✅ Send breakdown to backend for record
          "application_fee": feeBreakdown.applicationFee,
          "gst_amount": feeBreakdown.gstAmount,
          "service_charge": feeBreakdown.serviceCharge,
        },
      );

      if (!mounted) return;
      setState(() => _isApplyingWithUs = false);

      final responseData = orderResponse.data;
      final orderId = responseData['order_id'] ?? '';
      final keyId = responseData['key_id'] ?? '';
      final paymentId = responseData['payment_id'] ?? '';

      debugPrint("💰 Order Response - Order ID: $orderId, Payment ID: $paymentId");

      if (orderId.isEmpty || keyId.isEmpty) {
        _showSnackBar("Payment order failed", isError: true);
        return;
      }

      // ✅ PASS DISABILITY-AWARE CATEGORY AND TOTAL AMOUNT TO PAYMENT SCREEN
      final paymentCompleted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PaymentScreen(
          jobId: jobId,
          jobTitle: widget.job['post_name'] ?? 'Job',
          organization: widget.job['organization'] ?? 'Company',
          // ✅ Total amount includes app fee + GST + service charge
          amount: feeBreakdown.totalFee,
          // ✅ Pass breakdown for display in payment screen
          applicationFee: feeBreakdown.applicationFee,
          gstAmount: feeBreakdown.gstAmount,
          serviceCharge: feeBreakdown.serviceCharge,
          // ✅ PASS THE DISABILITY-AWARE CATEGORY
          categoryUsed: categoryKey,
          paymentId: paymentId,
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
          onPaymentSuccess: () {
            debugPrint("✅ Job Payment success callback");
            if (mounted) setState(() => _hasApplied = true);
            if (widget.onApplicationSubmitted != null) {
              widget.onApplicationSubmitted!();
            }
          },
          paymentType: PaymentType.job,
        ),
      );

      if (paymentCompleted == true && mounted) {
        _showSnackBar("✅ Application submitted!");
        await _checkIfAlreadyApplied();
        if (widget.onApplicationSubmitted != null) {
          widget.onApplicationSubmitted!();
        }
      } else if (mounted) {
        _showSnackBar("Payment cancelled", isError: true);
      }
    } catch (apiError) {
      debugPrint("Payment API Error: $apiError");
      if (mounted) {
        if (apiError.toString().contains("already applied")) {
          setState(() => _hasApplied = true);
          _showSnackBar("Already applied", isError: true);
        } else {
          _showSnackBar("Payment failed", isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingWithUs = false;
          _isPaymentProcessing = false;
        });
      }
    }
  }

  Future<void> _submitDirectApplication(String jobId) async {
    try {
      final isSaved = _isSaved;
      late dynamic response;
      if (isSaved) {
        response = await DioClient.dio.post(
          '/jobs/convert-saved-to-applied/$jobId',
          data: {
            "job_id": jobId,
            "cover_letter": "Applied via 'Apply with Us'",
            "additional_info": {
              "applied_from": "job_detail_screen",
              "application_source": "direct_application",
              "applied_at": DateTime.now().toIso8601String(),
            },
          },
        );
      } else {
        response = await DioClient.dio.post(
          '/jobs/apply/$jobId',
          data: {
            "job_id": jobId,
            "cover_letter": "Applied via 'Apply with Us'",
            "additional_info": {
              "applied_from": "job_detail_screen",
              "application_source": "direct_application",
              "applied_at": DateTime.now().toIso8601String(),
            },
          },
        );
      }
      if (!mounted) return;
      final responseData = response.data;
      final isSuccessResponse = responseData['status'] == 'success' ||
          responseData['success'] == true;
      if (isSuccessResponse) {
        setState(() => _hasApplied = true);
        _showSnackBar("✅ Application submitted!");
        if (widget.onApplicationSubmitted != null) {
          widget.onApplicationSubmitted!();
        }
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        _showSnackBar(
          responseData['message'] ?? 'Failed to submit',
          isError: true,
        );
      }
    } catch (e) {
      if (e.toString().contains("already applied")) {
        setState(() => _hasApplied = true);
        _showSnackBar("Already applied", isError: true);
      } else {
        _showSnackBar("Failed to apply: ${e.toString()}", isError: true);
      }
    }
  }

  Future<void> _toggleSaveJob() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      _showSnackBar("Please login to save", isError: true);
      return;
    }
    try {
      if (_isSaved) {
        await DioClient.dio.delete('/jobs/save/${widget.job['_id']}');
        setState(() => _isSaved = false);
        _showSnackBar("Removed from saved");
      } else {
        await DioClient.dio.post('/jobs/save/${widget.job['_id']}');
        setState(() => _isSaved = true);
        _showSnackBar("Saved!");
      }
    } catch (e) {
      _showSnackBar("Failed: $e", isError: true);
    }
  }

  void _shareJob() {
    final job = widget.job;
    String notificationInfo = "";
    if (_hasOfficialNotification) {
      notificationInfo +=
          "\n📄 Official Notification: $_officialNotificationUrl";
    }
    if (_hasAdvertisement) {
      notificationInfo += "\n📢 Advertisement: $_advertisementUrl";
    }
    final shareText =
        "📢 *${job['post_name'] ?? 'Job Opportunity'}* at ${job['organization'] ?? 'Company'}\n\n"
        "📍 Location: ${_getJobLocation()}\n"
        "💼 Job Type: ${job['job_type']?.toString().toUpperCase() ?? 'N/A'}\n"
        "🎓 Qualification: ${_getQualificationDisplay()}\n"
        "💰 Salary: ${_getSalaryDisplay()}\n"
        "📅 Last Date: ${_getLastDate()}\n"
        "$notificationInfo\n\n"
        "Apply on RojgarNext App\n\n"
        "Download RojgarNext App for more jobs!";

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
            const Text("Share Job",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  SelectableText(shareText, style: const TextStyle(height: 1.5)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text("Close"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareText));
                      Navigator.pop(context);
                      _showSnackBar("Copied to clipboard");
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    showMessage(context, message, isError: isError);
  }

  // ============================================================
  // ✅ ENHANCED: FILE VIEWERS - Opens ALL file types in FileViewerScreen
  // ============================================================
  void _showFilePopup(
    String url,
    String title, {
    String? downloadUrl,
    String? fileType,
  }) {
    String finalUrl = url.trim();
    if (finalUrl.isEmpty) {
      _showSnackBar("No file URL available", isError: true);
      return;
    }

    if (!finalUrl.startsWith('http') &&
        !finalUrl.startsWith('file') &&
        !finalUrl.startsWith('blob:')) {
      finalUrl = 'https://$finalUrl';
    }

    // ✅ Auto-detect file type if not provided or unknown
    String effectiveFileType = fileType ?? 'unknown';
    if (effectiveFileType == 'unknown' || effectiveFileType.isEmpty) {
      effectiveFileType = _JobFileTypeDetector.detectFileType(
        finalUrl,
        explicitType: fileType,
      );
    }

    debugPrint('=' * 70);
    debugPrint('📄 OPENING FILE VIEWER');
    debugPrint('   URL: $finalUrl');
    debugPrint('   Title: $title');
    debugPrint('   File Type: $effectiveFileType');
    debugPrint('   Download URL: ${downloadUrl ?? "same as url"}');
    debugPrint('=' * 70);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.95,
          height: MediaQuery.of(dialogContext).size.height * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: FileViewerScreen(
            url: finalUrl,
            title: title,
            downloadUrl: downloadUrl ?? finalUrl,
            fileType: effectiveFileType,
            fileName: title,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ VIEW OFFICIAL NOTIFICATION - Opens in FileViewerScreen
  // ============================================================
  void _viewOfficialNotification() {
    if (_officialNotificationUrl == null || _officialNotificationUrl!.isEmpty) {
      _showSnackBar("No notification link", isError: true);
      return;
    }

    // ✅ Detect if it's a PDF or other type
    final fileType = _isOfficialNotificationPdf
        ? 'pdf'
        : _JobFileTypeDetector.detectFileType(_officialNotificationUrl!);

    _showFilePopup(
      _officialNotificationUrl!,
      widget.job['post_name'] ?? "Official Notification",
      fileType: fileType,
    );
  }

  // ============================================================
  // ✅ VIEW ADVERTISEMENT - Opens ALL file types in FileViewerScreen
  // ============================================================
  void _viewAdvertisement() {
    if (_advertisementUrl == null || _advertisementUrl!.isEmpty) {
      _showSnackBar("No advertisement", isError: true);
      return;
    }

    // ✅ Enhanced file type detection using our helper
    final fileType = _JobFileTypeDetector.detectFileType(
      _advertisementUrl!,
    );

    debugPrint('📢 Advertisement file type: $fileType');
    debugPrint('   URL: $_advertisementUrl');

    _showFilePopup(
      _advertisementUrl!,
      widget.job['post_name'] ?? "Job Advertisement",
      downloadUrl: _advertisementDownloadUrl,
      fileType: fileType,
    );
  }

  // ============================================================
  // DESIGN HELPERS
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

  BoxDecoration _buildGlassContainerDecoration({bool isDark = false}) {
    return BoxDecoration(
      color: isDark
          ? Colors.grey.shade800.withOpacity(0.85)
          : Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? Colors.grey.shade700 : Colors.white.withOpacity(0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.08),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildGlassCard(Widget child, bool isDark, {Color? accentColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildGlassContainerDecoration(isDark: isDark),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color ?? const Color(0xFF6C63FF), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, {Color? color}) {
    return _buildSectionHeader(title, icon, color: color);
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
    bool isLongText = false,
    bool isLink = false,
  }) {
    if (value.isEmpty || value == 'Not specified' || value == 'Not provided')
      return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Colors.blueGrey),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isLink
                ? InkWell(
                    onTap: () async {
                      final uri = Uri.parse(
                          value.startsWith('http') ? value : 'https://$value');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color: color ?? Colors.black87,
                      fontSize: 13,
                      height: isLongText ? 1.5 : 1.2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    Color? color,
    bool isLink = false,
  }) {
    if (value.isEmpty || value == 'Not specified' || value == 'Not provided')
      return const SizedBox();
    return Row(
      children: [
        Icon(icon,
            size: 18,
            color: isLink
                ? Colors.blue
                : (color ?? (isDark ? Colors.grey.shade400 : Colors.blue))),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey),
          ),
        ),
        Expanded(
          child: isLink
              ? InkWell(
                  onTap: () async {
                    final uri = Uri.parse(
                        value.startsWith('http') ? value : 'https://$value');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color ?? (isDark ? Colors.white : Colors.black87),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
        child: Container(
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AI LOADING SCREEN
  // ============================================================
  Widget _buildLoadingScreen() {
    return Center(
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
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                    ),
                    borderRadius: BorderRadius.circular(18),
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
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
            ).createShader(bounds),
            child: const Text(
              "AI is loading job details...",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    final job = widget.job;
    final jobType = job['job_type'] ?? 'private';
    final typeColor = _getJobTypeColor(jobType);
    final postedDate = _formatPostedDate();
    final lastDate = _getLastDate();
    final hasValidWebsiteUrl = _hasValidWebsiteUrl();
    final hasApplyWithUsLink = _hasApplyWithUsLink();
    final showApplyButtons = hasValidWebsiteUrl || hasApplyWithUsLink;
    final multiplePosts = _getMultiplePosts();
    final hasMultiplePosts = multiplePosts.isNotEmpty;
    final hasAnyNotification = _hasAnyNotification();
    final hasApplicationFees = _hasApplicationFees();
    final applicationFees = _getApplicationFees();

    // ✅ NEW: Calculate fee breakdown for display
    final feeBreakdown = _calculateFeeBreakdown();

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: _buildAppBar(isDark),
      body: Container(
        decoration: _buildGradientBackground(),
        child: (_isLoadingCategory || _isLoadingDisability)
            ? _buildLoadingScreen()
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI HEADER CARD
                      _buildAIHeaderCard(
                          job, typeColor, postedDate, lastDate, isDark),
                      const SizedBox(height: 16),

                      // ✅ DISABILITY STATUS BANNER (if disabled)
                      if (_isDisabled) _buildDisabilityBanner(isDark),
                      if (_isDisabled) const SizedBox(height: 16),

                      // AI INSIGHTS ROW
                      if (_insights.isNotEmpty) _buildAIInsightsRow(isDark),
                      if (_insights.isNotEmpty) const SizedBox(height: 16),

                      // KEY INFO
                      _buildKeyInfoSection(job, isDark),
                      const SizedBox(height: 16),

                      // APPLICATION TIMELINE
                      if (_getApplicationStartDate().isNotEmpty ||
                          _getApplicationEndDate().isNotEmpty)
                        _buildApplicationTimelineSection(isDark),
                      if (_getApplicationStartDate().isNotEmpty ||
                          _getApplicationEndDate().isNotEmpty)
                        const SizedBox(height: 16),

                      // ✅ UPDATED: APPLICATION FEES with Service Charge & GST
                      if (hasApplicationFees &&
                          applicationFees.isNotEmpty)
                        _buildApplicationFeesSection(
                          applicationFees,
                          feeBreakdown,
                          isDark,
                        ),
                      if (hasApplicationFees &&
                          applicationFees.isNotEmpty)
                        const SizedBox(height: 16),

                      // AGE LIMIT
                      if (_getAgeLimit() != 'Not specified')
                        _buildAgeLimitSection(isDark),
                      if (_getAgeLimit() != 'Not specified')
                        const SizedBox(height: 16),

                      // EXAM CITIES
                      if (job['exam_cities'] != null &&
                          (job['exam_cities'] as List).isNotEmpty)
                        _buildExamCitiesSection(job['exam_cities'], isDark),
                      if (job['exam_cities'] != null &&
                          (job['exam_cities'] as List).isNotEmpty)
                        const SizedBox(height: 16),

                      // WORK DETAILS
                      _buildWorkDetailsSection(isDark),
                      const SizedBox(height: 16),

                      // BENEFITS
                      if (job['benefits'] != null &&
                          (job['benefits'] as List).isNotEmpty)
                        _buildBenefitsSection(job['benefits'], isDark),
                      if (job['benefits'] != null &&
                          (job['benefits'] as List).isNotEmpty)
                        const SizedBox(height: 16),

                      // LANGUAGES
                      if (job['languages_required'] != null &&
                          (job['languages_required'] as List).isNotEmpty)
                        _buildLanguagesSection(job['languages_required'], isDark),
                      if (job['languages_required'] != null &&
                          (job['languages_required'] as List).isNotEmpty)
                        const SizedBox(height: 16),

                      // EDUCATION DETAILS
                      if (job['education_details'] != null &&
                          job['education_details'].toString().isNotEmpty)
                        _buildEducationDetailsSection(
                            job['education_details'], isDark),
                      if (job['education_details'] != null &&
                          job['education_details'].toString().isNotEmpty)
                        const SizedBox(height: 16),

                      // EXPERIENCE DETAILS
                      if (job['experience_details'] != null &&
                          job['experience_details'].toString().isNotEmpty)
                        _buildExperienceDetailsSection(
                            job['experience_details'], isDark),
                      if (job['experience_details'] != null &&
                          job['experience_details'].toString().isNotEmpty)
                        const SizedBox(height: 16),

                      // PHYSICAL ELIGIBILITY
                      if (job['physical_eligibility'] != null)
                        _buildPhysicalEligibilitySection(
                            job['physical_eligibility'], isDark),
                      if (job['physical_eligibility'] != null)
                        const SizedBox(height: 16),

                      // INTERVIEW
                      if (job['interview_venue'] != null ||
                          job['interview_link'] != null ||
                          job['interview_date'] != null ||
                          job['interview_time'] != null)
                        _buildInterviewSection(isDark),
                      if (job['interview_venue'] != null ||
                          job['interview_link'] != null ||
                          job['interview_date'] != null ||
                          job['interview_time'] != null)
                        const SizedBox(height: 16),

                      // SELECTION PROCESS
                      if (job['selection_stages'] != null &&
                          (job['selection_stages'] as List).isNotEmpty)
                        _buildSelectionProcessSection(
                            job['selection_stages'],
                            job['selection_process_details'],
                            isDark),
                      if (job['selection_stages'] != null &&
                          (job['selection_stages'] as List).isNotEmpty)
                        const SizedBox(height: 16),

                      // CONTACT
                      if (job['contact_person'] != null ||
                          job['contact_email'] != null ||
                          job['contact_phone'] != null)
                        _buildContactInformationSection(isDark),
                      if (job['contact_person'] != null ||
                          job['contact_email'] != null ||
                          job['contact_phone'] != null)
                        const SizedBox(height: 16),

                      // IMPORTANT NOTES
                      if (job['important_notes'] != null &&
                          job['important_notes'].toString().isNotEmpty)
                        _buildImportantNotesSection(
                            job['important_notes'], isDark),
                      if (job['important_notes'] != null &&
                          job['important_notes'].toString().isNotEmpty)
                        const SizedBox(height: 16),

                      // TERMS
                      if (job['terms_conditions'] != null &&
                          job['terms_conditions'].toString().isNotEmpty)
                        _buildTermsConditionsSection(
                            job['terms_conditions'], isDark),
                      if (job['terms_conditions'] != null &&
                          job['terms_conditions'].toString().isNotEmpty)
                        const SizedBox(height: 16),

                      // IMPORTANT DATES
                      if (job['admit_card_date'] != null ||
                          job['exam_date'] != null ||
                          job['result_date'] != null)
                        _buildImportantDatesSection(
                          job['admit_card_date'],
                          job['exam_date'],
                          job['result_date'],
                          isDark,
                        ),
                      if (job['admit_card_date'] != null ||
                          job['exam_date'] != null ||
                          job['result_date'] != null)
                        const SizedBox(height: 16),

                      // HELPLINE
                      if (job['helpline_number'] != null ||
                          job['helpline_email'] != null ||
                          job['whatsapp_number'] != null ||
                          job['telegram_channel'] != null)
                        _buildHelplineSection(isDark),
                      if (job['helpline_number'] != null ||
                          job['helpline_email'] != null ||
                          job['whatsapp_number'] != null ||
                          job['telegram_channel'] != null)
                        const SizedBox(height: 16),

                      // DESCRIPTION
                      if (job['description'] != null &&
                          job['description'].toString().isNotEmpty)
                        _buildDescriptionSection(
                            job['description'], isDark),
                      if (job['description'] != null &&
                          job['description'].toString().isNotEmpty)
                        const SizedBox(height: 16),

                      // SKILLS
                      if (job['required_skills'] != null &&
                          (job['required_skills'] as List).isNotEmpty)
                        _buildSkillsSection(job['required_skills'], isDark),
                      if (job['required_skills'] != null &&
                          (job['required_skills'] as List).isNotEmpty)
                        const SizedBox(height: 16),

                      // MULTIPLE POSTS TABLE
                      if (hasMultiplePosts)
                        _buildMultiplePostsTable(
                            job, multiplePosts, isDark),
                      if (hasMultiplePosts) const SizedBox(height: 16),

                      // OFFICIAL NOTIFICATION
                      if (_hasOfficialNotification)
                        _buildOfficialNotificationSection(isDark),
                      if (_hasOfficialNotification)
                        const SizedBox(height: 16),

                      // ADVERTISEMENT
                      if (_hasAdvertisement)
                        _buildAdvertisementSection(isDark),
                      if (_hasAdvertisement) const SizedBox(height: 16),

                      // INFO NOTE
                      if (hasAnyNotification) _buildInfoNote(isDark),
                      if (hasAnyNotification) const SizedBox(height: 16),

                      // SAVE / SHARE
                      if (!_isCheckingApplied)
                        _buildSaveAndShareButtons(isDark),
                      if (!_isCheckingApplied) const SizedBox(height: 16),

                      // APPLY BUTTONS
                      if (_isCheckingApplied)
                        const Center(child: CircularProgressIndicator())
                      else if (showApplyButtons)
                        _buildApplyButtons(
                          hasApplyWithUsLink,
                          hasValidWebsiteUrl,
                          feeBreakdown,
                          isDark,
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ============================================================
  // ✅ DISABILITY BANNER - Shows when user is disabled
  // ============================================================
  Widget _buildDisabilityBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.orange.shade900.withOpacity(0.4),
                  Colors.amber.shade900.withOpacity(0.2)
                ]
              : [Colors.orange.shade50, Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.orange.shade600 : Colors.orange.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.amber],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.accessible,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "PWD Category Detected",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "PRIORITY",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "You will be charged the PWD (Divyangjan) application fee.",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                if (_disabilityPercentage != null &&
                    _disabilityPercentage!.isNotEmpty)
                  Text(
                    "Disability: $_disabilityPercentage%" +
                        (_disabilityCategory != null &&
                                _disabilityCategory!.isNotEmpty
                            ? " ($_disabilityCategory)"
                            : ""),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: const Text("Job Details"),
      backgroundColor: const Color(0xFF6C63FF),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => widget.onBack != null
            ? widget.onBack!()
            : Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white),
          onPressed: _toggleSaveJob,
          tooltip: "Save Job",
        ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: _shareJob,
          tooltip: "Share",
        ),
      ],
    );
  }

  // ============================================================
  // AI HEADER CARD
  // ============================================================
  Widget _buildAIHeaderCard(
    Map<String, dynamic> job,
    Color typeColor,
    String postedDate,
    String lastDate,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.grey.shade800, typeColor.withOpacity(0.2)]
              : [Colors.white.withOpacity(0.95), typeColor.withOpacity(0.12)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.white.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [typeColor, typeColor.withOpacity(0.6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getJobTypeIcon(job['job_type']),
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['post_name'] ?? 'Job Title',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['organization'] ?? 'Company Name',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            job['job_type']?.toString().toUpperCase() ?? 'N/A',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _matchScore >= 75
                                  ? [Colors.green, Colors.lightGreen]
                                  : _matchScore >= 50
                                      ? [Colors.orange, Colors.yellow]
                                      : [Colors.red, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${_matchScore.round()}% AI',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildHeaderInfo(
                    Icons.location_on, "Location", _getJobLocation(), isDark),
              ),
              Expanded(
                child: _buildHeaderInfo(
                    Icons.calendar_today, "Posted", postedDate, isDark),
              ),
            ],
          ),
          if (lastDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildHeaderInfo(
                  Icons.event, "Deadline", lastDate, isDark,
                  color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(IconData icon, String label, String value,
      bool isDark, {Color? color}) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: color ?? (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color ?? (isDark ? Colors.white : Colors.black87),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // AI INSIGHTS ROW
  // ============================================================
  Widget _buildAIInsightsRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.grey.shade800.withOpacity(0.8),
                  Colors.grey.shade700.withOpacity(0.8)
                ]
              : [
                  const Color(0xFF6C63FF).withOpacity(0.08),
                  const Color(0xFFFF6588).withOpacity(0.08)
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.grey.shade700
              : const Color(0xFF6C63FF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: _insights.map((insight) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.shade700
                  : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              insight,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade300 : Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // KEY INFO SECTION
  // ============================================================
  Widget _buildKeyInfoSection(Map<String, dynamic> job, bool isDark) {
    List<Widget> children = [
      _buildKeyInfoRow(Icons.work, "Job Level", _getJobLevel(), isDark),
      const Divider(height: 16),
      _buildKeyInfoRow(Icons.category, "Category", _getCategory(), isDark),
      const Divider(height: 16),
      _buildKeyInfoRow(
          Icons.work_history, "Experience", _getExperience(), isDark),
    ];

    if (widget.job['total_posts'] != null) {
      children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(
          Icons.people, "Vacancies", _getTotalVacancies(), isDark));
    }

    if (_getAgeLimit() != 'Not specified') {
      children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(
          Icons.calendar_today, "Age Limit", _getAgeLimit(), isDark));
    }

    if (_getGenderPreference() != 'Any') {
      children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(
          Icons.people, "Gender", _getGenderPreference(), isDark));
    }

    if (_getUrgencyLevel() != 'Normal') {
      children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(
          Icons.priority_high, "Urgency", _getUrgencyLevel(), isDark));
    }

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Key Information", Icons.info_outline),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // ✅ UPDATED: APPLICATION FEES - Disability-First Logic
  // ✅ NEW: Shows Application Fee + GST + Service Charge + Total
  // ============================================================
  Widget _buildApplicationFeesSection(
    Map<String, dynamic> fees,
    FeeBreakdown feeBreakdown,
    bool isDark,
  ) {
    final effectiveCategory = _getEffectivePaymentCategory();
    final effectiveDisplay = _getEffectivePaymentCategoryDisplay();
    final isPwd = _isPayingAsPwd();

    List<Widget> feeChildren = [];

    // ✅ Show category-wise application fees (base fees)
    fees.entries.forEach((entry) {
      // ✅ Check if this is the effective category (PWD or user's category)
      final entryKey = entry.key.toLowerCase();
      final isEffectiveCategory = entryKey == effectiveCategory.toLowerCase() ||
          _getAlternativeFeeKeys(effectiveCategory).contains(entryKey);

      // ✅ Special handling for PWD when user is disabled
      final isPwdEntry = entryKey == 'pwd' ||
          _getAlternativeFeeKeys('pwd').contains(entryKey);

      final isHighlighted = isEffectiveCategory || (isPwd && isPwdEntry);

      feeChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Category badge
              Container(
                width: 110,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? (isPwd
                          ? (isDark
                              ? Colors.orange.shade800
                              : Colors.orange.shade100)
                          : (isDark
                              ? Colors.green.shade800
                              : Colors.green.shade100))
                      : (isDark
                          ? Colors.teal.shade800
                          : Colors.teal.shade100),
                  borderRadius: BorderRadius.circular(12),
                  border: isHighlighted
                      ? Border.all(
                          color: isPwd ? Colors.orange : Colors.green,
                          width: 2)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHighlighted)
                      Icon(
                        isPwd ? Icons.accessible : Icons.check_circle,
                        size: 14,
                        color: isPwd ? Colors.orange : Colors.green,
                      )
                    else
                      const SizedBox.shrink(),
                    if (isHighlighted) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.key.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isHighlighted
                              ? (isPwd
                                  ? (isDark
                                      ? Colors.orange.shade200
                                      : Colors.orange.shade900)
                                  : (isDark
                                      ? Colors.green.shade200
                                      : Colors.green.shade900))
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Fee amount
              Expanded(
                child: Row(
                  children: [
                    Text(
                      "₹${entry.value}",
                      style: TextStyle(
                        fontSize: isHighlighted ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: isHighlighted
                            ? (isPwd ? Colors.orange : Colors.green)
                            : Colors.teal,
                      ),
                    ),
                    if (isHighlighted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPwd ? Colors.orange : Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isPwd ? "PWD RATE" : "YOUR CATEGORY",
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });

    // ✅ NEW: Build complete fee breakdown (Application Fee + GST + Service Charge + Total)
    final hasAppFee = feeBreakdown.applicationFee > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPwd
              ? (isDark
                  ? [
                      Colors.orange.shade900.withOpacity(0.3),
                      Colors.amber.shade900.withOpacity(0.1)
                    ]
                  : [Colors.orange.shade50, Colors.amber.shade50])
              : (isDark
                  ? [
                      Colors.teal.shade900.withOpacity(0.3),
                      Colors.teal.shade800.withOpacity(0.1)
                    ]
                  : [Colors.teal.shade50, Colors.teal.shade100.withOpacity(0.5)]),
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPwd
              ? (isDark ? Colors.orange.shade600 : Colors.orange.shade300)
              : (isDark ? Colors.teal.shade700 : Colors.teal.shade300),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPwd
                        ? [Colors.orange, Colors.amber]
                        : [Colors.teal, Colors.tealAccent],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPwd ? Icons.accessible : Icons.currency_rupee,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Application Fees",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isPwd ? Colors.orange : Colors.teal,
                      ),
                    ),
                    Text(
                      isPwd
                          ? "♿ PWD (Disabled) rate applied"
                          : "Your category: $effectiveDisplay",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontWeight:
                            isPwd ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              // User's total fee summary badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPwd
                        ? [Colors.orange, Colors.amber]
                        : [Colors.green, Colors.lightGreen],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isPwd ? Colors.orange : Colors.green)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPwd) ...[
                          const Icon(Icons.accessible,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          "₹${feeBreakdown.totalFee}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isPwd ? "PWD Total" : "Total Payable",
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
              color: isDark
                  ? Colors.grey.shade700
                  : (isPwd
                      ? Colors.orange.shade200
                      : Colors.teal.shade200)),
          const SizedBox(height: 8),

          // ✅ Category-wise base fees
          ...feeChildren,

          // ✅ NEW: Complete Fee Breakdown
          const SizedBox(height: 12),
          Divider(
              color: isDark
                  ? Colors.grey.shade700
                  : (isPwd
                      ? Colors.orange.shade200
                      : Colors.teal.shade200)),
          const SizedBox(height: 8),

          // Breakdown title
          Text(
            "💰 Fee Breakdown",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Application Fee row
          if (hasAppFee)
            _buildFeeBreakdownRow(
              "Application Fees",
              feeBreakdown.applicationFee,
              isDark,
              Colors.teal,
            ),
          if (hasAppFee) const SizedBox(height: 8),

          // GST row
          if (hasAppFee)
            _buildFeeBreakdownRow(
              "GST (${GST_PERCENT.toInt()}%)",
              feeBreakdown.gstAmount,
              isDark,
              Colors.orange,
            ),
          if (hasAppFee) const SizedBox(height: 8),

          // Service Charge row
          _buildFeeBreakdownRow(
            "Service Charge",
            feeBreakdown.serviceCharge,
            isDark,
            Colors.purple,
          ),
          const SizedBox(height: 12),

          // Total Divider
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPwd
                    ? [Colors.orange, Colors.amber]
                    : [Colors.green, Colors.lightGreen],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 12),

          // Total row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPwd
                    ? [Colors.orange.shade400, Colors.amber.shade400]
                    : [Colors.green.shade600, Colors.green.shade400],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isPwd ? Colors.orange : Colors.green)
                      .withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isPwd ? Icons.accessible : Icons.payments,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Total Payable",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  "₹${feeBreakdown.totalFee}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Info note
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.shade800.withOpacity(0.5)
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isPwd ? Colors.orange : Colors.teal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasAppFee
                        ? "Total = Application Fee ₹${feeBreakdown.applicationFee} + GST ₹${feeBreakdown.gstAmount} + Service Charge ₹${feeBreakdown.serviceCharge} = ₹${feeBreakdown.totalFee}"
                        : "Service Charge ₹${feeBreakdown.serviceCharge} applies for this application.",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade400
                          : (isPwd
                              ? Colors.orange.shade800
                              : Colors.teal.shade800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Helper to build each breakdown row
  Widget _buildFeeBreakdownRow(
    String label,
    int amount,
    bool isDark,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade800.withOpacity(0.4)
            : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
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
      ),
    );
  }

  // ============================================================
  // AGE LIMIT
  // ============================================================
  Widget _buildAgeLimitSection(bool isDark) {
    final ageCalcDate = widget.job['age_calculation_date'];
    final ageRelaxationDetails = widget.job['age_relaxation_details'];
    final ageRelaxationByCategory = widget.job['age_relaxation_by_category'];

    List<Widget> children = [
      _buildKeyInfoRow(
          Icons.calendar_today, "Age Limit", _getAgeLimit(), isDark),
    ];

    if (ageCalcDate != null && ageCalcDate.toString().isNotEmpty) {
      children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.event, "Calculation Date",
          _formatDate(ageCalcDate), isDark));
    }

    if (ageRelaxationDetails != null &&
        ageRelaxationDetails.toString().isNotEmpty) {
      children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.extension, "Relaxation",
          ageRelaxationDetails.toString(), isDark));
    }

    if (ageRelaxationByCategory != null &&
        ageRelaxationByCategory is Map &&
        ageRelaxationByCategory.isNotEmpty) {
      children.add(const Divider(height: 16));
      children.add(const Text(
        "Category-wise Relaxation:",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ));
      children.add(const SizedBox(height: 8));
      ageRelaxationByCategory.entries.forEach((entry) {
        final isUserCategory = _isDisabled
            ? entry.key.toLowerCase().contains('pwd') ||
                entry.key.toLowerCase().contains('ph')
            : entry.key.toLowerCase() == (_userCategory ?? '').toLowerCase();

        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  isUserCategory ? Icons.check_circle : Icons.people,
                  size: 14,
                  color: isUserCategory ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  "${entry.key.toUpperCase()}: ",
                  style: TextStyle(
                    fontWeight:
                        isUserCategory ? FontWeight.bold : FontWeight.w500,
                    color: isUserCategory ? Colors.green : null,
                  ),
                ),
                Text(
                  "${entry.value} years",
                  style: TextStyle(
                    color: isUserCategory ? Colors.green : null,
                  ),
                ),
                if (isUserCategory) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "YOU",
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      });
    }

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Age Requirements", Icons.calendar_today),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // EXAM CITIES
  // ============================================================
  Widget _buildExamCitiesSection(List<dynamic> examCities, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Exam Cities", Icons.location_city),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: examCities
                .map((city) => Chip(
                      label: Text(city.toString()),
                      backgroundColor: isDark
                          ? Colors.grey.shade700
                          : Colors.blue.shade50,
                    ))
                .toList(),
          ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // WORK DETAILS
  // ============================================================
  Widget _buildWorkDetailsSection(bool isDark) {
    List<Widget> children = [
      _buildKeyInfoRow(Icons.schedule, "Schedule", _getWorkSchedule(), isDark),
      const Divider(height: 16),
      _buildKeyInfoRow(Icons.nightlight_round, "Shift", _getShift(), isDark),
      const Divider(height: 16),
      _buildKeyInfoRow(
          Icons.calendar_today, "Working Days", _getWorkingDays(), isDark),
    ];

    if (widget.job['is_fully_remote'] == true) {
      children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.wifi, "Mode", "Fully Remote", isDark,
          color: Colors.purple));
    } else if (widget.job['is_hybrid'] == true) {
      children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.sync, "Mode", "Hybrid", isDark,
          color: Colors.orange));
    }

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Work Details", Icons.work_outline),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // BENEFITS
  // ============================================================
  Widget _buildBenefitsSection(List<dynamic> benefits, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Benefits & Perks", Icons.card_giftcard,
              color: Colors.green),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: benefits
                .map((benefit) => Chip(
                      label: Text(benefit.toString()),
                      backgroundColor: isDark
                          ? Colors.grey.shade700
                          : Colors.green.shade50,
                      avatar: const Icon(Icons.card_giftcard,
                          size: 16, color: Colors.green),
                    ))
                .toList(),
          ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // LANGUAGES
  // ============================================================
  Widget _buildLanguagesSection(List<dynamic> languages, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Languages Required", Icons.language,
              color: Colors.blue),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: languages
                .map((lang) => Chip(
                      label: Text(lang.toString()),
                      backgroundColor: isDark
                          ? Colors.grey.shade700
                          : Colors.blue.shade50,
                      avatar: const Icon(Icons.language,
                          size: 16, color: Colors.blue),
                    ))
                .toList(),
          ),
          if (widget.job['other_languages'] != null &&
              widget.job['other_languages'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Other: ${widget.job['other_languages']}",
                style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey),
              ),
            ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // EDUCATION DETAILS
  // ============================================================
  Widget _buildEducationDetailsSection(
      dynamic educationDetails, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Education Requirements", Icons.school,
              color: Colors.teal),
          const SizedBox(height: 8),
          Text(
            educationDetails.toString(),
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.grey.shade300 : Colors.black87),
          ),
          if (widget.job['required_qualification'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.teal.shade900.withOpacity(0.3)
                      : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, size: 16, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.job['required_qualification'].toString(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.teal.shade200
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // EXPERIENCE DETAILS
  // ============================================================
  Widget _buildExperienceDetailsSection(
      dynamic experienceDetails, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Experience Requirements", Icons.work_history,
              color: Colors.orange),
          const SizedBox(height: 8),
          Text(
            experienceDetails.toString(),
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.grey.shade300 : Colors.black87),
          ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // PHYSICAL ELIGIBILITY
  // ============================================================
  Widget _buildPhysicalEligibilitySection(
      Map<String, dynamic> physical, bool isDark) {
    List<Widget> children = [];

    if (physical['min_height_cm'] != null) {
      children.add(_buildKeyInfoRow(Icons.height, "Min Height",
          "${physical['min_height_cm']} cm", isDark));
    }

    if (physical['min_height_female_cm'] != null) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.height, "Min Height (Female)",
          "${physical['min_height_female_cm']} cm", isDark));
    }

    if (physical['min_chest_cm'] != null) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.fitness_center, "Min Chest",
          "${physical['min_chest_cm']} cm", isDark));
    }

    if (physical['max_weight_kg'] != null) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.monitor_weight, "Max Weight",
          "${physical['max_weight_kg']} kg", isDark));
    }

    if (physical['relaxation'] != null) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.extension, "Relaxation",
          physical['relaxation'].toString(), isDark));
    }

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Physical Eligibility", Icons.fitness_center,
              color: Colors.red),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // INTERVIEW
  // ============================================================
  Widget _buildInterviewSection(bool isDark) {
    final interviewVenue = widget.job['interview_venue'];
    final interviewLink = widget.job['interview_link'];
    final interviewDate = widget.job['interview_date'];
    final interviewTime = widget.job['interview_time'];
    final interviewDocuments = widget.job['interview_documents'];

    List<Widget> children = [];

    if (interviewVenue != null && interviewVenue.toString().isNotEmpty) {
      children.add(_buildKeyInfoRow(
          Icons.location_on, "Venue", interviewVenue.toString(), isDark));
    }

    if (interviewLink != null && interviewLink.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.link, "Online Link",
          interviewLink.toString(), isDark,
          isLink: true));
    }

    if (interviewDate != null && interviewDate.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(
          Icons.event, "Date", _formatDate(interviewDate), isDark));
    }

    if (interviewTime != null && interviewTime.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(
          Icons.access_time, "Time", interviewTime.toString(), isDark));
    }

    if (interviewDocuments != null &&
        interviewDocuments is List &&
        interviewDocuments.isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(const Text("Required Documents:",
          style: TextStyle(fontWeight: FontWeight.bold)));
      children.add(const SizedBox(height: 8));
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: interviewDocuments
              .map((doc) => Chip(
                    label: Text(doc.toString()),
                    backgroundColor: isDark
                        ? Colors.grey.shade700
                        : Colors.orange.shade50,
                    avatar: const Icon(Icons.description,
                        size: 16, color: Colors.orange),
                  ))
              .toList(),
        ),
      );
    }

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Interview Details", Icons.people,
              color: Colors.orange),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // SELECTION PROCESS
  // ============================================================
  Widget _buildSelectionProcessSection(
      List<dynamic> stages, String? details, bool isDark) {
    List<Widget> children = [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: stages
            .map((stage) => Chip(
                  label: Text(stage.toString()),
                  backgroundColor: isDark
                      ? Colors.grey.shade700
                      : Colors.purple.shade50,
                  avatar: const Icon(Icons.timeline,
                      size: 16, color: Colors.purple),
                ))
            .toList(),
      ),
    ];

    if (details != null && details.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(details,
              style: TextStyle(
                  fontSize: 13,
                  color:
                      isDark ? Colors.grey.shade300 : Colors.black87)),
        ),
      );
    }

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Selection Process", Icons.timeline,
              color: Colors.purple),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // CONTACT
  // ============================================================
  Widget _buildContactInformationSection(bool isDark) {
    final contactPerson = widget.job['contact_person'];
    final contactDesignation = widget.job['contact_designation'];
    final contactEmail = widget.job['contact_email'];
    final contactPhone = widget.job['contact_phone'];

    List<Widget> children = [];

    if (contactPerson != null && contactPerson.toString().isNotEmpty) {
      children.add(_buildKeyInfoRow(Icons.person, "Contact Person",
          contactPerson.toString(), isDark));
    }

    if (contactDesignation != null &&
        contactDesignation.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.badge, "Designation",
          contactDesignation.toString(), isDark));
    }

    if (contactEmail != null && contactEmail.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.email, "Email",
          contactEmail.toString(), isDark,
          isLink: true));
    }

    if (contactPhone != null && contactPhone.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.phone, "Phone",
          contactPhone.toString(), isDark,
          isLink: true));
    }

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Contact Information", Icons.contact_mail,
              color: Colors.blue),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // IMPORTANT NOTES
  // ============================================================
  Widget _buildImportantNotesSection(dynamic notes, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Important Notes", Icons.warning,
              color: Colors.red),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.red.shade900.withOpacity(0.3)
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              notes.toString(),
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark
                      ? Colors.red.shade200
                      : Colors.black87),
            ),
          ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // TERMS
  // ============================================================
  Widget _buildTermsConditionsSection(dynamic terms, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Terms & Conditions", Icons.description,
              color: Colors.grey),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              terms.toString(),
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color:
                      isDark ? Colors.grey.shade300 : Colors.black87),
            ),
          ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // IMPORTANT DATES
  // ============================================================
  Widget _buildImportantDatesSection(
    String? admitCardDate,
    String? examDate,
    String? resultDate,
    bool isDark,
  ) {
    List<Widget> children = [];

    if (admitCardDate != null && admitCardDate.toString().isNotEmpty) {
      children.add(_buildKeyInfoRow(Icons.download, "Admit Card",
          _formatDate(admitCardDate), isDark));
    }

    if (examDate != null && examDate.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.edit_calendar, "Exam Date",
          _formatDate(examDate), isDark));
    }

    if (resultDate != null && resultDate.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.assignment_turned_in, "Result",
          _formatDate(resultDate), isDark));
    }

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Important Dates", Icons.event,
              color: Colors.blue),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // HELPLINE
  // ============================================================
  Widget _buildHelplineSection(bool isDark) {
    final helplineNumber = widget.job['helpline_number'];
    final helplineEmail = widget.job['helpline_email'];
    final whatsappNumber = widget.job['whatsapp_number'];
    final telegramChannel = widget.job['telegram_channel'];
    final officialWebsite = widget.job['official_website'];

    List<Widget> children = [];

    if (helplineNumber != null && helplineNumber.toString().isNotEmpty) {
      children.add(_buildKeyInfoRow(Icons.support_agent, "Helpline",
          helplineNumber.toString(), isDark,
          isLink: true));
    }

    if (helplineEmail != null && helplineEmail.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.email, "Helpline Email",
          helplineEmail.toString(), isDark,
          isLink: true));
    }

    if (whatsappNumber != null && whatsappNumber.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.chat, "WhatsApp",
          whatsappNumber.toString(), isDark,
          isLink: true));
    }

    if (telegramChannel != null && telegramChannel.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.telegram, "Telegram",
          telegramChannel.toString(), isDark,
          isLink: true));
    }

    if (officialWebsite != null && officialWebsite.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const Divider(height: 16));
      children.add(_buildKeyInfoRow(Icons.public, "Website",
          officialWebsite.toString(), isDark,
          isLink: true));
    }

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Helpline & Resources", Icons.support,
              color: Colors.teal),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================
  Widget _buildDescriptionSection(dynamic description, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Job Description", Icons.description,
              color: Colors.blue),
          const SizedBox(height: 12),
          Text(
            description.toString(),
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.grey.shade300 : Colors.black87),
          ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // SKILLS
  // ============================================================
  Widget _buildSkillsSection(List<dynamic> skills, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Required Skills", Icons.build,
              color: Colors.blue),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills.map((skill) {
              final skillName = skill is Map ? skill['name'] : skill;
              return Chip(
                label: Text(skillName.toString(),
                    style: const TextStyle(fontSize: 13)),
                backgroundColor: isDark
                    ? Colors.grey.shade700
                    : Colors.blue.shade50,
                avatar: const Icon(Icons.check_circle,
                    size: 16, color: Colors.blue),
              );
            }).toList(),
          ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // MULTIPLE POSTS TABLE
  // ============================================================
  Widget _buildMultiplePostsTable(
      Map<String, dynamic> job, List<dynamic> multiplePosts, bool isDark) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.green.shade900
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.table_chart,
                    color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Post-wise Vacancy Details",
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (job['total_posts'] != null)
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.green.shade900
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Total: ${job['total_posts']}",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.green.shade200
                            : Colors.black87),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.resolveWith(
                (states) =>
                    isDark ? Colors.grey.shade700 : Colors.blue.shade50,
              ),
              columns: const [
                DataColumn(
                    label: Text("S.No",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Post Name",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Vacancies",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Qualification",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Experience",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Age Limit",
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: multiplePosts.asMap().entries.map((entry) {
                final index = entry.key;
                final post = entry.value;
                final postAgeMin = post['age_min'];
                final postAgeMax = post['age_max'];
                final experienceDetails = post['experience_details'] ?? '';

                String qualificationDisplay = '—';
                final degreeName = post['degree_name'];
                final degreeStream = post['degree_stream'];
                final qualMain = post['qualification_main'];
                final qualSub = post['qualification_sub'];
                final otherQual = post['other_qualification_details'];
                final qualification = post['qualification'];

                if (degreeName != null && degreeName.toString().isNotEmpty) {
                  if (degreeStream != null &&
                      degreeStream.toString().isNotEmpty) {
                    qualificationDisplay = "$degreeName - $degreeStream";
                  } else {
                    qualificationDisplay = degreeName.toString();
                  }
                } else if (degreeStream != null &&
                    degreeStream.toString().isNotEmpty) {
                  qualificationDisplay = degreeStream.toString();
                } else if (qualMain != null &&
                    qualMain.toString().isNotEmpty) {
                  qualificationDisplay = qualMain.toString();
                } else if (qualSub != null && qualSub.toString().isNotEmpty) {
                  qualificationDisplay = qualSub.toString();
                } else if (qualification != null &&
                    qualification.toString().isNotEmpty) {
                  qualificationDisplay = qualification.toString();
                }

                String experienceDisplay = experienceDetails.isNotEmpty
                    ? experienceDetails
                    : 'Not specified';
                String ageLimit = 'Not specified';
                if (postAgeMin != null && postAgeMax != null) {
                  ageLimit = '$postAgeMin - $postAgeMax years';
                } else if (postAgeMin != null) {
                  ageLimit = '$postAgeMin+ years';
                } else if (postAgeMax != null) {
                  ageLimit = 'Up to $postAgeMax years';
                }

                return DataRow(
                  cells: [
                    DataCell(Text("${index + 1}")),
                    DataCell(Text(post['post_name'] ?? 'Post Name')),
                    DataCell(Text("${post['total_posts'] ?? 1}")),
                    DataCell(
                      Tooltip(
                        message: qualificationDisplay,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            qualificationDisplay,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      experienceDisplay != 'Not specified'
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                experienceDisplay,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : Text(experienceDisplay,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey)),
                    ),
                    DataCell(Text(ageLimit,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // OFFICIAL NOTIFICATION
  // ============================================================
  Widget _buildOfficialNotificationSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.blue.shade900.withOpacity(0.3),
                  Colors.blue.shade800.withOpacity(0.1)
                ]
              : [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color:
                isDark ? Colors.blue.shade700 : Colors.blue.shade300,
            width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.shade800
                      : Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isOfficialNotificationPdf
                      ? Icons.picture_as_pdf
                      : Icons.link,
                  color: isDark
                      ? Colors.blue.shade200
                      : Colors.blue.shade800,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📄 Official Notification",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                    Text(
                      _isOfficialNotificationPdf
                          ? "PDF Document"
                          : "External Link",
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Click the button below to view the official job notification",
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _viewOfficialNotification,
              icon: Icon(
                  _isOfficialNotificationPdf
                      ? Icons.picture_as_pdf
                      : Icons.open_in_new,
                  size: 20,
                  color: Colors.white),
              label: Text(
                _isOfficialNotificationPdf
                    ? "View Notification PDF"
                    : "Open Link",
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADVERTISEMENT
  // ============================================================
  Widget _buildAdvertisementSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.orange.shade900.withOpacity(0.3),
                  Colors.orange.shade800.withOpacity(0.1)
                ]
              : [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.orange.shade700
                : Colors.orange.shade300,
            width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.shade800
                      : Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getAdvertisementIcon(),
                  color: isDark
                      ? Colors.orange.shade200
                      : Colors.orange.shade800,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📢 Official Advertisement",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange),
                    ),
                    Text(
                      _getAdvertisementSubtitle(),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Click the button below to view the official job advertisement",
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _viewAdvertisement,
              icon: const Icon(Icons.open_in_new,
                  size: 20, color: Colors.white),
              label: Text(
                _getAdvertisementButtonText(),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO NOTE
  // ============================================================
  Widget _buildInfoNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blue.shade900.withOpacity(0.3)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _hasOfficialNotification && _hasAdvertisement
                  ? "This job has both Official Notification and Advertisement available."
                  : _hasOfficialNotification
                      ? "Official Notification PDF available."
                      : _hasAdvertisement && _isPrivateCloudinaryFile
                          ? "🔒 Secure PDF advertisement available."
                          : "Advertisement file available.",
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.blue.shade200
                      : Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPLICATION TIMELINE
  // ============================================================
  Widget _buildApplicationTimelineSection(bool isDark) {
    List<Widget> children = [];

    if (_getApplicationStartDate().isNotEmpty) {
      children.add(_buildKeyInfoRow(Icons.play_circle, "Start Date",
          _getApplicationStartDate(), isDark));
      children.add(const Divider(height: 16));
    }

    if (_getApplicationEndDate().isNotEmpty) {
      children.add(_buildKeyInfoRow(Icons.stop_circle, "End Date",
          _getApplicationEndDate(), isDark));
      children.add(const Divider(height: 16));
    }

    children.add(_buildKeyInfoRow(
        Icons.devices, "Mode", _getApplicationMode(), isDark));

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Application Timeline", Icons.timeline,
              color: Colors.blue),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
      isDark,
    );
  }

  // ============================================================
  // SAVE / SHARE
  // ============================================================
  Widget _buildSaveAndShareButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleSaveJob,
            icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                size: 20,
                color: _isSaved
                    ? Colors.green
                    : const Color(0xFF6C63FF)),
            label: Text(
              _isSaved ? "Saved" : "Save Job",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isSaved
                      ? Colors.green
                      : const Color(0xFF6C63FF)),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: _isSaved
                      ? Colors.green
                      : const Color(0xFF6C63FF),
                  width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareJob,
            icon: const Icon(Icons.share, size: 20, color: Colors.teal),
            label: const Text("Share Job",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.teal, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ✅ UPDATED: APPLY BUTTONS - Shows Total Fee Breakdown
  // ============================================================
  Widget _buildApplyButtons(
    bool hasApplyWithUsLink,
    bool hasValidWebsiteUrl,
    FeeBreakdown feeBreakdown,
    bool isDark,
  ) {
    if (_hasApplied) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle, size: 20),
          label: const Text("Already Applied",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      );
    }

    // ✅ Show user's effective category and total fee in apply button area
    final hasFees = _hasApplicationFees();
    final effectiveDisplay = _getEffectivePaymentCategoryDisplay();
    final isPwd = _isPayingAsPwd();
    final totalFee = feeBreakdown.totalFee;

    return Column(
      children: [
        // ✅ Show fee info (always show if service charge or app fee exists)
        if (totalFee > 0)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPwd
                    ? [Colors.orange.shade50, Colors.amber.shade50]
                    : [Colors.green.shade50, Colors.teal.shade50],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPwd
                    ? Colors.orange.shade300
                    : Colors.green.shade200,
                width: isPwd ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPwd
                              ? [Colors.orange, Colors.amber]
                              : [Colors.green, Colors.lightGreen],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPwd ? Icons.accessible : Icons.payment,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Total Payable",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isPwd
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                              if (isPwd) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "PWD PRIORITY",
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            isPwd
                                ? "PWD Fee: ₹${feeBreakdown.applicationFee} + GST ₹${feeBreakdown.gstAmount} + Service ₹${feeBreakdown.serviceCharge}"
                                : "$effectiveDisplay Fee: ₹${feeBreakdown.applicationFee} + GST ₹${feeBreakdown.gstAmount} + Service ₹${feeBreakdown.serviceCharge}",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPwd
                              ? [Colors.orange, Colors.amber]
                              : [Colors.green, Colors.lightGreen],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "₹$totalFee",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                // ✅ Breakdown line below
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "₹${feeBreakdown.applicationFee}",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal),
                      ),
                      const Text(" + ",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        "₹${feeBreakdown.gstAmount}",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange),
                      ),
                      const Text(" + ",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        "₹${feeBreakdown.serviceCharge}",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple),
                      ),
                      const Text(" = ",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        "₹${feeBreakdown.totalFee}",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSmallFeeLabel(
                        "App Fee", Colors.teal, isDark),
                    const SizedBox(width: 8),
                    _buildSmallFeeLabel(
                        "GST ${GST_PERCENT.toInt()}%", Colors.orange, isDark),
                    const SizedBox(width: 8),
                    _buildSmallFeeLabel(
                        "Service", Colors.purple, isDark),
                  ],
                ),
              ],
            ),
          ),
        Row(
          children: [
            if (hasApplyWithUsLink)
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (_isApplyingWithUs || _isPaymentProcessing)
                        ? null
                        : _applyWithUs,
                    icon: (_isApplyingWithUs || _isPaymentProcessing)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.payment, size: 20),
                    label: Text(
                      (_isApplyingWithUs || _isPaymentProcessing)
                          ? "Processing..."
                          : "Apply with Us",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                  ),
                ),
              ),
            if (hasApplyWithUsLink && hasValidWebsiteUrl)
              const SizedBox(width: 12),
            if (hasValidWebsiteUrl)
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isApplyingOnWebsite ? null : _applyOnWebsite,
                    icon: _isApplyingOnWebsite
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.open_in_browser, size: 20),
                    label: Text(
                      _isApplyingOnWebsite
                          ? "Opening..."
                          : "Apply on Website",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side:
                          const BorderSide(color: Colors.blue, width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _toggleSaveJob,
            icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                size: 20),
            label: Text(_isSaved ? "Saved" : "Save Job",
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  _isSaved ? Colors.green : const Color(0xFF6C63FF),
              side: BorderSide(
                  color: _isSaved
                      ? Colors.green
                      : const Color(0xFF6C63FF),
                  width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Small fee label helper
  Widget _buildSmallFeeLabel(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}