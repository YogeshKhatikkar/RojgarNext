// lib/features/resume/presentation/screens/format/formats/classic_format.dart
// ✅ CLASSIC — Blue gradient header + two-column + navy accents
// 🔧 Style changes: edit ONLY this file

import 'package:flutter/material.dart';
import '../resume_format_base.dart';

class ClassicFormat extends ResumeFormatBase {
  @override String get id => 'classic';
  @override String get name => 'Classic Professional';
  @override String get icon => '📄';
  @override String get description => 'Clean & Traditional Design';
  @override String get color => '#1E3A8A';
  @override String get styleKey => 'classic';
  @override String get templateType => 'classic';
  @override String get badgeText => 'Most Popular';

  // ==================== COLORS ====================
  static const Color _primary = Color(0xFF1E3A8A);
  static const Color _secondary = Color(0xFF3B82F6);
  static const Color _bg = Color(0xFFF8F8F8);
  static const Color _cardBg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF555555);

  // ==========================================================================
  // HTML (for PDF export & Copy HTML) — unchanged
  // ==========================================================================
  @override
  String generateHtml(Map<String, dynamic> resumeData) {
    final name = getString(resumeData, 'user_info', 'full_name');
    final email = getString(resumeData, 'contact_info', 'email');
    final phone = getString(resumeData, 'contact_info', 'phone');
    final location = getLocation(resumeData);
    final summary = getString(resumeData, 'professional_summary', '');
    final careerObjective = getString(resumeData, 'career_objective', '');
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
<title>$name</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Georgia,serif;background:#f8f8f8;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;box-shadow:0 10px 40px rgba(0,0,0,.1);overflow:hidden}
.header{background:linear-gradient(135deg,#1E3A8A,#3B82F6);padding:40px 35px;color:#fff;text-align:center}
.name{font-size:36px;font-weight:bold;margin-bottom:8px}
.contact-info{display:flex;justify-content:center;flex-wrap:wrap;gap:20px;margin-top:15px;font-size:14px}
.section{padding:25px 35px;border-bottom:1px solid #eef2f6}
.section-title{font-size:20px;font-weight:bold;color:#1E3A8A;border-bottom:2px solid #1E3A8A;padding-bottom:10px;margin-bottom:20px}
.card-item{padding:15px 18px;margin-bottom:12px;background:#fafafa;border-radius:8px;border-left:4px solid #1E3A8A}
.card-title{font-size:16px;font-weight:bold}
.card-subtitle{font-size:14px;opacity:.8}
.skill-chip{display:inline-block;background:#f0f0f0;padding:5px 14px;border-radius:20px;font-size:12px;margin:3px;color:#333}
.summary-text{font-size:15px;line-height:1.7;padding:15px 20px;background:#f8f8f8;border-radius:8px}
.two-column{display:flex;gap:25px;padding:0 35px 25px 35px}
.two-column>div{flex:1}
@media(max-width:768px){.section{padding:18px}.two-column{flex-direction:column;padding:0 18px 18px}}
</style></head><body>
<div class="resume-container">
<div class="header"><div class="name">${escapeHtml(name)}</div>
<div class="contact-info">
${email.isNotEmpty ? '<span>📧 ${escapeHtml(email)}</span>' : ''}
${phone.isNotEmpty ? '<span>📞 ${escapeHtml(phone)}</span>' : ''}
${location.isNotEmpty ? '<span>📍 ${escapeHtml(location)}</span>' : ''}
</div></div>
<div class="section"><div class="section-title">📌 Professional Summary</div><div class="summary-text">${escapeHtml(summary)}</div></div>
<div class="two-column">
<div>
<div class="section-title">⚡ Skills</div>
${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}
${buildCertificationsSection(certifications)}
<div style="padding:20px 0;"><div class="section-title">🌐 Languages</div>$languagesHtml</div>
</div>
<div>
<div class="section-title">💼 Work Experience</div>
${experience.map((exp) => '''
<div class="card-item"><div class="card-title">${escapeHtml(exp['role'])}</div>
<div class="card-subtitle">${escapeHtml(exp['company'])}</div>
<div style="font-size:12px;color:#888;margin-top:4px;">📅 ${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</div>
${exp['description'].toString().isNotEmpty ? '<div style="margin-top:8px;font-size:13px;">${escapeHtml(exp['description'])}</div>' : ''}</div>
''').join('')}
</div></div>
<div class="section"><div class="section-title">🎓 Education</div>
${education.map((edu) => '''
<div class="card-item"><div class="card-title">${escapeHtml(edu['degree'])}</div>
<div class="card-subtitle">${escapeHtml(edu['institute'])}</div>
<div style="font-size:12px;color:#888;">Year: ${escapeHtml(edu['year_of_passing'].toString())}</div></div>
''').join('')}
</div>
${buildProjectsSection(projects)}
<div class="section"><div class="section-title">🎯 Career Objective</div><div class="summary-text">${escapeHtml(careerObjective)}</div></div>
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HEADER
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          child: Column(
            children: [
              Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  ResumeFormatBase.pContactRow(
                      Icons.email, email, color: Colors.white),
                  ResumeFormatBase.pContactRow(
                      Icons.phone, phone, color: Colors.white),
                  ResumeFormatBase.pContactRow(
                      Icons.location_on, location, color: Colors.white),
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
                    color: _primary),
                ResumeFormatBase.pInfoBox(summary, bg: _bg),
                const SizedBox(height: 18),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (skills.isNotEmpty) ...[
                          ResumeFormatBase.pSectionTitle('Skills', color: _primary),
                          ResumeFormatBase.pChipsWrap(skills,
                              bg: const Color(0xFFF0F0F0), fg: _primary),
                          const SizedBox(height: 16),
                        ],
                        if (certs.isNotEmpty) ...[
                          ResumeFormatBase.pSectionTitle('Certifications',
                              color: _primary),
                          ...certs.map((x) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                    '• ${ResumeFormatBase.pCert(ResumeFormatBase.pMap(x))}',
                                    style: const TextStyle(fontSize: 13)),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (langs.isNotEmpty) ...[
                          ResumeFormatBase.pSectionTitle('Languages',
                              color: _primary),
                          ResumeFormatBase.pChipsWrap(
                              ResumeFormatBase.pLangs(langs),
                              bg: const Color(0xFFF0F0F0),
                              fg: _primary),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (exp.isNotEmpty) ...[
                          ResumeFormatBase.pSectionTitle('Work Experience',
                              color: _primary),
                          ...exp.map((e) => _expCard(ResumeFormatBase.pMap(e))),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (edu.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Education', color: _primary),
                ...edu.map((e) => _eduCard(ResumeFormatBase.pMap(e))),
                const SizedBox(height: 18),
              ],
              if (projects.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Projects', color: _primary),
                ...projects.map((p) => _projCard(ResumeFormatBase.pMap(p))),
                const SizedBox(height: 18),
              ],
              if (objective.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Career Objective',
                    color: _primary),
                ResumeFormatBase.pInfoBox(objective, bg: _bg),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _expCard(Map<String, dynamic> exp) {
    return ResumeFormatBase.pCard(
      bg: _cardBg,
      leftBorder: _primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ResumeFormatBase.pStr(exp['role'], 'Role'),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 2),
          Text(ResumeFormatBase.pStr(exp['company'], 'Company'),
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 6),
          ResumeFormatBase.pTag(
              '📅 ${ResumeFormatBase.pStr(exp['start_date'])} - ${ResumeFormatBase.pStr(exp['end_date'], 'Present')}',
              bg: Colors.white,
              fg: _muted),
          if (ResumeFormatBase.pStr(exp['description']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(ResumeFormatBase.pStr(exp['description']),
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _eduCard(Map<String, dynamic> edu) {
    return ResumeFormatBase.pCard(
      bg: _cardBg,
      leftBorder: _primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ResumeFormatBase.pStr(edu['degree'], 'Degree'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(ResumeFormatBase.pStr(edu['institute'], 'Institute'),
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 6),
          Wrap(
            children: [
              if (ResumeFormatBase.pStr(edu['year_of_passing']).isNotEmpty)
                ResumeFormatBase.pTag('📅 Year: ${edu['year_of_passing']}',
                    bg: Colors.white, fg: _muted),
              if (ResumeFormatBase.pStr(edu['cgpa_percentage']).isNotEmpty)
                ResumeFormatBase.pTag(
                    '📊 ${ResumeFormatBase.pStr(edu['result_type'], 'Score')}: ${edu['cgpa_percentage']}',
                    bg: Colors.white,
                    fg: _muted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _projCard(Map<String, dynamic> p) {
    final techs =
        ResumeFormatBase.pList(p['technologies']).map((e) => e.toString()).toList();
    return ResumeFormatBase.pCard(
      bg: _cardBg,
      leftBorder: _primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ResumeFormatBase.pStr(p['title'], 'Project'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          if (ResumeFormatBase.pStr(p['description']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(ResumeFormatBase.pStr(p['description']),
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
          if (techs.isNotEmpty) ...[
            const SizedBox(height: 8),
            ResumeFormatBase.pChipsWrap(techs,
                bg: const Color(0xFFF0F0F0), fg: _primary),
          ],
        ],
      ),
    );
  }
}