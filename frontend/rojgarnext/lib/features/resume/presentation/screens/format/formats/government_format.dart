// lib/features/resume/presentation/screens/format/formats/government_format.dart
// ✅ GOVERNMENT — Navy + gold framed border + formal grid
// 🔧 Style changes: edit ONLY this file

import 'package:flutter/material.dart';
import '../resume_format_base.dart';

class GovernmentFormat extends ResumeFormatBase {
  @override String get id => 'government';
  @override String get name => 'Government / PSU';
  @override String get icon => '🏛️';
  @override String get description => 'Formal Government Layout';
  @override String get color => '#1A237E';
  @override String get styleKey => 'government';
  @override String get templateType => 'government';
  @override String get badgeText => 'Official';

  // ==================== COLORS ====================
  static const Color _navy = Color(0xFF1A237E);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _lightNavy = Color(0xFFE8EAF6);
  static const Color _border = Color(0xFFDDDDDD);
  static const Color _softBg = Color(0xFFFAFAFA);

  // ==========================================================================
  // HTML — unchanged
  // ==========================================================================
  @override
  String generateHtml(Map<String, dynamic> resumeData) {
    final name = getString(resumeData, 'user_info', 'full_name');
    final email = getString(resumeData, 'contact_info', 'email');
    final phone = getString(resumeData, 'contact_info', 'phone');
    final location = getLocation(resumeData);
    final education = getList(resumeData, 'education');
    final experience = getList(resumeData, 'experience');
    final skills = getSkills(resumeData);
    final certifications = getList(resumeData, 'certifications');
    final projects = getList(resumeData, 'projects');
    final languages = getList(resumeData, 'languages');
    final socialLinks = getMap(resumeData, 'social_links');

    final languagesHtml = languages.map((lang) {
      final n = lang['name']?.toString() ?? '';
      final p = lang['proficiency']?.toString() ?? '';
      return '<span class="skill-chip">${escapeHtml(p.isNotEmpty ? "$n - $p" : n)}</span>';
    }).join(' ');

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Times New Roman',serif;background:#f5f5f0;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;border:2px solid #1A237E;overflow:hidden}
.header{background:#1A237E;padding:35px 30px;color:#fff;text-align:center;border-bottom:3px solid #FFD700}
.name{font-size:34px;font-weight:bold;letter-spacing:1px}
.section{padding:22px 30px;border-bottom:1px solid #eee}
.section-title{font-size:18px;font-weight:bold;color:#1A237E;border-bottom:2px solid #FFD700;padding-bottom:8px;margin-bottom:16px}
.card-item{padding:12px 16px;margin-bottom:10px;border:1px solid #ddd;background:#fafafa}
.skill-chip{display:inline-block;background:#e8eaf6;color:#1A237E;padding:4px 12px;border-radius:15px;font-size:12px;margin:2px}
@media(max-width:768px){.section{padding:16px}.name{font-size:26px}}
</style></head><body>
<div class="resume-container">
<div class="header"><div class="name">${escapeHtml(name)}</div>
<div style="margin-top:15px;font-size:14px;display:flex;justify-content:center;flex-wrap:wrap;gap:20px;">
${email.isNotEmpty ? '<span>📧 ${escapeHtml(email)}</span>' : ''}
${phone.isNotEmpty ? '<span>📞 ${escapeHtml(phone)}</span>' : ''}
${location.isNotEmpty ? '<span>📍 ${escapeHtml(location)}</span>' : ''}
</div></div>
<div class="section"><div class="section-title">EDUCATION</div>
${education.map((edu) => '''
<div class="card-item"><div style="font-weight:bold;color:#1A237E;">${escapeHtml(edu['degree'])}</div>
<div>${escapeHtml(edu['institute'])}</div>
<div style="font-size:12px;color:#666;">Year: ${escapeHtml(edu['year_of_passing'].toString())}</div></div>
''').join('')}
</div>
<div class="section"><div class="section-title">EXPERIENCE</div>
${experience.map((exp) => '''
<div class="card-item"><div style="font-weight:bold;color:#1A237E;">${escapeHtml(exp['role'])}</div>
<div>${escapeHtml(exp['company'])}</div>
<div style="font-size:12px;color:#666;">${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</div>
${exp['description'].toString().isNotEmpty ? '<div style="margin-top:6px;font-size:13px;">${escapeHtml(exp['description'])}</div>' : ''}</div>
''').join('')}
</div>
<div class="section"><div class="section-title">SKILLS</div>
${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>
${buildCertificationsSection(certifications)}
${buildProjectsSection(projects)}
<div class="section"><div class="section-title">LANGUAGES</div>$languagesHtml</div>
${buildSocialSection(socialLinks)}
</div></body></html>''';
  }

  // ==========================================================================
  // ✅ NATIVE PREVIEW — edit ONLY this for style changes
  // ==========================================================================
  @override
  Widget buildPreview(BuildContext context, Map<String, dynamic> data) {
    final u = ResumeFormatBase.pMap(data['user_info']);
    final c = ResumeFormatBase.pMap(data['contact_info']);
    final name = ResumeFormatBase.pStr(u['full_name'], 'Your Name');
    final email = ResumeFormatBase.pStr(c['email']);
    final phone = ResumeFormatBase.pStr(c['phone']);
    final location = ResumeFormatBase.pLocation(data);
    final summary = ResumeFormatBase.pStr(data['professional_summary']);
    final objective = ResumeFormatBase.pStr(data['career_objective']);
    final exp = ResumeFormatBase.pList(data['experience']);
    final edu = ResumeFormatBase.pList(data['education']);
    final skills = ResumeFormatBase.pSkills(data['skills']);
    final certs = ResumeFormatBase.pList(data['certifications']);
    final projects = ResumeFormatBase.pList(data['projects']);
    final langs = ResumeFormatBase.pList(data['languages']);

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: _navy, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: _navy,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white)),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  height: 2,
                  width: 120,
                  color: _gold,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    if (email.isNotEmpty) _line('📧 $email'),
                    if (phone.isNotEmpty) _line('📞 $phone'),
                    if (location.isNotEmpty) _line('📍 $location'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('Professional Summary',
                      color: _navy,
                      uppercase: true,
                      underlineColor: _gold),
                  Text(summary,
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                  const SizedBox(height: 16),
                ],
                if (skills.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('Skills',
                      color: _navy,
                      uppercase: true,
                      underlineColor: _gold),
                  ResumeFormatBase.pChipsWrap(skills,
                      bg: _lightNavy,
                      fg: _navy,
                      border: _navy.withOpacity(0.25)),
                  const SizedBox(height: 16),
                ],
                if (exp.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('Work Experience',
                      color: _navy,
                      uppercase: true,
                      underlineColor: _gold),
                  ...exp.map((e) => _expCard(ResumeFormatBase.pMap(e))),
                  const SizedBox(height: 16),
                ],
                if (edu.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('Education',
                      color: _navy,
                      uppercase: true,
                      underlineColor: _gold),
                  ...edu.map((e) => _eduCard(ResumeFormatBase.pMap(e))),
                  const SizedBox(height: 16),
                ],
                if (certs.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('Certifications',
                      color: _navy,
                      uppercase: true,
                      underlineColor: _gold),
                  ...certs.map((x) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                            '• ${ResumeFormatBase.pCert(ResumeFormatBase.pMap(x))}',
                            style: const TextStyle(fontSize: 13)),
                      )),
                  const SizedBox(height: 16),
                ],
                if (projects.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('Projects',
                      color: _navy,
                      uppercase: true,
                      underlineColor: _gold),
                  ...projects.map((p) => _projCard(ResumeFormatBase.pMap(p))),
                  const SizedBox(height: 16),
                ],
                if (langs.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('Languages',
                      color: _navy,
                      uppercase: true,
                      underlineColor: _gold),
                  ResumeFormatBase.pChipsWrap(ResumeFormatBase.pLangs(langs),
                      bg: _lightNavy,
                      fg: _navy,
                      border: _navy.withOpacity(0.25)),
                  const SizedBox(height: 16),
                ],
                if (objective.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('Career Objective',
                      color: _navy,
                      uppercase: true,
                      underlineColor: _gold),
                  Text(objective,
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(t,
            style: const TextStyle(fontSize: 12, color: Colors.white)),
      );

  Widget _expCard(Map<String, dynamic> exp) => ResumeFormatBase.pCard(
        bg: _softBg,
        borderColor: _border,
        radius: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(exp['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(exp['company'], 'Company'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
            const SizedBox(height: 4),
            Text(
              '${ResumeFormatBase.pStr(exp['start_date'])} - ${ResumeFormatBase.pStr(exp['end_date'], 'Present')}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
            ),
            if (ResumeFormatBase.pStr(exp['description']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ResumeFormatBase.pStr(exp['description']),
                  style: const TextStyle(fontSize: 12, height: 1.4)),
            ],
          ],
        ),
      );

  Widget _eduCard(Map<String, dynamic> edu) => ResumeFormatBase.pCard(
        bg: _softBg,
        borderColor: _border,
        radius: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(edu['degree'], 'Degree'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(edu['institute'], 'Institute'),
                style: const TextStyle(fontSize: 12)),
            if (ResumeFormatBase.pStr(edu['year_of_passing']).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Year: ${edu['year_of_passing']}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF666666))),
            ],
          ],
        ),
      );

  Widget _projCard(Map<String, dynamic> p) => ResumeFormatBase.pCard(
        bg: _softBg,
        borderColor: _border,
        radius: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(p['title'], 'Project'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
            if (ResumeFormatBase.pStr(p['description']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ResumeFormatBase.pStr(p['description']),
                  style: const TextStyle(fontSize: 12, height: 1.4)),
            ],
          ],
        ),
      );
}