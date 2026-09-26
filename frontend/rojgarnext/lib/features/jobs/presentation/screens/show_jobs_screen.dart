// lib/features/jobs/presentation/screens/show_jobs_screen.dart
// ✅ AI-POWERED MODERN REDESIGN – Glassmorphism, Gradients, Animated Loading
// ✅ AI insights banner with animated gradient orbs + KPI strip
// ✅ Glassmorphism job cards with AI engagement ring
// ✅ Pill-style animated filter chips with count badges
// ✅ Beautiful error + empty states
// ✅ Fixed all type errors (explicit casts for filter data)
// ✅ Preserves all original functionality (caching, delete, refresh, navigation)
// ✅ UPDATED: Add Job now renders INLINE on the right side of the sidebar
//            (no route push) with a back button in the AppBar

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/job_detail_screen.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/add_job_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===============================================================
// AI SERVICE (unchanged logic)
// ===============================================================
class AdminJobAIService {
  static double calculateEngagementScore(Map<String, dynamic> job) {
    final applications = (job['applications_count'] ?? 0) as num;
    final views = (job['views_count'] ?? 0) as num;
    if (applications == 0 && views == 0) return 0;
    const maxApps = 100.0;
    const maxViews = 1000.0;
    final appScore = (applications / maxApps).clamp(0.0, 1.0) * 70;
    final viewScore = (views / maxViews).clamp(0.0, 1.0) * 30;
    return appScore + viewScore;
  }

  static List<String> getInsights(List<dynamic> jobs) {
    final List<String> insights = [];
    if (jobs.isEmpty) return ['No jobs posted yet'];

    int totalApps = 0;
    int totalViews = 0;
    int openJobs = 0;
    int closedJobs = 0;
    for (var job in jobs) {
      totalApps += (job['applications_count'] ?? 0) as int;
      totalViews += (job['views_count'] ?? 0) as int;
      if (job['status'] == 'open') {
        openJobs++;
      } else {
        closedJobs++;
      }
    }

    insights.add("📊 Total Jobs: ${jobs.length}");
    if (openJobs > 0) insights.add("🟢 Open: $openJobs");
    if (closedJobs > 0) insights.add("🔴 Closed: $closedJobs");
    insights.add("👥 Applications: $totalApps");
    insights.add("👁️ Views: $totalViews");

    if (jobs.isNotEmpty) {
      var topJob = jobs.reduce((a, b) {
        final aScore = calculateEngagementScore(a);
        final bScore = calculateEngagementScore(b);
        return aScore >= bScore ? a : b;
      });
      final topTitle = topJob['post_name'] ?? 'Untitled';
      final topApps = topJob['applications_count'] ?? 0;
      insights.add("🏆 Top: $topTitle ($topApps apps)");
    }
    return insights;
  }
}

// ===============================================================
// ✅ LOCAL VIEW ENUM — controls which pane renders on the right
// ===============================================================
enum _ShowJobsView { list, addJob }

// ===============================================================
// MAIN SCREEN
// ===============================================================
class ShowJobsScreen extends StatefulWidget {
  final String adminRole;
  final VoidCallback? onJobDeleted;
  final VoidCallback? onJobUpdated;

  const ShowJobsScreen({
    super.key,
    this.adminRole = 'admin',
    this.onJobDeleted,
    this.onJobUpdated,
  });

  @override
  State<ShowJobsScreen> createState() => _ShowJobsScreenState();
}

class _ShowJobsScreenState extends State<ShowJobsScreen>
    with TickerProviderStateMixin {
  // ================= STATE =================
  List<dynamic> jobs = [];
  List<dynamic> _filteredJobs = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String? errorMessage;

  static const String _cacheKey = 'admin_jobs_cache';

  List<String> _insights = [];

  String _filterStatus = 'all'; // 'all', 'open', 'closed'

  // ✅ Which pane to show on the right of the sidebar
  _ShowJobsView _view = _ShowJobsView.list;

  // ================= ANIMATION CONTROLLERS =================
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _orbController;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _orbController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();

    _loadCachedJobs();
    _fetchJobs();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  // ================= CACHING =================
  Future<void> _loadCachedJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final List<dynamic> cachedJobs = jsonDecode(cached);
        if (cachedJobs.isNotEmpty) {
          setState(() {
            jobs = cachedJobs;
            _applyFilters();
            _insights = AdminJobAIService.getInsights(jobs);
            isLoading = false;
          });
          debugPrint('✅ Loaded ${jobs.length} admin jobs from cache');
        }
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
    }
  }

  Future<void> _saveJobsToCache(List<dynamic> jobs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(jobs));
      debugPrint('✅ Saved ${jobs.length} admin jobs to cache');
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  // ================= API =================
  String _getApiEndpoint() {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs';
      case 'superadmin':
        return '/superadmin/jobs';
      default:
        return '/admin/jobs';
    }
  }

  String _getDeleteEndpoint(String jobId) {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs/$jobId';
      case 'superadmin':
        return '/superadmin/jobs/$jobId';
      default:
        return '/admin/jobs/$jobId';
    }
  }

  Future<void> _fetchJobs() async {
    if (!mounted) return;

    setState(() {
      isRefreshing = true;
      errorMessage = null;
    });

    try {
      debugPrint("📤 Fetching jobs for ${widget.adminRole}...");
      final response = await DioClient.dio.get(_getApiEndpoint());
      debugPrint("📥 Response status: ${response.statusCode}");

      if (!mounted) return;

      dynamic jobsData = [];
      if (response.data is Map) {
        if (response.data.containsKey('data') && response.data['data'] is Map) {
          jobsData = response.data['data']['jobs'] ?? [];
        } else if (response.data.containsKey('jobs')) {
          jobsData = response.data['jobs'] ?? [];
        } else {
          jobsData = response.data['data'] ?? [];
        }
      } else {
        jobsData = response.data ?? [];
      }

      setState(() {
        jobs = jobsData is List ? jobsData : [];
        _applyFilters();
        _insights = AdminJobAIService.getInsights(jobs);
      });

      if (jobs.isNotEmpty) {
        await _saveJobsToCache(jobs);
      }
      debugPrint("✅ Jobs fetched: ${jobs.length}");

      _entranceController
        ..reset()
        ..forward();
    } catch (e) {
      debugPrint("❌ Error fetching jobs: $e");
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
        });
        if (jobs.isEmpty) {
          showMessage(context, "Failed to load jobs: $e", isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    }
  }

  // ================= FILTERS =================
  void _applyFilters() {
    List<dynamic> filtered = List.from(jobs);
    if (_filterStatus != 'all') {
      filtered =
          filtered.where((job) => job['status'] == _filterStatus).toList();
    }
    setState(() => _filteredJobs = filtered);
  }

  int _countByStatus(String status) {
    if (status == 'all') return jobs.length;
    return jobs.where((j) => j['status'] == status).length;
  }

  // ================= DELETE =================
  Future<void> _deleteJob(String jobId, String jobTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Job"),
          ],
        ),
        content: Text(
          "Are you sure you want to delete \"$jobTitle\"? All associated applications will also be deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DioClient.dio.delete(_getDeleteEndpoint(jobId));
      if (!mounted) return;
      showMessage(context, "Job deleted successfully");
      await _fetchJobs();
      widget.onJobDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Failed to delete job: $e", isError: true);
    }
  }

  // ================= NAVIGATION =================
  void _onJobTap(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
    ).then((_) => _fetchJobs());
  }

  // ============================================================
  // ✅ INLINE NAVIGATION — switch right pane (sidebar stays visible)
  // ============================================================
  void _openAddJobView() {
    setState(() => _view = _ShowJobsView.addJob);
  }

  void _closeAddJobView() {
    // Go back to the list and force-refresh so the new job shows up
    setState(() => _view = _ShowJobsView.list);
    _fetchJobs();
    // Bubble up to the parent dashboard (badge counts etc.)
    widget.onJobUpdated?.call();
  }

  // ================= HELPERS =================
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatSalary(dynamic min, dynamic max) {
    final minVal = min != null ? (min / 100000).toStringAsFixed(1) : null;
    final maxVal = max != null ? (max / 100000).toStringAsFixed(1) : null;
    if (minVal == null && maxVal == null) return 'Not disclosed';
    if (minVal != null && maxVal != null) return '₹${minVal}L - ₹${maxVal}L';
    if (minVal != null) return '₹${minVal}L+';
    return 'Up to ₹${maxVal}L';
  }

  Color _getJobTypeColor(String? type) {
    switch (type) {
      case 'private':
        return const Color(0xFF3B82F6);
      case 'remote':
        return const Color(0xFF8B5CF6);
      case 'government':
        return const Color(0xFF10B981);
      case 'hybrid':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
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

  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
      ),
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    // ✅ Inline view: Add Job (sidebar remains visible because we are
    //    rendered inside the dashboard's Expanded content area)
    if (_view == _ShowJobsView.addJob) {
      return Column(
        children: [
          _buildInlineAddJobHeader(),
          Expanded(
            child: AddJobScreen(
              adminRole: widget.adminRole,
              onJobAdded: () {
                // Keep the AddJobScreen open after success so the admin
                // can add another job; list refresh happens on back press.
                widget.onJobUpdated?.call();
              },
            ),
          ),
        ],
      );
    }

    // ✅ Default: list view
    if (isLoading && jobs.isEmpty) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: Container(
        decoration: _buildGradientBackground(),
        child: Column(
          children: [
            _buildAIInsightsBanner(),
            _buildStatsStrip(),
            _buildFilterChips(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ============================================================
  // ✅ INLINE ADD-JOB HEADER (back button + title)
  // ============================================================
  Widget _buildInlineAddJobHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ---- Back button ----
          Material(
            color: const Color(0xFF6C63FF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _closeAddJobView,
              splashColor: const Color(0xFF6C63FF).withOpacity(0.15),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: Color(0xFF6C63FF),
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Back",
                      style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // ---- Title ----
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  "Add New Job",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Fill all 8 tabs and publish",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // ---- Role badge ----
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.adminRole.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= LOADING SCREEN =================
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "AI is loading your jobs...",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Analyzing engagement & insights",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= APP BAR =================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'My Jobs',
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
      ),
      backgroundColor: const Color(0xFF6C63FF),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // ✅ Add Job button (same inline action)
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _openAddJobView,
          tooltip: 'Add Job',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchJobs,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (value) {
            if (value == 'all' || value == 'open' || value == 'closed') {
              setState(() => _filterStatus = value);
              _applyFilters();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'all', child: Text("All")),
            const PopupMenuItem(value: 'open', child: Text("Open")),
            const PopupMenuItem(value: 'closed', child: Text("Closed")),
          ],
        ),
      ],
    );
  }

  // ================= AI INSIGHTS BANNER =================
  Widget _buildAIInsightsBanner() {
    final jobCount = _filteredJobs.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: AnimatedBuilder(
              animation: _orbController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _orbController.value * 2 * math.pi,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.18),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: -20,
            bottom: -40,
            child: AnimatedBuilder(
              animation: _orbController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_orbController.value * 2 * math.pi,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.14),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.adminRole.toUpperCase()} Dashboard",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$jobCount jobs • AI analyzed",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildAIBadge(),
                ],
              ),
              if (_insights.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: _insights.map((insight) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            insight,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            "AI",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ================= KPI STATS STRIP =================
  Widget _buildStatsStrip() {
    final total = jobs.length;
    final open = _countByStatus('open');
    final closed = _countByStatus('closed');
    final totalApps = jobs.fold<int>(
        0, (sum, j) => sum + ((j['applications_count'] ?? 0) as int));
    final totalViews =
        jobs.fold<int>(0, (sum, j) => sum + ((j['views_count'] ?? 0) as int));

    final items = <_KpiItem>[
      _KpiItem("Total", "$total", Icons.work_rounded, const Color(0xFF6C63FF)),
      _KpiItem("Open", "$open", Icons.check_circle_rounded,
          const Color(0xFF10B981)),
      _KpiItem("Closed", "$closed", Icons.cancel_rounded,
          const Color(0xFFEF4444)),
      _KpiItem("Apps", "$totalApps", Icons.assignment_rounded,
          const Color(0xFF3B82F6)),
      _KpiItem("Views", "$totalViews", Icons.visibility_rounded,
          const Color(0xFFF59E0B)),
    ];

    return Container(
      height: 88,
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.color.withOpacity(0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: item.color.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, size: 16, color: item.color),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: item.color,
                      ),
                    ),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= FILTER CHIPS =================
  Widget _buildFilterChips() {
    final List<Map<String, dynamic>> filterValues = [
      {
        'value': 'all',
        'label': 'All',
        'icon': Icons.apps_rounded,
        'color': const Color(0xFF6C63FF),
        'count': _countByStatus('all'),
      },
      {
        'value': 'open',
        'label': 'Open',
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF10B981),
        'count': _countByStatus('open'),
      },
      {
        'value': 'closed',
        'label': 'Closed',
        'icon': Icons.cancel_rounded,
        'color': const Color(0xFFEF4444),
        'count': _countByStatus('closed'),
      },
    ];

    return Container(
      height: 54,
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filterValues.length,
        itemBuilder: (context, index) {
          final filter = filterValues[index];
          final String value = filter['value'] as String;
          final String label = filter['label'] as String;
          final IconData icon = filter['icon'] as IconData;
          final Color color = filter['color'] as Color;
          final int count = filter['count'] as int;
          final bool isSelected = _filterStatus == value;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [color, color.withOpacity(0.75)],
                      )
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 0 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(26),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _filterStatus = value;
                      _applyFilters();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: isSelected ? Colors.white : color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : color,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.25)
                                : color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$count",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= BODY =================
  Widget _buildBody() {
    if (errorMessage != null && jobs.isEmpty) {
      return _buildErrorState();
    }

    if (_filteredJobs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchJobs,
      color: const Color(0xFF6C63FF),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filteredJobs.length,
        itemBuilder: (context, index) {
          final double start = (index * 0.06).clamp(0.0, 0.6);
          final curved = CurvedAnimation(
            parent: _entranceController,
            curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
                curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: _buildJobCard(_filteredJobs[index], index),
            ),
          );
        },
      ),
    );
  }

  // ================= JOB CARD =================
  Widget _buildJobCard(Map<String, dynamic> job, int index) {
    final jobTitle = job['post_name'] ?? 'Job Title';
    final organization = job['organization'] ?? 'Company';
    final location = job['location'] ?? 'Not specified';
    final jobType = job['job_type'] ?? 'private';
    final typeColor = _getJobTypeColor(jobType);
    final status = job['status'] ?? 'open';
    final postedDate = _formatDate(job['created_at']);
    final applicationsCount = (job['applications_count'] ?? 0) as int;
    final viewsCount = (job['views_count'] ?? 0) as int;
    final salaryMin = job['salary_min'];
    final salaryMax = job['salary_max'];

    final engagementScore = AdminJobAIService.calculateEngagementScore(job);
    final bool isHighEngagement = engagementScore >= 50;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isHighEngagement
              ? [
                  const Color(0xFF6C63FF).withOpacity(0.06),
                  const Color(0xFFFF6588).withOpacity(0.05),
                ]
              : [Colors.white, Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: isHighEngagement
                ? const Color(0xFF6C63FF).withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isHighEngagement
              ? const Color(0xFF6C63FF).withOpacity(0.3)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onJobTap(job),
          splashColor: const Color(0xFF6C63FF).withOpacity(0.08),
          highlightColor: const Color(0xFF6C63FF).withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatusPill(status),
                    const SizedBox(width: 8),
                    _buildTypePill(jobType, typeColor),
                    const Spacer(),
                    if (isHighEngagement)
                      _buildAIRing(engagementScore, size: 42),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: const [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 10),
                              Text("Delete"),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteJob(job['_id'], jobTitle);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  jobTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  organization,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(Icons.location_on_outlined, location),
                    _buildInfoChip(
                        Icons.calendar_today_outlined, postedDate),
                    if (salaryMin != null || salaryMax != null)
                      _buildInfoChip(
                        Icons.currency_rupee,
                        _formatSalary(salaryMin, salaryMax),
                        highlight: true,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStat(
                        "Applications",
                        applicationsCount,
                        Icons.assignment_outlined,
                        const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStat(
                        "Views",
                        viewsCount,
                        Icons.visibility_outlined,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final bool isOpen = status == 'open';
    final color = isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill(String jobType, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getJobTypeIcon(jobType), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            jobType.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRing(double score, {double size = 42}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (score / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 3,
                  backgroundColor: const Color(0xFF6C63FF).withOpacity(0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF6C63FF),
                  ),
                ),
              );
            },
          ),
          Text(
            "${score.round()}",
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label,
      {bool highlight = false}) {
    final color = highlight
        ? const Color(0xFF10B981)
        : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    String title,
    int value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$value",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= FAB =================
  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        // ✅ Now switches the inline view — sidebar stays visible
        onPressed: _openAddJobView,
        icon: const Icon(Icons.add),
        label: const Text(
          "Add Job",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  // ================= ERROR STATE =================
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.red.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.15),
                      Colors.red.withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops! Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchJobs,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border:
                Border.all(color: const Color(0xFF6C63FF).withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.15),
                      const Color(0xFFFF6588).withOpacity(0.10),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.work_off_outlined,
                  size: 40,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No jobs found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _filterStatus != 'all'
                    ? 'Try changing the filter'
                    : 'Click on "Add Job" to create your first job posting',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (_filterStatus != 'all')
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _filterStatus = 'all');
                    _applyFilters();
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _openAddJobView,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===============================================================
// SMALL HELPER MODEL
// ===============================================================
class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiItem(this.label, this.value, this.icon, this.color);
}