// lib/features/resume/presentation/screens/format/formats/fresher_format.dart
// ✅ FRESHER — Teal gradient + friendly rounded cards + emoji titles
// 🔧 Style changes: edit ONLY this file

import 'package:flutter/material.dart';
import '../resume_format_base.dart';

class FresherFormat extends ResumeFormatBase {
  @override String get id => 'fresher';
  @override String get name => 'Fresher / Entry Level';
  @override String get icon => '🎓';
  @override String get description => 'Education-Focused Design';
  @override String get color => '#00897B';
  @override String get styleKey => 'fresher';
  @override String get templateType => 'fresher';
  @override String get badgeText => 'New Grad';

  // ==================== COLORS ====================
  static const Color _primary = Color(0xFF00897B);
  static const Color _secondary = Color(0xFF26A69A);
  static const Color _bg = Color(0xFFE0F2F1);
  static const Color _bodyBg = Color(0xFFF1FDFB);

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
body{font-family:'Segoe UI',sans-serif;background:linear-gradient(135deg,#e0f2f1,#b2dfdb);padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;border-radius:20px;overflow:hidden;box-shadow:0 10px 40px rgba(0,0,0,.1)}
.header{background:linear-gradient(135deg,#00897B,#26A69A);padding:35px 30px;color:#fff;text-align:center;border-radius:20px 20px 0 0}
.name{font-size:34px;font-weight:bold}
.section{padding:22px 30px}
.section-title{font-size:18px;font-weight:600;color:#00897B;border-bottom:2px solid #26A69A;padding-bottom:8px;margin-bottom:16px}
.card-item{padding:12px 16px;margin-bottom:10px;background:#f5f5f5;border-radius:12px}
.skill-chip{display:inline-block;background:#e0f2f1;color:#00897B;padding:5px 14px;border-radius:20px;font-size:12px;margin:3px;font-weight:500}
.summary-text{font-size:14px;line-height:1.7;padding:16px 20px;background:#f5f5f5;border-radius:12px}
@media(max-width:768px){.section{padding:16px}.name{font-size:26px}}
</style></head><body>
<div class="resume-container">
<div class="header"><div class="name">${escapeHtml(name)}</div>
<div style="margin-top:12px;font-size:13px;display:flex;justify-content:center;flex-wrap:wrap;gap:18px;">
${email.isNotEmpty ? '<span>📧 ${escapeHtml(email)}</span>' : ''}
${phone.isNotEmpty ? '<span>📞 ${escapeHtml(phone)}</span>' : ''}
${location.isNotEmpty ? '<span>📍 ${escapeHtml(location)}</span>' : ''}
</div></div>
<div class="section"><div class="section-title">About Me</div><div class="summary-text">${escapeHtml(summary)}</div></div>
<div class="section"><div class="section-title">Education</div>
${education.map((edu) => '''
<div class="card-item"><div style="font-weight:bold;color:#00897B;">${escapeHtml(edu['degree'])}</div>
<div style="font-size:13px;color:#555;">${escapeHtml(edu['institute'])}</div>
<div style="font-size:12px;color:#888;">Year: ${escapeHtml(edu['year_of_passing'].toString())}</div></div>
''').join('')}
</div>
<div class="section"><div class="section-title">Skills</div>
${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>
<div class="section"><div class="section-title">Experience</div>
${experience.map((exp) => '''
<div class="card-item"><div style="font-weight:bold;color:#00897B;">${escapeHtml(exp['role'])}</div>
<div style="font-size:13px;color:#555;">${escapeHtml(exp['company'])}</div>
<div style="font-size:12px;color:#888;">${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</div></div>
''').join('')}
</div>
${buildCertificationsSection(certifications)}
${buildProjectsSection(projects)}
<div class="section"><div class="section-title">Languages</div>$languagesHtml</div>
<div class="section"><div class="section-title">Career Objective</div><div class="summary-text">${escapeHtml(careerObjective)}</div></div>
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
      color: _bodyBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, _secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Column(
              children: [
                Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    if (email.isNotEmpty) _pill('📧 $email'),
                    if (phone.isNotEmpty) _pill('📞 $phone'),
                    if (location.isNotEmpty) _pill('📍 $location'),
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
                  ResumeFormatBase.pSectionTitle('👋 About Me', color: _primary),
                  ResumeFormatBase.pInfoBox(summary, bg: _bg, radius: 14),
                  const SizedBox(height: 20),
                ],
                if (edu.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('🎓 Education',
                      color: _primary),
                  ...edu.map((e) => _eduCard(ResumeFormatBase.pMap(e))),
                  const SizedBox(height: 20),
                ],
                if (skills.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('⚡ Skills', color: _primary),
                  Wrap(children: skills.map(_fresherChip).toList()),
                  const SizedBox(height: 20),
                ],
                if (projects.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('🛠️ Projects',
                      color: _primary),
                  ...projects.map((p) => _projCard(ResumeFormatBase.pMap(p))),
                  const SizedBox(height: 20),
                ],
                if (exp.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('💼 Experience',
                      color: _primary),
                  ...exp.map((e) => _expCard(ResumeFormatBase.pMap(e))),
                  const SizedBox(height: 20),
                ],
                if (certs.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('📜 Certifications',
                      color: _primary),
                  ...certs.map((x) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                            '• ${ResumeFormatBase.pCert(ResumeFormatBase.pMap(x))}',
                            style: const TextStyle(fontSize: 13)),
                      )),
                  const SizedBox(height: 20),
                ],
                if (langs.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('🌐 Languages',
                      color: _primary),
                  Wrap(
                      children: ResumeFormatBase.pLangs(langs)
                          .map(_fresherChip)
                          .toList()),
                  const SizedBox(height: 20),
                ],
                if (objective.isNotEmpty) ...[
                  ResumeFormatBase.pSectionTitle('🎯 Career Objective',
                      color: _primary),
                  ResumeFormatBase.pInfoBox(objective, bg: _bg, radius: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String t) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.white)),
      );

  Widget _fresherChip(String text) => Container(
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _secondary.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: _primary, fontWeight: FontWeight.w500)),
      );

  Widget _eduCard(Map<String, dynamic> edu) => ResumeFormatBase.pCard(
        bg: Colors.white,
        borderColor: _secondary.withOpacity(0.3),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(edu['degree'], 'Degree'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _primary)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(edu['institute'], 'Institute'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
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
        decoration:
            BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(fontSize: 11, color: _primary)),
      );

  Widget _projCard(Map<String, dynamic> p) {
    final techs = ResumeFormatBase.pList(p['technologies'])
        .map((e) => e.toString())
        .toList();
    return ResumeFormatBase.pCard(
      bg: Colors.white,
      borderColor: _secondary.withOpacity(0.3),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ResumeFormatBase.pStr(p['title'], 'Project'),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: _primary)),
          if (ResumeFormatBase.pStr(p['description']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(ResumeFormatBase.pStr(p['description']),
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
          if (techs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(children: techs.map(_fresherChip).toList()),
          ],
        ],
      ),
    );
  }

  Widget _expCard(Map<String, dynamic> exp) => ResumeFormatBase.pCard(
        bg: Colors.white,
        borderColor: _secondary.withOpacity(0.3),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(exp['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _primary)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(exp['company'], 'Company'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
            if (ResumeFormatBase.pStr(exp['description']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ResumeFormatBase.pStr(exp['description']),
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ],
        ),
      );
}