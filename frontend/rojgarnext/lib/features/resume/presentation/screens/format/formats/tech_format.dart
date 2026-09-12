// lib/features/resume/presentation/screens/format/formats/tech_format.dart
// ✅ TECH — Dark navy + green monospace accents
// 🔧 Style changes: edit ONLY this file

import 'package:flutter/material.dart';
import '../resume_format_base.dart';

class TechFormat extends ResumeFormatBase {
  @override String get id => 'tech';
  @override String get name => 'Tech / IT Specialist';
  @override String get icon => '💻';
  @override String get description => 'Skills-Focused Technical Resume';
  @override String get color => '#00C853';
  @override String get styleKey => 'tech';
  @override String get templateType => 'tech';
  @override String get badgeText => 'Developer';

  // ==================== COLORS ====================
  static const Color _bg = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF00E676);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _text = Color(0xFFE2E8F0);
  static const Color _border = Color(0xFF334155);

  // ==========================================================================
  // HTML — unchanged
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
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Fira Code',monospace;background:#0a0e27;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#0f172a;border:1px solid #334155;border-radius:12px;overflow:hidden}
.header{background:linear-gradient(135deg,#00C853,#00E676);padding:35px 30px;color:#0a0e27;text-align:center;border-bottom:2px solid #00FF88}
.name{font-size:36px;font-weight:700;letter-spacing:2px}
.contact-info{display:flex;justify-content:center;flex-wrap:wrap;gap:16px;margin-top:12px;font-size:13px}
.contact-info span{background:rgba(0,0,0,.1);padding:4px 14px;border-radius:20px}
.section{padding:20px 30px}
.section-title{font-size:18px;font-weight:600;color:#00E676;border-bottom:2px solid #00E676;padding-bottom:8px;margin-bottom:16px}
.card-item{padding:14px 16px;margin-bottom:12px;background:#1e293b;border:1px solid #334155;border-radius:10px}
.card-title{color:#00E676;font-weight:600;font-size:15px}
.card-subtitle{font-size:13px;color:#94a3b8}
.skill-chip{display:inline-block;background:rgba(0,230,118,.12);color:#00E676;padding:5px 14px;border-radius:8px;font-size:12px;margin:3px;border:1px solid #00E676}
.summary-text{font-size:14px;line-height:1.7;padding:16px 20px;background:#1e293b;border-left:4px solid #00E676;border-radius:8px;color:#e2e8f0}
@media(max-width:768px){.section{padding:16px}.name{font-size:28px}}
</style></head><body>
<div class="resume-container">
<div class="header"><div class="name">${escapeHtml(name)}</div>
<div class="contact-info">
${email.isNotEmpty ? '<span>📧 ${escapeHtml(email)}</span>' : ''}
${phone.isNotEmpty ? '<span>📞 ${escapeHtml(phone)}</span>' : ''}
${location.isNotEmpty ? '<span>📍 ${escapeHtml(location)}</span>' : ''}
</div></div>
<div class="section"><div class="section-title">// SUMMARY</div><div class="summary-text">${escapeHtml(summary)}</div></div>
<div class="section"><div class="section-title">// EXPERIENCE</div>
${experience.map((exp) => '''
<div class="card-item"><div class="card-title">${escapeHtml(exp['role'])}</div>
<div class="card-subtitle">${escapeHtml(exp['company'])}</div>
<div style="font-size:11px;color:#94a3b8;margin-top:6px;">📅 ${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</div>
${exp['description'].toString().isNotEmpty ? '<div style="margin-top:6px;font-size:12px;color:#94a3b8;">${escapeHtml(exp['description'])}</div>' : ''}</div>
''').join('')}
</div>
<div class="section"><div class="section-title">// SKILLS</div>
${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>
<div class="section"><div class="section-title">// EDUCATION</div>
${education.map((edu) => '''
<div class="card-item"><div class="card-title">${escapeHtml(edu['degree'])}</div>
<div class="card-subtitle">${escapeHtml(edu['institute'])}</div>
<div style="font-size:11px;color:#94a3b8;margin-top:6px;">Year: ${escapeHtml(edu['year_of_passing'].toString())}</div></div>
''').join('')}
</div>
${buildCertificationsSection(certifications)}
${buildProjectsSection(projects)}
<div class="section"><div class="section-title">// LANGUAGES</div>$languagesHtml</div>
<div class="section"><div class="section-title">// OBJECTIVE</div><div class="summary-text">${escapeHtml(careerObjective)}</div></div>
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

    return Container(
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00C853), Color(0xFF00E676)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Color(0xFF0A0E27),
                        fontFamily: 'monospace')),
                const SizedBox(height: 10),
                Wrap(
                  children: [
                    if (email.isNotEmpty) _darkPill('📧 $email'),
                    if (phone.isNotEmpty) _darkPill('📞 $phone'),
                    if (location.isNotEmpty) _darkPill('📍 $location'),
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
                  ResumeFormatBase.pSectionTitle('// SUMMARY',
                      color: _accent, uppercase: false),
                  ResumeFormatBase.pInfoBox(summary,
                      bg: _card,
                      leftBorder: _accent,
                      textStyle: const TextStyle(
                          fontSize: 13, height: 1.5, color: _text)),
                  const SizedBox(height: 20),
                ],
                if (exp.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('// EXPERIENCE',
                      color: _accent, uppercase: false),
                  ...exp.map((e) => _expCard(ResumeFormatBase.pMap(e))),
                  const SizedBox(height: 20),
                ],
                if (edu.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('// EDUCATION',
                      color: _accent, uppercase: false),
                  ...edu.map((e) => _eduCard(ResumeFormatBase.pMap(e))),
                  const SizedBox(height: 20),
                ],
                if (skills.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('// SKILLS',
                      color: _accent, uppercase: false),
                  Wrap(children: skills.map(_techChip).toList()),
                  const SizedBox(height: 20),
                ],
                if (certs.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('// CERTIFICATIONS',
                      color: _accent, uppercase: false),
                  ...certs.map((x) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                            '• ${ResumeFormatBase.pCert(ResumeFormatBase.pMap(x))}',
                            style: const TextStyle(
                                fontSize: 12, color: _text)),
                      )),
                  const SizedBox(height: 20),
                ],
                if (projects.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('// PROJECTS',
                      color: _accent, uppercase: false),
                  ...projects.map((p) => _projCard(ResumeFormatBase.pMap(p))),
                  const SizedBox(height: 20),
                ],
                if (objective.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('// OBJECTIVE',
                      color: _accent, uppercase: false),
                  ResumeFormatBase.pInfoBox(objective,
                      bg: _card,
                      leftBorder: _accent,
                      textStyle: const TextStyle(
                          fontSize: 13, height: 1.5, color: _text)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkPill(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20)),
          child: Text(t,
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ),
      );

  Widget _techChip(String t) => Container(
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.12),
          border: Border.all(color: _accent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12, color: _accent, fontFamily: 'monospace')),
      );

  Widget _expCard(Map<String, dynamic> exp) => ResumeFormatBase.pCard(
        bg: _card,
        borderColor: _border,
        radius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(exp['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _accent)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(exp['company'], 'Company'),
                style: const TextStyle(fontSize: 13, color: _muted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _bg,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                  '📅 ${ResumeFormatBase.pStr(exp['start_date'])} - ${ResumeFormatBase.pStr(exp['end_date'], 'Present')}',
                  style: const TextStyle(fontSize: 10, color: _muted)),
            ),
            if (ResumeFormatBase.pStr(exp['description']).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ResumeFormatBase.pStr(exp['description']),
                  style: const TextStyle(
                      fontSize: 12, height: 1.4, color: Color(0xFFCBD5E1))),
            ],
          ],
        ),
      );

  Widget _eduCard(Map<String, dynamic> edu) => ResumeFormatBase.pCard(
        bg: _card,
        borderColor: _border,
        radius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(edu['degree'], 'Degree'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: _accent)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(edu['institute'], 'Institute'),
                style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 6),
            Wrap(
              children: [
                if (ResumeFormatBase.pStr(edu['year_of_passing']).isNotEmpty)
                  _tag('📅 ${edu['year_of_passing']}'),
                if (ResumeFormatBase.pStr(edu['cgpa_percentage']).isNotEmpty)
                  _tag('📊 ${edu['cgpa_percentage']}'),
              ],
            ),
          ],
        ),
      );

  Widget _tag(String t) => Container(
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(t, style: const TextStyle(fontSize: 10, color: _muted)),
      );

  Widget _projCard(Map<String, dynamic> p) {
    final techs = ResumeFormatBase.pList(p['technologies'])
        .map((e) => e.toString())
        .toList();
    return ResumeFormatBase.pCard(
      bg: _card,
      borderColor: _border,
      radius: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ResumeFormatBase.pStr(p['title'], 'Project'),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _accent)),
          if (ResumeFormatBase.pStr(p['description']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(ResumeFormatBase.pStr(p['description']),
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: Color(0xFFCBD5E1))),
          ],
          if (techs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(children: techs.map(_techChip).toList()),
          ],
        ],
      ),
    );
  }
}