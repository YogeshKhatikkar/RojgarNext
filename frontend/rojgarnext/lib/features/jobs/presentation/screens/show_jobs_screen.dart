// lib/features/jobs/presentation/screens/show_jobs_screen.dart
// ✅ AI-POWERED MODERN REDESIGN – Glassmorphism, Gradients, Animated Loading
// ✅ Fixed all type errors (explicit casts for filter data)
// ✅ Preserves all original functionality (caching, delete, refresh, navigation)
// ✅ Fully matches the ApplicationsScreen UI pattern

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/job_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------- AI SERVICE ----------
class AdminJobAIService {
  static double calculateEngagementScore(Map<String, dynamic> job) {
    final applications = (job['applications_count'] ?? 0) as num;
    final views = (job['views_count'] ?? 0) as num;
    if (applications == 0 && views == 0) return 0;
    final maxApps = 100.0;
    final maxViews = 1000.0;
    final appScore = (applications / maxApps).clamp(0.0, 1.0) * 70;
    final viewScore = (views / maxViews).clamp(0.0, 1.0) * 30;
    return appScore + viewScore;
  }

  static List<String> getInsights(List<dynamic> jobs) {
    List<String> insights = [];
    if (jobs.isEmpty) return ['No jobs posted yet'];

    int totalApps = 0;
    int totalViews = 0;
    int openJobs = 0;
    int closedJobs = 0;
    for (var job in jobs) {
      totalApps += (job['applications_count'] ?? 0) as int;
      totalViews += (job['views_count'] ?? 0) as int;
      if (job['status'] == 'open') openJobs++;
      else closedJobs++;
    }

    insights.add("📊 Total Jobs: ${jobs.length}");
    if (openJobs > 0) insights.add("🟢 Open: $openJobs");
    if (closedJobs > 0) insights.add("🔴 Closed: $closedJobs");
    insights.add("👥 Total Applications: $totalApps");
    insights.add("👁️ Total Views: $totalViews");

    if (jobs.isNotEmpty) {
      var topJob = jobs.reduce((a, b) {
        final aScore = calculateEngagementScore(a);
        final bScore = calculateEngagementScore(b);
        return aScore >= bScore ? a : b;
      });
      final topTitle = topJob['post_name'] ?? 'Untitled';
      final topApps = topJob['applications_count'] ?? 0;
      insights.add("🏆 Top: $topTitle ($topApps applications)");
    }
    return insights;
  }
}

// ---------- MAIN SCREEN ----------
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
    with SingleTickerProviderStateMixin {
  List<dynamic> jobs = [];
  List<dynamic> _filteredJobs = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String? errorMessage;

  // Cache key
  static const String _cacheKey = 'admin_jobs_cache';

  // AI insights
  List<String> _insights = [];

  // Filter
  String _filterStatus = 'all'; // 'all', 'open', 'closed'

  // Animation for loading
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ---------- LIFECYCLE ----------
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadCachedJobs();
    _fetchJobs(); // background refresh
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ---------- CACHING ----------
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

  // ---------- API ----------
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

  // ---------- FILTERS ----------
  void _applyFilters() {
    List<dynamic> filtered = List.from(jobs);
    if (_filterStatus != 'all') {
      filtered = filtered.where((job) => job['status'] == _filterStatus).toList();
    }
    setState(() => _filteredJobs = filtered);
  }

  // ---------- DELETE ----------
  Future<void> _deleteJob(String jobId, String jobTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Job"),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  // ---------- NAVIGATION ----------
  void _onJobTap(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
    ).then((_) => _fetchJobs());
  }

  // ---------- HELPERS ----------
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
      case 'private': return Colors.blue;
      case 'remote': return Colors.purple;
      case 'government': return Colors.green;
      case 'hybrid': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getJobTypeIcon(String? type) {
    switch (type) {
      case 'private': return Icons.business_center;
      case 'remote': return Icons.wifi;
      case 'government': return Icons.account_balance;
      case 'hybrid': return Icons.sync;
      default: return Icons.work;
    }
  }

  // ---------- GRADIENT BACKGROUND ----------
  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
      ),
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
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
            _buildAIInsightsHeader(),
            _buildFilterChips(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ---------- LOADING SCREEN (same as admin applications) ----------
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
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
              ),
              const SizedBox(height: 30),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ).createShader(bounds),
                child: const Text(
                  "AI is loading your jobs...",
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

  // ---------- APP BAR ----------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'My Jobs',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color(0xFF6C63FF),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchJobs,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list),
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

  // ---------- AI INSIGHTS HEADER (gradient, glass) ----------
  Widget _buildAIInsightsHeader() {
    final jobCount = _filteredJobs.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(top: 8, left: 12, right: 12),
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
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
                      ),
                    ),
                    Text(
                      "$jobCount jobs • AI analyzed",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      "AI",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_insights.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: _insights.map((insight) {
                  return Text(
                    insight,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- FILTER CHIPS (with explicit casts) ----------
  Widget _buildFilterChips() {
    // Use a typed list of maps to avoid repeated casts, but still cast for safety
    final List<Map<String, dynamic>> filterValues = [
      {'value': 'all', 'label': 'All', 'icon': Icons.list, 'color': Colors.grey},
      {'value': 'open', 'label': 'Open', 'icon': Icons.check_circle, 'color': Colors.green},
      {'value': 'closed', 'label': 'Closed', 'icon': Icons.cancel, 'color': Colors.red},
    ];

    return Container(
      height: 56,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
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
          final bool isSelected = _filterStatus == value;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _filterStatus = selected ? value : 'all';
                  _applyFilters();
                });
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: color,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- BODY (with error/empty handling) ----------
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
        padding: const EdgeInsets.all(16),
        itemCount: _filteredJobs.length,
        itemBuilder: (context, index) =>
            _buildJobCard(_filteredJobs[index], index),
      ),
    );
  }

  // ---------- JOB CARD (glassmorphism, AI engagement, modern) ----------
  Widget _buildJobCard(Map<String, dynamic> job, int index) {
    final jobTitle = job['post_name'] ?? 'Job Title';
    final organization = job['organization'] ?? 'Company';
    final location = job['location'] ?? 'Not specified';
    final jobType = job['job_type'] ?? 'private';
    final typeColor = _getJobTypeColor(jobType);
    final status = job['status'] ?? 'open';
    final postedDate = _formatDate(job['created_at']);
    final applicationsCount = job['applications_count'] ?? 0;
    final viewsCount = job['views_count'] ?? 0;
    final salaryMin = job['salary_min'];
    final salaryMax = job['salary_max'];

    final engagementScore = AdminJobAIService.calculateEngagementScore(job);
    final bool isHighEngagement = engagementScore >= 50;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _onJobTap(job),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.92),
                typeColor.withOpacity(0.08),
              ],
            ),
            border: Border.all(
              color: isHighEngagement
                  ? const Color(0xFF6C63FF).withOpacity(0.5)
                  : Colors.grey.shade200,
              width: isHighEngagement ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: status, type, menu
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'open'
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: status == 'open' ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status == 'open' ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: status == 'open' ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: status == 'open' ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getJobTypeIcon(jobType), size: 12, color: typeColor),
                        const SizedBox(width: 4),
                        Text(
                          jobType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isHighEngagement)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            "${engagementScore.round()}%",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'delete', child: Text("Delete")),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') _deleteJob(job['_id'], jobTitle);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title & Org
              Text(
                jobTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                organization,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              // Info chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.location_on, location),
                  _buildInfoChip(Icons.calendar_today, postedDate),
                  if (salaryMin != null || salaryMax != null)
                    _buildInfoChip(Icons.currency_rupee, _formatSalary(salaryMin, salaryMax)),
                ],
              ),
              const SizedBox(height: 12),
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Applications",
                      applicationsCount.toString(),
                      Icons.assignment,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      "Views",
                      viewsCount.toString(),
                      Icons.visibility,
                      Colors.grey,
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- FAB ----------
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        // Future: navigate to add job screen
        showMessage(context, "Add job feature coming soon", isError: false);
      },
      icon: const Icon(Icons.add),
      label: const Text("Add Job"),
      backgroundColor: const Color(0xFF6C63FF),
      foregroundColor: Colors.white,
    );
  }

  // ---------- ERROR & EMPTY STATES ----------
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            'Oops! Something went wrong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchJobs,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No jobs found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            _filterStatus != 'all'
                ? 'Try changing the filter'
                : 'Click on "Add Job" to create your first job posting',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (_filterStatus != 'all')
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _filterStatus = 'all');
                _applyFilters();
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}