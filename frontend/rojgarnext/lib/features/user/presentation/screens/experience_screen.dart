// lib/features/user/presentation/screens/experience_screen.dart
// ✅ COMPLETE FIXED VERSION
// ✅ FIXED: Cache busting for proper mode switching
// ✅ FIXED: Fresher/Experienced mode toggle working perfectly

import 'package:flutter/material.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/user/data/user_service.dart';

class ExperienceScreen extends StatefulWidget {
  const ExperienceScreen({super.key});

  @override
  State<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends State<ExperienceScreen> {
  List<Map<String, dynamic>> _experienceList = [];
  List<Map<String, dynamic>> _internshipList = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFresher = false;
  int _activeTabIndex = 0;

  // Experience Form Controllers
  final TextEditingController _companyCtrl = TextEditingController();
  final TextEditingController _roleCtrl = TextEditingController();
  final TextEditingController _industryCtrl = TextEditingController();
  final TextEditingController _workTypeCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _salaryCtrl = TextEditingController();
  final TextEditingController _startDateCtrl = TextEditingController();
  final TextEditingController _endDateCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _achievementsCtrl = TextEditingController();
  final TextEditingController _skillsCtrl = TextEditingController();
  final TextEditingController _reasonForLeaveCtrl = TextEditingController();
  final TextEditingController _reportingManagerCtrl = TextEditingController();
  final TextEditingController _teamSizeCtrl = TextEditingController();

  bool _isCurrent = false;
  String _employmentType = 'Full-time';
  final List<String> _employmentTypes = [
    'Full-time', 'Part-time', 'Contract', 'Freelance', 'Internship', 'Consultant',
  ];

  // Internship Form Controllers
  final TextEditingController _internshipCompanyCtrl = TextEditingController();
  final TextEditingController _internshipRoleCtrl = TextEditingController();
  final TextEditingController _internshipStartDateCtrl = TextEditingController();
  final TextEditingController _internshipEndDateCtrl = TextEditingController();
  final TextEditingController _internshipDescriptionCtrl = TextEditingController();
  final TextEditingController _internshipStipendCtrl = TextEditingController();
  final TextEditingController _internshipSkillsCtrl = TextEditingController();
  bool _isCurrentInternship = false;

  // Fresher Form Controllers
  final TextEditingController _internshipDetailsCtrl = TextEditingController();
  final TextEditingController _trainingProgramCtrl = TextEditingController();
  final TextEditingController _dailyWageCtrl = TextEditingController();
  final TextEditingController _projectsDoneCtrl = TextEditingController();
  final TextEditingController _certificationsCtrl = TextEditingController();
  String _labourType = 'Mason';
  final List<String> _labourTypes = [
    'Mason', 'Helper', 'Farming', 'Driver', 'Electrician',
    'Plumber', 'Carpenter', 'Painter', 'Other',
  ];

  String? _editingId;
  String? _editingInternshipId;

  @override
  void initState() {
    super.initState();
    _loadExperience();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _roleCtrl.dispose();
    _industryCtrl.dispose();
    _workTypeCtrl.dispose();
    _locationCtrl.dispose();
    _salaryCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _descriptionCtrl.dispose();
    _achievementsCtrl.dispose();
    _skillsCtrl.dispose();
    _reasonForLeaveCtrl.dispose();
    _reportingManagerCtrl.dispose();
    _teamSizeCtrl.dispose();
    _internshipCompanyCtrl.dispose();
    _internshipRoleCtrl.dispose();
    _internshipStartDateCtrl.dispose();
    _internshipEndDateCtrl.dispose();
    _internshipDescriptionCtrl.dispose();
    _internshipStipendCtrl.dispose();
    _internshipSkillsCtrl.dispose();
    _internshipDetailsCtrl.dispose();
    _trainingProgramCtrl.dispose();
    _dailyWageCtrl.dispose();
    _projectsDoneCtrl.dispose();
    _certificationsCtrl.dispose();
    super.dispose();
  }

  // ✅ FIXED: Force fresh data load with cache busting
  Future<void> _loadExperience({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      debugPrint("📊 _loadExperience called with forceRefresh: $forceRefresh");
      
      // ✅ Force fresh API call by passing a timestamp to bypass cache
      final data = await UserService.getProfileWithApplications(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      final isFresh = profile['is_fresher'] == true;

      debugPrint("📊 _loadExperience: isFresher from server = $isFresh");

      if (mounted) {
        setState(() {
          _isFresher = isFresh;
          
          if (!_isFresher) {
            // ✅ EXPERIENCED MODE - Load experience and internship data
            debugPrint("📊 Loading Experienced Mode data...");
            _experienceList = List<Map<String, dynamic>>.from(
              profile['experience'] ?? [],
            );
            _internshipList = List<Map<String, dynamic>>.from(
              profile['internships'] ?? [],
            );
            
            // Clear fresher data from UI
            _internshipDetailsCtrl.clear();
            _trainingProgramCtrl.clear();
            _dailyWageCtrl.clear();
            _projectsDoneCtrl.clear();
            _certificationsCtrl.clear();
            
            debugPrint("📊 Loaded ${_experienceList.length} experiences and ${_internshipList.length} internships");
          } else {
            // ✅ FRESHER MODE - Load fresher data
            debugPrint("📊 Loading Fresher Mode data...");
            _internshipDetailsCtrl.text = profile['internship_details'] ?? '';
            _trainingProgramCtrl.text = profile['training_program'] ?? '';
            _dailyWageCtrl.text = profile['daily_wage']?.toString() ?? '';
            _projectsDoneCtrl.text = profile['projects_done'] ?? '';
            _certificationsCtrl.text =
                (profile['certifications'] as List?)?.join(', ') ?? '';
            _labourType = profile['labour_type'] ?? 'Mason';
            
            // Clear experience data from UI
            _experienceList = [];
            _internshipList = [];
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading experience: $e");
      if (mounted) {
        showMessage(context, "Failed to load experience: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEditExperience(Map<String, dynamic> item) {
    _editingId = item['_id'];
    _companyCtrl.text = item['company'] ?? '';
    _roleCtrl.text = item['role'] ?? '';
    _industryCtrl.text = item['industry_type'] ?? '';
    _workTypeCtrl.text = item['work_type'] ?? '';
    _locationCtrl.text = item['location'] ?? '';
    _salaryCtrl.text = item['salary']?.toString() ?? '';
    _startDateCtrl.text = item['start_date'] ?? '';
    _endDateCtrl.text = item['end_date'] ?? '';
    _descriptionCtrl.text = item['description'] ?? '';
    _achievementsCtrl.text = (item['achievements'] as List?)?.join('\n') ?? '';
    _skillsCtrl.text = (item['skills_used'] as List?)?.join(', ') ?? '';
    _reasonForLeaveCtrl.text = item['reason_for_leaving'] ?? '';
    _reportingManagerCtrl.text = item['reporting_manager'] ?? '';
    _teamSizeCtrl.text = item['team_size']?.toString() ?? '';
    _isCurrent = item['end_date'] == null || item['end_date'] == '';
    _employmentType = item['employment_type'] ?? 'Full-time';
    setState(() {});
  }

  void _startEditInternship(Map<String, dynamic> item) {
    _editingInternshipId = item['_id'];
    _internshipCompanyCtrl.text = item['company'] ?? '';
    _internshipRoleCtrl.text = item['role'] ?? '';
    _internshipStartDateCtrl.text = item['start_date'] ?? '';
    _internshipEndDateCtrl.text = item['end_date'] ?? '';
    _internshipDescriptionCtrl.text = item['description'] ?? '';
    _internshipStipendCtrl.text = item['stipend']?.toString() ?? '';
    _internshipSkillsCtrl.text =
        (item['technologies'] as List?)?.join(', ') ?? '';
    _isCurrentInternship = item['end_date'] == null || item['end_date'] == '';
    setState(() {});
  }

  void _clearExperienceForm() {
    _editingId = null;
    _companyCtrl.clear();
    _roleCtrl.clear();
    _industryCtrl.clear();
    _workTypeCtrl.clear();
    _locationCtrl.clear();
    _salaryCtrl.clear();
    _startDateCtrl.clear();
    _endDateCtrl.clear();
    _descriptionCtrl.clear();
    _achievementsCtrl.clear();
    _skillsCtrl.clear();
    _reasonForLeaveCtrl.clear();
    _reportingManagerCtrl.clear();
    _teamSizeCtrl.clear();
    _isCurrent = false;
    _employmentType = 'Full-time';
    setState(() {});
  }

  void _clearInternshipForm() {
    _editingInternshipId = null;
    _internshipCompanyCtrl.clear();
    _internshipRoleCtrl.clear();
    _internshipStartDateCtrl.clear();
    _internshipEndDateCtrl.clear();
    _internshipDescriptionCtrl.clear();
    _internshipStipendCtrl.clear();
    _internshipSkillsCtrl.clear();
    _isCurrentInternship = false;
    setState(() {});
  }

  Future<void> _saveExperience() async {
    if (!_isFresher) {
      if (_activeTabIndex == 0) {
        await _saveWorkExperience();
      } else {
        await _saveInternship();
      }
    } else {
      await _saveFresher();
    }
  }

  Future<void> _saveWorkExperience() async {
    if (_companyCtrl.text.trim().isEmpty || _roleCtrl.text.trim().isEmpty) {
      if (mounted) {
        showMessage(context, "Company and Role are required", isError: true);
      }
      return;
    }

    if (_startDateCtrl.text.trim().isEmpty) {
      if (mounted) {
        showMessage(context, "Start date is required", isError: true);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    final payload = {
      'company': _companyCtrl.text.trim(),
      'role': _roleCtrl.text.trim(),
      'industry_type': _industryCtrl.text.trim(),
      'work_type': _workTypeCtrl.text.trim(),
      'employment_type': _employmentType,
      'location': _locationCtrl.text.trim(),
      'salary': int.tryParse(_salaryCtrl.text.trim()),
      'start_date': _startDateCtrl.text.trim(),
      'end_date': _isCurrent ? null : _endDateCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'achievements': _achievementsCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'skills_used': _skillsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'reason_for_leaving': _reasonForLeaveCtrl.text.trim(),
      'reporting_manager': _reportingManagerCtrl.text.trim(),
      'team_size': int.tryParse(_teamSizeCtrl.text.trim()),
    };

    try {
      if (_editingId != null) {
        await UserService.updateExperience(_editingId!, payload);
        if (mounted) {
          showMessage(context, "Experience updated successfully!");
        }
      } else {
        await UserService.addExperience(payload);
        if (mounted) {
          showMessage(context, "Experience added successfully!");
        }
      }
      _clearExperienceForm();
      await _loadExperience(forceRefresh: true);
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveInternship() async {
    if (_internshipCompanyCtrl.text.trim().isEmpty ||
        _internshipRoleCtrl.text.trim().isEmpty) {
      if (mounted) {
        showMessage(context, "Company and Role are required", isError: true);
      }
      return;
    }

    if (_internshipStartDateCtrl.text.trim().isEmpty) {
      if (mounted) {
        showMessage(context, "Start date is required", isError: true);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    final payload = {
      'company': _internshipCompanyCtrl.text.trim(),
      'role': _internshipRoleCtrl.text.trim(),
      'start_date': _internshipStartDateCtrl.text.trim(),
      'end_date': _isCurrentInternship
          ? null
          : _internshipEndDateCtrl.text.trim(),
      'description': _internshipDescriptionCtrl.text.trim(),
      'stipend': int.tryParse(_internshipStipendCtrl.text.trim()),
      'technologies': _internshipSkillsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };

    try {
      if (_editingInternshipId != null) {
        await UserService.updateInternship(_editingInternshipId!, payload);
        if (mounted) {
          showMessage(context, "Internship updated successfully!");
        }
      } else {
        await UserService.addInternship(payload);
        if (mounted) {
          showMessage(context, "Internship added successfully!");
        }
      }
      _clearInternshipForm();
      await _loadExperience(forceRefresh: true);
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveFresher() async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      final certificationsList = _certificationsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final data = {
        'is_fresher': true,
        'internship_details': _internshipDetailsCtrl.text.trim(),
        'training_program': _trainingProgramCtrl.text.trim(),
        'daily_wage': int.tryParse(_dailyWageCtrl.text.trim()),
        'projects_done': _projectsDoneCtrl.text.trim(),
        'certifications': certificationsList,
        'labour_type': _labourType,
      };
      await UserService.updateFresherStatus(data);
      await _loadExperience(forceRefresh: true);
      if (mounted) {
        showMessage(context, "Fresher information saved successfully!");
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteExperience(String id, String role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("Delete Experience"),
        content: Text("Are you sure you want to delete \"$role\" experience?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      await UserService.deleteExperience(id);
      await _loadExperience(forceRefresh: true);
      if (mounted) {
        showMessage(context, "Experience deleted successfully!");
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to delete: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteInternship(String id, String role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("Delete Internship"),
        content: Text("Are you sure you want to delete \"$role\" internship?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      await UserService.deleteInternship(id);
      await _loadExperience(forceRefresh: true);
      if (mounted) {
        showMessage(context, "Internship deleted successfully!");
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to delete: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ FIXED: Properly working toggle with cache busting
  Future<void> _toggleFresherMode(bool value) async {
    if (!mounted) return;
    
    debugPrint("🔄 Toggle called with value: $value");
    debugPrint("🔄 Current _isFresher: $_isFresher");
    
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      if (value) {
        // ========== SWITCHING TO FRESHER MODE ==========
        debugPrint("🔄 Switching to Fresher Mode...");
        
        // Step 1: Save any existing fresher data
        if (_internshipDetailsCtrl.text.isNotEmpty ||
            _trainingProgramCtrl.text.isNotEmpty ||
            _dailyWageCtrl.text.isNotEmpty ||
            _projectsDoneCtrl.text.isNotEmpty ||
            _certificationsCtrl.text.isNotEmpty) {
          await _saveFresher();
          debugPrint("✅ Fresher data saved before switching");
        }
        
        // Step 2: Update server to fresher mode
        await UserService.updateFresherStatus({'is_fresher': true});
        debugPrint("✅ Server updated to Fresher Mode");
        
        // ✅ Step 3: Reload data with force refresh to bust cache
        await _loadExperience(forceRefresh: true);
        
        if (mounted) {
          showMessage(
            context,
            "✅ Switched to Fresher Mode. Please provide your basic information.",
          );
        }
      } else {
        // ========== SWITCHING TO EXPERIENCED MODE ==========
        debugPrint("🔄 Switching to Experienced Mode...");
        
        // Step 1: Save any fresher data before switching
        if (_internshipDetailsCtrl.text.isNotEmpty ||
            _trainingProgramCtrl.text.isNotEmpty ||
            _dailyWageCtrl.text.isNotEmpty ||
            _projectsDoneCtrl.text.isNotEmpty ||
            _certificationsCtrl.text.isNotEmpty) {
          await _saveFresher();
          debugPrint("✅ Fresher data saved before switching");
        }
        
        // Step 2: Update server to experienced mode (is_fresher = false)
        await UserService.updateFresherStatus({'is_fresher': false});
        debugPrint("✅ Server updated to Experienced Mode (is_fresher: false)");
        
        // Step 3: Clear fresher data from UI
        _internshipDetailsCtrl.clear();
        _trainingProgramCtrl.clear();
        _dailyWageCtrl.clear();
        _projectsDoneCtrl.clear();
        _certificationsCtrl.clear();
        
        // ✅ Step 4: Reload data with force refresh to bust cache
        await _loadExperience(forceRefresh: true);
        
        if (mounted) {
          showMessage(
            context,
            "✅ Switched to Experienced Mode. You can now add work experience and internships.",
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error switching mode: $e");
      if (mounted) {
        showMessage(context, "Failed to switch mode: $e", isError: true);
      }
      // Revert the toggle state on error
      if (mounted) {
        setState(() {
          _isFresher = !value;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      ctrl.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  String _formatDuration(String? startDate, String? endDate) {
    if (startDate == null || startDate.isEmpty) return '';
    try {
      final start = DateTime.parse(startDate);
      final end = endDate != null && endDate.isNotEmpty
          ? DateTime.parse(endDate)
          : DateTime.now();
      final years = end.year - start.year;
      final months = end.month - start.month;

      if (years > 0) {
        return "$years yr${years > 1 ? 's' : ''} ${months > 0 ? '$months mon' : ''}";
      } else if (months > 0) {
        return "$months month${months > 1 ? 's' : ''}";
      } else {
        final days = end.difference(start).inDays;
        return "$days day${days > 1 ? 's' : ''}";
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildFresherToggle(),
                const SizedBox(height: 24),
                if (!_isFresher) ...[
                  _buildTabSelector(),
                  const SizedBox(height: 20),
                  if (_activeTabIndex == 0)
                    _buildWorkExperienceTab()
                  else
                    _buildInternshipTab(),
                ] else ...[
                  _buildFresherSection(),
                ],
                const SizedBox(height: 16),
                _buildInfoNote(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== AI-BASED DESIGN COMPONENTS ====================

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
                  "AI is loading your experience...",
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

  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
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
            child: const Icon(
              Icons.work_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Experience Details",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isFresher 
                      ? "Add your skills and training information"
                      : "Add your work experience and internships",
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

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
    );
  }

  // ==================== AI TEXT FIELD ====================

  Widget _buildAITextField(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
    int maxLines = 1,
    String? hintText,
    IconData? prefixIcon,
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

  // ==================== AI DROPDOWN ====================

  Widget _buildAIDropdown<T>(
    T? value,
    List<T> items,
    String label, {
    void Function(T?)? onChanged,
    bool required = false,
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
        child: DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Icon(
              Icons.arrow_drop_down,
              color: Colors.grey.shade600,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: const TextStyle(color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
          validator: (value) => required && value == null ? "Required" : null,
        ),
      ),
    );
  }

  // ==================== DATE FIELD ====================

  Widget _buildAIDateField(
    TextEditingController ctrl,
    String label, {
    bool enabled = true,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
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
          readOnly: true,
          enabled: enabled,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(
              color: enabled ? Colors.grey.shade700 : Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(Icons.calendar_today,
                color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Icon(Icons.event,
                color: enabled ? Colors.grey.shade400 : Colors.grey.shade300,
                size: 18),
          ),
          onTap: enabled ? () => _pickDate(ctrl) : null,
          validator: (value) => required && (value == null || value.isEmpty) ? "Required" : null,
        ),
      ),
    );
  }

  // ==================== FRESHER TOGGLE ====================

  Widget _buildFresherToggle() {
    final isFresher = _isFresher;
    return _buildGlassContainer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isFresher
                      ? Colors.green.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFresher ? Icons.school : Icons.work,
                  color: isFresher ? Colors.green.shade700 : Colors.blue.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFresher ? "Fresher Mode" : "Experienced Mode",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isFresher ? Colors.green.shade900 : Colors.blue.shade900,
                    ),
                  ),
                  Text(
                    isFresher
                        ? "No work experience yet - Add your skills and training"
                        : "Add your work experience, internships, and professional details",
                    style: TextStyle(
                      fontSize: 12,
                      color: isFresher ? Colors.green.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isFresher
                  ? Colors.green.shade100
                  : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(30),
              boxShadow: isFresher
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: isFresher,
                onChanged: (value) {
                  debugPrint("🔄 Switch tapped! New value: $value");
                  _toggleFresherMode(value);
                },
                activeColor: Colors.white,
                activeTrackColor: Colors.green,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB SELECTOR ====================

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTabItem("Work Experience", 0, _experienceList.length, Colors.blue),
          _buildTabItem("Internships", 1, _internshipList.length, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index, int count, Color color) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                index == 0 ? Icons.work : Icons.business_center,
                color: isSelected ? color : Colors.grey.shade600,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== WORK EXPERIENCE TAB ====================

  Widget _buildWorkExperienceTab() {
    return Column(
      children: [
        _buildWorkExperienceForm(),
        const SizedBox(height: 24),
        _buildWorkExperienceList(),
      ],
    );
  }

  Widget _buildWorkExperienceForm() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            _editingId == null ? "Add Work Experience" : "Edit Work Experience",
            _editingId == null ? Icons.add_circle_outline : Icons.edit,
          ),
          _buildAITextField(
            _companyCtrl,
            "Company Name",
            required: true,
            prefixIcon: Icons.business,
          ),
          _buildAITextField(
            _roleCtrl,
            "Job Role / Designation",
            required: true,
            prefixIcon: Icons.work,
          ),
          _buildAITextField(
            _industryCtrl,
            "Industry Type",
            prefixIcon: Icons.factory,
          ),
          _buildAIDropdown<String>(
            _employmentType,
            _employmentTypes,
            "Employment Type",
            onChanged: (v) {
              if (v != null) setState(() => _employmentType = v);
            },
          ),
          _buildAITextField(
            _workTypeCtrl,
            "Work Type (e.g., Remote, Onsite, Hybrid)",
            prefixIcon: Icons.location_city,
          ),
          _buildAITextField(
            _locationCtrl,
            "Work Location",
            prefixIcon: Icons.location_on,
          ),
          _buildAITextField(
            _salaryCtrl,
            "Monthly Salary (₹)",
            keyboardType: TextInputType.number,
            prefixIcon: Icons.currency_rupee,
          ),
          Row(
            children: [
              Expanded(
                child: _buildAIDateField(
                  _startDateCtrl,
                  "Start Date",
                  required: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAIDateField(
                  _endDateCtrl,
                  "End Date",
                  enabled: !_isCurrent,
                ),
              ),
            ],
          ),
          _buildSwitchTile(
            value: _isCurrent,
            onChanged: (v) => setState(() => _isCurrent = v),
            title: "Currently working here",
            color: Colors.blue,
          ),
          _buildAITextField(
            _descriptionCtrl,
            "Job Description",
            maxLines: 3,
            prefixIcon: Icons.description,
          ),
          _buildAITextField(
            _achievementsCtrl,
            "Key Achievements (one per line)",
            maxLines: 3,
            prefixIcon: Icons.emoji_events,
          ),
          _buildAITextField(
            _skillsCtrl,
            "Skills Used (comma separated)",
            prefixIcon: Icons.build,
          ),
          if (!_isCurrent)
            _buildAITextField(
              _reasonForLeaveCtrl,
              "Reason for Leaving",
              prefixIcon: Icons.exit_to_app,
            ),
          _buildAITextField(
            _reportingManagerCtrl,
            "Reporting Manager Name",
            prefixIcon: Icons.people,
          ),
          _buildAITextField(
            _teamSizeCtrl,
            "Team Size",
            keyboardType: TextInputType.number,
            prefixIcon: Icons.group,
          ),
          const SizedBox(height: 20),
          _buildActionButtons(
            onSave: _saveExperience,
            onCancel: _editingId != null ? _clearExperienceForm : null,
            isSaving: _isSaving,
            saveLabel: _editingId == null ? "Add Experience" : "Update Experience",
            buttonColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkExperienceList() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Your Work Experience",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_experienceList.length} Records",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_experienceList.isEmpty)
            _buildEmptyState(
              icon: Icons.work_off,
              title: "No work experience added yet",
              subtitle: "Add your work experience using the form above",
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _experienceList.length,
              itemBuilder: (context, index) {
                final exp = _experienceList[index];
                return _buildExperienceCard(exp, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExperienceCard(Map<String, dynamic> exp, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            (index + 1).toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
        ),
        title: Text(
          exp['role'] ?? '',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exp['company'] ?? '', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text(
              "${exp['start_date']} - ${exp['end_date'] ?? 'Present'} (${_formatDuration(exp['start_date'], exp['end_date'])})",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
                onPressed: () => _startEditExperience(exp),
                tooltip: "Edit Experience",
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
                onPressed: () =>
                    _deleteExperience(exp['_id'], exp['role'] ?? 'Experience'),
                tooltip: "Delete Experience",
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exp['location'] != null && exp['location'].toString().isNotEmpty)
                  _buildDetailRow(Icons.location_on, "Location", exp['location']),
                if (exp['employment_type'] != null && exp['employment_type'].toString().isNotEmpty)
                  _buildDetailRow(Icons.business_center, "Employment Type", exp['employment_type']),
                if (exp['salary'] != null)
                  _buildDetailRow(Icons.currency_rupee, "Salary", "₹${exp['salary']}"),
                if (exp['description'] != null && exp['description'].toString().isNotEmpty)
                  _buildDetailRow(Icons.description, "Description", exp['description'], isLongText: true),
                if (exp['achievements'] != null && (exp['achievements'] as List).isNotEmpty)
                  _buildListRow(Icons.emoji_events, "Achievements", exp['achievements']),
                if (exp['skills_used'] != null && (exp['skills_used'] as List).isNotEmpty)
                  _buildChipRow("Skills Used", exp['skills_used']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== INTERNSHIP TAB ====================

  Widget _buildInternshipTab() {
    return Column(
      children: [
        _buildInternshipForm(),
        const SizedBox(height: 24),
        _buildInternshipList(),
      ],
    );
  }

  Widget _buildInternshipForm() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            _editingInternshipId == null ? "Add Internship" : "Edit Internship",
            _editingInternshipId == null ? Icons.add_circle_outline : Icons.edit,
          ),
          _buildAITextField(
            _internshipCompanyCtrl,
            "Company Name",
            required: true,
            prefixIcon: Icons.business,
          ),
          _buildAITextField(
            _internshipRoleCtrl,
            "Internship Role",
            required: true,
            prefixIcon: Icons.work,
          ),
          Row(
            children: [
              Expanded(
                child: _buildAIDateField(
                  _internshipStartDateCtrl,
                  "Start Date",
                  required: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAIDateField(
                  _internshipEndDateCtrl,
                  "End Date",
                  enabled: !_isCurrentInternship,
                ),
              ),
            ],
          ),
          _buildSwitchTile(
            value: _isCurrentInternship,
            onChanged: (v) => setState(() => _isCurrentInternship = v),
            title: "Currently ongoing",
            color: Colors.orange,
          ),
          _buildAITextField(
            _internshipDescriptionCtrl,
            "Internship Description",
            maxLines: 3,
            prefixIcon: Icons.description,
          ),
          _buildAITextField(
            _internshipStipendCtrl,
            "Stipend (₹)",
            keyboardType: TextInputType.number,
            prefixIcon: Icons.currency_rupee,
          ),
          _buildAITextField(
            _internshipSkillsCtrl,
            "Technologies/Skills Learned (comma separated)",
            prefixIcon: Icons.computer,
          ),
          const SizedBox(height: 20),
          _buildActionButtons(
            onSave: _saveExperience,
            onCancel: _editingInternshipId != null ? _clearInternshipForm : null,
            isSaving: _isSaving,
            saveLabel: _editingInternshipId == null ? "Add Internship" : "Update Internship",
            buttonColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildInternshipList() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Your Internships",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_internshipList.length} Records",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_internshipList.isEmpty)
            _buildEmptyState(
              icon: Icons.business_center,
              title: "No internships added yet",
              subtitle: "Add your internship using the form above",
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _internshipList.length,
              itemBuilder: (context, index) {
                final intern = _internshipList[index];
                return _buildInternshipCard(intern, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInternshipCard(Map<String, dynamic> intern, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            (index + 1).toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ),
        title: Text(
          intern['role'] ?? '',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(intern['company'] ?? '', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text(
              "${intern['start_date']} - ${intern['end_date'] ?? 'Present'} (${_formatDuration(intern['start_date'], intern['end_date'])})",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (intern['stipend'] != null)
              Text(
                "Stipend: ₹${intern['stipend']}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade700,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.edit, color: Colors.orange.shade700, size: 20),
                onPressed: () => _startEditInternship(intern),
                tooltip: "Edit Internship",
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
                onPressed: () =>
                    _deleteInternship(intern['_id'], intern['role'] ?? 'Internship'),
                tooltip: "Delete Internship",
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FRESHER SECTION ====================

  Widget _buildFresherSection() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Fresher / Entry Level Information", Icons.school),
          Text(
            "Tell us about your skills and training",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          _buildAITextField(
            _internshipDetailsCtrl,
            "Internship Details (if any)",
            maxLines: 2,
            prefixIcon: Icons.school,
          ),
          _buildAITextField(
            _trainingProgramCtrl,
            "Training Programs Completed",
            maxLines: 2,
            prefixIcon: Icons.assignment,
          ),
          _buildAITextField(
            _dailyWageCtrl,
            "Daily Wage Experience (₹/day)",
            keyboardType: TextInputType.number,
            prefixIcon: Icons.currency_rupee,
          ),
          _buildAITextField(
            _projectsDoneCtrl,
            "Projects Done",
            maxLines: 2,
            prefixIcon: Icons.code,
          ),
          _buildAITextField(
            _certificationsCtrl,
            "Certifications (comma separated)",
            prefixIcon: Icons.verified,
          ),
          _buildAIDropdown<String>(
            _labourType,
            _labourTypes,
            "Work Type (Labour/Skilled)",
            onChanged: (v) {
              if (v != null) setState(() => _labourType = v);
            },
          ),
          const SizedBox(height: 20),
          _buildActionButtons(
            onSave: _saveFresher,
            isSaving: _isSaving,
            saveLabel: "Save Fresher Information",
            buttonColor: Colors.green,
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildActionButtons({
    required VoidCallback onSave,
    VoidCallback? onCancel,
    required bool isSaving,
    required String saveLabel,
    required Color buttonColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [buttonColor, buttonColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          saveLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (onCancel != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSwitchTile({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: color,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isLongText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, height: isLongText ? 1.4 : 1.2, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListRow(IconData icon, String label, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• ", style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                          Expanded(
                            child: Text(
                              item.toString(),
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipRow(String label, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items
                  .map(
                    (skill) => Chip(
                      label: Text(
                        skill.toString(),
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                      ),
                      backgroundColor: Colors.blue.shade50,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Toggle the switch to switch between Fresher and Experienced mode. "
              "Your data is automatically saved when switching modes.",
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }
}