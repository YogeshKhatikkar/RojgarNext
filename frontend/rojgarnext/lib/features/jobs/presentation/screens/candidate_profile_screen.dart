// lib/features/jobs/presentation/screens/candidate_profile_screen.dart
// Complete Candidate Profile Screen - Text Selection Only (No Copy Icons) + Print Option

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CandidateProfileScreen extends StatefulWidget {
  final String email;
  final String candidateName;
  final VoidCallback? onBack;

  const CandidateProfileScreen({
    super.key,
    required this.email,
    required this.candidateName,
    this.onBack,
  });

  @override
  State<CandidateProfileScreen> createState() => _CandidateProfileScreenState();
}

class _CandidateProfileScreenState extends State<CandidateProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profile = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint("📋 Fetching candidate profile for email: ${widget.email}");

      final response = await DioClient.dio.get(
        '/user/user-profile-by-email?email=${widget.email}',
      );

      if (!mounted) return;

      if (response.data is Map) {
        final data = response.data;
        if (data.containsKey('data') && data['data'] is Map) {
          _profile = data['data'];
        } else {
          _profile = data;
        }
      }

      debugPrint("📋 Profile fetched successfully");
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Error fetching profile: $e");
      setState(() {
        _errorMessage = e.toString();
      });
      showMessage(context, "Failed to load profile: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==================== PRINT PROFILE ====================
  Future<void> _printProfile() async {
    try {
      // Generate PDF
      final pdf = await _generatePdf();

      // Share/Print the PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'Candidate_Profile_${widget.candidateName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error printing: ${e.toString().substring(0, 100)}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    // Personal Information
    final fullName = _getString('full_name');
    final email = widget.email;
    final phone = _getString('phone');
    final dob = _getString('dob');
    final gender = _getString('gender');
    final category = _getString('category');

    // Address
    final address = _profile['current_address'] as Map? ?? {};
    final village = address['village_name'] ?? '';
    final district = address['district'] ?? '';
    final state = address['state'] ?? '';
    final pincode = address['pincode'] ?? '';

    // Disability
    final disability = _profile['disability'] as Map? ?? {};
    final isDisabled =
        disability['is_disabled'] == true || _profile['is_disable'] == true;
    final disabilityCategory = disability['disability_category'] ??
        _profile['disability_category'] ??
        '';
    final disabilityPercentage = disability['disability_percentage'] ??
        _profile['disability_percentage'];
    final disabilityDetails = disability['disability_details'] ?? '';

    // Education
    final educationList = _getList('academic_records');

    // Experience
    final experienceList = _getList('experience');

    // Skills
    final skillsList = _getList('skills');

    // Certifications
    final certList = _getList('certifications');

    // Projects
    final projectList = _getList('projects');

    // Languages
    final languagesKnown = _getList('languages_known');

    // Summary
    final summary = _getString('summary');
    final careerObjective = _getString('career_objective');

    // Social Links
    final social = _profile['social_links'] as Map? ?? {};
    final linkedin = social['linkedin'] ?? '';
    final github = social['github'] ?? '';
    final portfolio = social['portfolio'] ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    fullName,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Candidate Profile - RojgarNext Job Portal',
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Divider(thickness: 2, color: PdfColors.blue),
            pw.SizedBox(height: 20),

            // Personal Information
            pw.Text(
              '📋 Personal Information',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPdfRow('Full Name:', fullName),
                  _buildPdfRow('Email:', email),
                  _buildPdfRow(
                      'Phone:', phone.isNotEmpty ? phone : 'Not provided'),
                  _buildPdfRow(
                      'Date of Birth:', dob.isNotEmpty ? dob : 'Not provided'),
                  _buildPdfRow(
                      'Gender:', gender.isNotEmpty ? gender : 'Not provided'),
                  _buildPdfRow('Category:',
                      category.isNotEmpty ? category : 'Not provided'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Address
            if (village.isNotEmpty || district.isNotEmpty || state.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '📍 Address',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (village.isNotEmpty)
                          _buildPdfRow('Village/City:', village),
                        if (district.isNotEmpty)
                          _buildPdfRow('District:', district),
                        if (state.isNotEmpty) _buildPdfRow('State:', state),
                        if (pincode.isNotEmpty)
                          _buildPdfRow('Pincode:', pincode),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Disability Information
            if (isDisabled)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '♿ Disability Information',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfRow('Status:', 'Yes'),
                        if (disabilityCategory.isNotEmpty)
                          _buildPdfRow('Category:', disabilityCategory),
                        if (disabilityPercentage != null)
                          _buildPdfRow('Percentage:', '$disabilityPercentage%'),
                        if (disabilityDetails.isNotEmpty)
                          _buildPdfRow('Details:', disabilityDetails),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Education
            if (educationList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🎓 Education',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  ...educationList.map((edu) => pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              edu['degree'] ?? edu['level'] ?? 'Education',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 14),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                                '🏛️ ${edu['institute'] ?? ''} | Passing Year: ${edu['year_of_passing'] ?? ''}'),
                            if (edu['cgpa_percentage'] != null)
                              pw.Text(
                                  '${edu['result_type'] ?? 'Score'}: ${edu['cgpa_percentage']}'),
                            if (edu['board_university'] != null &&
                                edu['board_university'].toString().isNotEmpty)
                              pw.Text(
                                  'Board/University: ${edu['board_university']}'),
                          ],
                        ),
                      )),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Work Experience
            if (experienceList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '💼 Work Experience',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  ...experienceList.map((exp) => pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              exp['role'] ?? 'Position',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 14),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text('🏢 ${exp['company'] ?? ''}'),
                            pw.Text(
                                '📅 ${exp['start_date'] ?? ''} - ${exp['end_date'] ?? 'Present'}'),
                            if (exp['description'] != null &&
                                exp['description'].toString().isNotEmpty)
                              pw.Text(exp['description']),
                          ],
                        ),
                      )),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Skills
            if (skillsList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '⚡ Skills',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: skillsList.map((skill) {
                      final skillName = skill is Map ? skill['name'] : skill;
                      return pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(skillName.toString(),
                            style: pw.TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Certifications
            if (certList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '📜 Certifications',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: certList.map((cert) {
                      final certName = cert is Map ? cert['name'] : cert;
                      return pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.purple50,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(certName.toString(),
                            style: pw.TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Projects
            if (projectList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🛠️ Projects',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  ...projectList.map((proj) => pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              proj['title'] ?? 'Project',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 14),
                            ),
                            if (proj['description'] != null &&
                                proj['description'].toString().isNotEmpty)
                              pw.Text(proj['description']),
                            if (proj['technologies'] != null &&
                                (proj['technologies'] as List).isNotEmpty)
                              pw.Text(
                                  'Technologies: ${(proj['technologies'] as List).join(', ')}'),
                          ],
                        ),
                      )),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Languages
            if (languagesKnown.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🌐 Languages',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: languagesKnown
                        .map((lang) => pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.cyan50,
                                borderRadius: pw.BorderRadius.circular(20),
                              ),
                              child: pw.Text(lang.toString(),
                                  style: pw.TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Professional Summary
            if (summary.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '📝 Professional Summary',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(summary,
                        style: pw.TextStyle(fontSize: 12, height: 1.5)),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Career Objective
            if (careerObjective.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🎯 Career Objective',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(careerObjective,
                        style: pw.TextStyle(fontSize: 12, height: 1.5)),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Social Links
            if (linkedin.isNotEmpty ||
                github.isNotEmpty ||
                portfolio.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🔗 Social & Professional Links',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (linkedin.isNotEmpty)
                          _buildPdfRow('LinkedIn:', linkedin),
                        if (github.isNotEmpty) _buildPdfRow('GitHub:', github),
                        if (portfolio.isNotEmpty)
                          _buildPdfRow('Portfolio:', portfolio),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),

            // Footer
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Generated by RojgarNext on ${DateTime.now().toString().split(' ')[0]}\nThis is an official document from RojgarNext Job Portal',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    // AppBar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Back Button
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.blueAccent),
                            onPressed: () {
                              if (widget.onBack != null) {
                                widget.onBack!();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            tooltip: "Back to Dashboard",
                          ),
                          const SizedBox(width: 8),
                          // Title
                          Expanded(
                            child: Text(
                              widget.candidateName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Print Button
                          Tooltip(
                            message: "Print Profile",
                            child: IconButton(
                              icon: const Icon(Icons.print,
                                  color: Colors.blueAccent),
                              onPressed: _printProfile,
                            ),
                          ),
                          // Refresh Button
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                color: Colors.blueAccent),
                            onPressed: _fetchProfile,
                            tooltip: "Refresh",
                          ),
                        ],
                      ),
                    ),
                    // Profile Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderCard(),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: "Personal Information",
                              icon: Icons.person,
                              color: Colors.blue,
                              children: [
                                _buildSelectableInfoRow(
                                  Icons.person_outline,
                                  "Full Name",
                                  _getString('full_name'),
                                ),
                                _buildDivider(),
                                _buildSelectableInfoRow(
                                  Icons.email,
                                  "Email",
                                  widget.email,
                                ),
                                _buildDivider(),
                                _buildSelectableInfoRow(
                                  Icons.phone,
                                  "Phone",
                                  _getString('phone'),
                                ),
                                _buildDivider(),
                                _buildSelectableInfoRow(
                                  Icons.cake,
                                  "Date of Birth",
                                  _getString('dob'),
                                ),
                                _buildDivider(),
                                _buildSelectableInfoRow(
                                  Icons.wc,
                                  "Gender",
                                  _getString('gender'),
                                ),
                                _buildDivider(),
                                _buildSelectableInfoRow(
                                  Icons.category,
                                  "Category",
                                  _getString('category'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildDisabilityCard(),
                            const SizedBox(height: 16),
                            _buildAddressCard(),
                            const SizedBox(height: 16),
                            if (_getList('academic_records').isNotEmpty)
                              _buildEducationSection(),
                            if (_getList('academic_records').isNotEmpty)
                              const SizedBox(height: 16),
                            if (_getList('experience').isNotEmpty)
                              _buildExperienceSection(),
                            if (_getList('experience').isNotEmpty)
                              const SizedBox(height: 16),
                            if (_getList('skills').isNotEmpty)
                              _buildSkillsSection(),
                            if (_getList('skills').isNotEmpty)
                              const SizedBox(height: 16),
                            if (_getList('certifications').isNotEmpty)
                              _buildCertificationsSection(),
                            if (_getList('certifications').isNotEmpty)
                              const SizedBox(height: 16),
                            if (_getList('projects').isNotEmpty)
                              _buildProjectsSection(),
                            if (_getList('projects').isNotEmpty)
                              const SizedBox(height: 16),
                            if (_getList('languages_known').isNotEmpty ||
                                _getList('languages').isNotEmpty)
                              _buildLanguagesSection(),
                            if (_getList('languages_known').isNotEmpty ||
                                _getList('languages').isNotEmpty)
                              const SizedBox(height: 16),
                            if (_getString('summary').isNotEmpty)
                              _buildSectionCard(
                                title: "Professional Summary",
                                icon: Icons.description,
                                color: Colors.grey,
                                children: [
                                  _buildSelectableText(_getString('summary')),
                                ],
                              ),
                            if (_getString('summary').isNotEmpty)
                              const SizedBox(height: 16),
                            if (_getString('career_objective').isNotEmpty)
                              _buildSectionCard(
                                title: "Career Objective",
                                icon: Icons.track_changes,
                                color: Colors.amber,
                                children: [
                                  _buildSelectableText(
                                      _getString('career_objective')),
                                ],
                              ),
                            if (_getString('career_objective').isNotEmpty)
                              const SizedBox(height: 16),
                            if (_hasSocialLinks()) _buildSocialLinksCard(),
                            if (_hasSocialLinks()) const SizedBox(height: 16),
                            if (_getString('resume_url').isNotEmpty)
                              _buildResumeCard(),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ==================== SELECTABLE INFO ROW (No Copy Icon) ====================
  Widget _buildSelectableInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty || value == 'null') {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SELECTABLE TEXT (No Copy Icon) ====================
  Widget _buildSelectableText(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(height: 1.5),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            "Failed to load profile",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SelectableText(
              _errorMessage ?? "Unknown error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchProfile,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withAlpha(51),
            child: Text(
              _getString('full_name').isNotEmpty
                  ? _getString('full_name')[0].toUpperCase()
                  : widget.candidateName.isNotEmpty
                      ? widget.candidateName[0].toUpperCase()
                      : 'U',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  _getString('full_name').isNotEmpty
                      ? _getString('full_name')
                      : widget.candidateName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  widget.email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
                if (_getString('phone').isNotEmpty)
                  SelectableText(
                    _getString('phone'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withAlpha(204),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1),
    );
  }

  Widget _buildDisabilityCard() {
    final disability = _profile['disability'] as Map? ?? {};
    final isDisabled =
        disability['is_disabled'] == true || _profile['is_disable'] == true;
    final disabilityCategory = disability['disability_category'] ??
        _profile['disability_category'] ??
        'Not specified';
    final disabilityPercentage = disability['disability_percentage'] ??
        _profile['disability_percentage'];

    if (!isDisabled && disabilityCategory == 'Not specified') {
      return const SizedBox();
    }

    return _buildSectionCard(
      title: "Disability Information",
      icon: Icons.accessible,
      color: Colors.orange,
      children: [
        _buildSelectableInfoRow(
          Icons.accessible,
          "Status",
          isDisabled ? "Yes" : "No",
        ),
        if (isDisabled) ...[
          _buildDivider(),
          _buildSelectableInfoRow(
            Icons.category,
            "Category",
            disabilityCategory,
          ),
          if (disabilityPercentage != null) ...[
            _buildDivider(),
            _buildSelectableInfoRow(
              Icons.percent,
              "Percentage",
              "$disabilityPercentage%",
            ),
          ],
          if (disability['disability_details'] != null &&
              disability['disability_details'].toString().isNotEmpty)
            Column(
              children: [
                _buildDivider(),
                _buildSelectableInfoRow(
                  Icons.description,
                  "Details",
                  disability['disability_details'],
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildAddressCard() {
    final address = _profile['current_address'] as Map? ?? {};
    final hasAddress = address['district'] != null ||
        address['state'] != null ||
        address['village_name'] != null;

    if (!hasAddress) {
      return const SizedBox();
    }

    return _buildSectionCard(
      title: "Current Address",
      icon: Icons.location_on,
      color: Colors.green,
      children: [
        if (address['village_name'] != null &&
            address['village_name'].toString().isNotEmpty)
          _buildSelectableInfoRow(
            Icons.location_city,
            "Village/City",
            address['village_name'],
          ),
        if (address['district'] != null &&
            address['district'].toString().isNotEmpty)
          _buildSelectableInfoRow(
            Icons.map,
            "District",
            address['district'],
          ),
        if (address['state'] != null && address['state'].toString().isNotEmpty)
          _buildSelectableInfoRow(
            Icons.location_on,
            "State",
            address['state'],
          ),
        if (address['pincode'] != null &&
            address['pincode'].toString().isNotEmpty)
          _buildSelectableInfoRow(
            Icons.pin_drop,
            "Pincode",
            address['pincode'],
          ),
        if (address['country'] != null &&
            address['country'].toString().isNotEmpty &&
            address['country'] != 'India')
          _buildSelectableInfoRow(
            Icons.public,
            "Country",
            address['country'],
          ),
      ],
    );
  }

  Widget _buildEducationSection() {
    final educationList = _getList('academic_records');

    return _buildSectionCard(
      title: "Education",
      icon: Icons.school,
      color: Colors.purple,
      children: educationList.map((edu) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edu['degree'] ?? edu['level'] ?? 'Education',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (edu['institute'] != null &&
                          edu['institute'].toString().isNotEmpty)
                        Text(
                          "🏛️ ${edu['institute']}",
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (edu['board_university'] != null &&
                          edu['board_university'].toString().isNotEmpty)
                        Text(
                          "📚 ${edu['board_university']}",
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Year: ${edu['year_of_passing']}",
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (edu['cgpa_percentage'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${edu['result_type'] ?? 'Score'}: ${edu['cgpa_percentage']}",
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (educationList.indexOf(edu) != educationList.length - 1)
              const Divider(),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildExperienceSection() {
    final experienceList = _getList('experience');

    return _buildSectionCard(
      title: "Work Experience",
      icon: Icons.work,
      color: Colors.orange,
      children: experienceList.map((exp) {
        final duration = _calculateDuration(
          exp['start_date'],
          exp['end_date'],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp['role'] ?? 'Position',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "🏢 ${exp['company']}",
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        "📅 ${exp['start_date']} - ${exp['end_date'] ?? 'Present'} ($duration)",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (exp['description'] != null &&
                          exp['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SelectableText(
                            exp['description'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (experienceList.indexOf(exp) != experienceList.length - 1)
              const Divider(),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSkillsSection() {
    final skillsList = _getList('skills');

    return _buildSectionCard(
      title: "Skills",
      icon: Icons.build,
      color: Colors.red,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: skillsList.map((skill) {
            final skillName = skill is Map ? skill['name'] : skill;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                skillName.toString(),
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
        ),
        if (skillsList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "💡 Tip: Press and hold any text to select and copy",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCertificationsSection() {
    final certList = _getList('certifications');

    return _buildSectionCard(
      title: "Certifications",
      icon: Icons.verified,
      color: Colors.deepPurple,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: certList.map((cert) {
            final certName = cert is Map ? cert['name'] : cert;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Text(
                certName.toString(),
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProjectsSection() {
    final projectList = _getList('projects');

    return _buildSectionCard(
      title: "Projects",
      icon: Icons.code,
      color: Colors.indigo,
      children: projectList.map((proj) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proj['title'] ?? 'Project',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (proj['description'] != null &&
                          proj['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SelectableText(
                            proj['description'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (proj['technologies'] != null &&
                          (proj['technologies'] as List).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            children: (proj['technologies'] as List)
                                .map((tech) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        tech.toString(),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (projectList.indexOf(proj) != projectList.length - 1)
              const Divider(),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLanguagesSection() {
    final languagesKnown = _getList('languages_known');
    final languages = _getList('languages');

    if (languagesKnown.isEmpty && languages.isEmpty) {
      return const SizedBox();
    }

    return _buildSectionCard(
      title: "Languages",
      icon: Icons.language,
      color: Colors.cyan,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...languagesKnown.map((lang) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.cyan.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.cyan.shade200),
                  ),
                  child: Text(
                    lang.toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                )),
            ...languages.map((lang) {
              final langName = lang is Map ? lang['name'] : lang;
              final proficiency = lang is Map ? lang['proficiency'] : null;
              final langText = proficiency != null
                  ? "$langName ($proficiency)"
                  : langName.toString();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyan.shade200),
                ),
                child: Text(
                  langText,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  bool _hasSocialLinks() {
    final social = _profile['social_links'] as Map? ?? {};
    return (social['linkedin'] != null &&
            social['linkedin'].toString().isNotEmpty) ||
        (social['github'] != null && social['github'].toString().isNotEmpty) ||
        (social['portfolio'] != null &&
            social['portfolio'].toString().isNotEmpty);
  }

  Widget _buildSocialLinksCard() {
    final social = _profile['social_links'] as Map? ?? {};

    return _buildSectionCard(
      title: "Social & Professional Links",
      icon: Icons.link,
      color: Colors.blue,
      children: [
        if (social['linkedin'] != null &&
            social['linkedin'].toString().isNotEmpty)
          _buildSelectableLinkTile(
            Icons.linked_camera,
            "LinkedIn",
            social['linkedin'],
          ),
        if (social['github'] != null && social['github'].toString().isNotEmpty)
          _buildSelectableLinkTile(
            Icons.code,
            "GitHub",
            social['github'],
          ),
        if (social['portfolio'] != null &&
            social['portfolio'].toString().isNotEmpty)
          _buildSelectableLinkTile(
            Icons.web,
            "Portfolio",
            social['portfolio'],
          ),
      ],
    );
  }

  Widget _buildSelectableLinkTile(IconData icon, String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                SelectableText(
                  url,
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18, color: Colors.blue),
            onPressed: () async {
              final Uri uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            tooltip: "Open link",
          ),
        ],
      ),
    );
  }

  Widget _buildResumeCard() {
    final resumeUrl = _getString('resume_url');
    if (resumeUrl.isEmpty) {
      return const SizedBox();
    }

    return _buildSectionCard(
      title: "Resume / CV",
      icon: Icons.picture_as_pdf,
      color: Colors.red,
      children: [
        InkWell(
          onTap: () => _launchResume(resumeUrl),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, size: 40, color: Colors.red),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Resume Available",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                      SelectableText(
                        resumeUrl,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new, color: Colors.blue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "💡 Tip: Long press on any text to select and copy",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchResume(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          showMessage(context, "Could not open resume", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Error opening resume: $e", isError: true);
      }
    }
  }

  String _getString(String key) {
    final value = _profile[key];
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  List<dynamic> _getList(String key) {
    final value = _profile[key];
    if (value is List) return value;
    return [];
  }

  String _calculateDuration(String? startDate, String? endDate) {
    if (startDate == null) return 'N/A';
    try {
      final start = DateTime.parse(startDate);
      final end = endDate != null ? DateTime.parse(endDate) : DateTime.now();
      final years = end.year - start.year;
      final months = end.month - start.month;
      if (years > 0) {
        return "$years yr${years > 1 ? 's' : ''} ${months > 0 ? '$months mon' : ''}";
      }
      if (months > 0) {
        return "$months month${months > 1 ? 's' : ''}";
      }
      final days = end.difference(start).inDays;
      return "$days day${days > 1 ? 's' : ''}";
    } catch (e) {
      return 'N/A';
    }
  }
}
