// lib/features/resume/presentation/screens/format/formats/modern_format.dart
// ✅ MODERN — Purple gradient + rounded cards + shadows
// 🔧 Style changes: edit ONLY this file

import 'package:flutter/material.dart';
import '../resume_format_base.dart';

class ModernFormat extends ResumeFormatBase {
  @override String get id => 'modern';
  @override String get name => 'Modern Creative';
  @override String get icon => '🎨';
  @override String get description => 'Stylish Contemporary Design';
  @override String get color => '#9C27B0';
  @override String get styleKey => 'modern';
  @override String get templateType => 'modern';
  @override String get badgeText => 'Trending';

  // ==================== COLORS ====================
  static const Color _primary = Color(0xFF9C27B0);
  static const Color _secondary = Color(0xFFCE93D8);
  static const Color _dark = Color(0xFF4A148C);
  static const Color _bg = Color(0xFFF3E5F5);

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
body{font-family:'Poppins',sans-serif;background:#f5f7fa;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;border-radius:30px;box-shadow:0 30px 50px rgba(0,0,0,.2);overflow:hidden}
.header{background:linear-gradient(135deg,#9C27B0,#E1BEE7);padding:40px 35px;color:#fff;text-align:center}
.name{font-size:40px;font-weight:700;margin-bottom:8px}
.contact-info{display:flex;justify-content:center;flex-wrap:wrap;gap:20px;margin-top:15px;font-size:14px}
.contact-info span{background:rgba(255,255,255,.15);padding:5px 15px;border-radius:30px}
.section{padding:25px 35px}
.section-title{font-size:20px;font-weight:600;color:#9C27B0;border-bottom:3px solid #9C27B0;padding-bottom:10px;margin-bottom:20px}
.card-item{padding:18px 20px;margin-bottom:14px;background:#fff;border-radius:15px;box-shadow:0 5px 15px rgba(0,0,0,.08);border-left:4px solid #9C27B0}
.skill-chip{display:inline-block;background:linear-gradient(135deg,#9C27B0,#E1BEE7);color:#fff;padding:6px 16px;border-radius:25px;font-size:12px;font-weight:500;margin:3px}
.summary-text{font-size:15px;line-height:1.7;padding:18px 22px;background:#f5f5f5;border-radius:14px;border-left:4px solid #9C27B0}
@media(max-width:768px){.section{padding:18px}.name{font-size:30px}}
</style></head><body>
<div class="resume-container">
<div class="header"><div class="name">${escapeHtml(name)}</div>
<div class="contact-info">
${email.isNotEmpty ? '<span>📧 ${escapeHtml(email)}</span>' : ''}
${phone.isNotEmpty ? '<span>📞 ${escapeHtml(phone)}</span>' : ''}
${location.isNotEmpty ? '<span>📍 ${escapeHtml(location)}</span>' : ''}
</div></div>
<div class="section"><div class="section-title">✨ Professional Summary</div><div class="summary-text">${escapeHtml(summary)}</div></div>
<div class="section"><div class="section-title">⚡ Skills</div>
${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>
<div class="section"><div class="section-title">💼 Work Experience</div>
${experience.map((exp) => '''
<div class="card-item"><div style="font-weight:700;color:#4A148C;font-size:16px;">${escapeHtml(exp['role'])}</div>
<div style="font-size:13px;color:#666;margin-top:2px;">${escapeHtml(exp['company'])}</div>
<div style="font-size:11px;color:#888;margin-top:6px;">📅 ${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</div>
${exp['description'].toString().isNotEmpty ? '<div style="margin-top:8px;font-size:13px;">${escapeHtml(exp['description'])}</div>' : ''}</div>
''').join('')}
</div>
<div class="section"><div class="section-title">🎓 Education</div>
${education.map((edu) => '''
<div class="card-item"><div style="font-weight:700;font-size:15px;">${escapeHtml(edu['degree'])}</div>
<div style="font-size:13px;color:#666;margin-top:3px;">${escapeHtml(edu['institute'])}</div>
<div style="font-size:11px;color:#888;margin-top:6px;">Year: ${escapeHtml(edu['year_of_passing'].toString())}</div></div>
''').join('')}
</div>
${buildCertificationsSection(certifications)}
${buildProjectsSection(projects)}
<div class="section"><div class="section-title">🌐 Languages</div>$languagesHtml</div>
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
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 34),
          child: Column(
            children: [
              Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1)),
              const SizedBox(height: 14),
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
                ResumeFormatBase.pSectionTitle('✨ Professional Summary',
                    color: _dark),
                ResumeFormatBase.pInfoBox(summary,
                    bg: _bg, leftBorder: _primary, radius: 14),
                const SizedBox(height: 20),
              ],
              if (exp.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('💼 Work Experience',
                    color: _dark),
                ...exp.map((e) => _expCard(ResumeFormatBase.pMap(e))),
                const SizedBox(height: 20),
              ],
              if (edu.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('🎓 Education', color: _dark),
                ...edu.map((e) => _eduCard(ResumeFormatBase.pMap(e))),
                const SizedBox(height: 20),
              ],
              if (skills.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('⚡ Skills', color: _dark),
                Wrap(children: skills.map(_chip).toList()),
                const SizedBox(height: 20),
              ],
              if (certs.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('📜 Certifications',
                    color: _dark),
                ...certs.map((x) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                          '• ${ResumeFormatBase.pCert(ResumeFormatBase.pMap(x))}',
                          style: const TextStyle(fontSize: 13)),
                    )),
                const SizedBox(height: 20),
              ],
              if (projects.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('🛠️ Projects', color: _dark),
                ...projects.map((p) => _projCard(ResumeFormatBase.pMap(p))),
                const SizedBox(height: 20),
              ],
              if (langs.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('🌐 Languages', color: _dark),
                Wrap(
                    children:
                        ResumeFormatBase.pLangs(langs).map(_chip).toList()),
                const SizedBox(height: 20),
              ],
              if (objective.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('🎯 Career Objective',
                    color: _dark),
                ResumeFormatBase.pInfoBox(objective,
                    bg: _bg, leftBorder: _primary, radius: 14),
              ],
            ],
          ),
        ),
      ],
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

  Widget _chip(String text) => Container(
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
                color: Color(0x339C27B0),
                blurRadius: 6,
                offset: Offset(0, 3)),
          ],
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500)),
      );

  Widget _expCard(Map<String, dynamic> exp) => ResumeFormatBase.pCard(
        bg: Colors.white,
        leftBorder: _primary,
        radius: 14,
        shadows: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(exp['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _dark)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(exp['company'], 'Company'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: _bg, borderRadius: BorderRadius.circular(20)),
              child: Text(
                  '📅 ${ResumeFormatBase.pStr(exp['start_date'])} - ${ResumeFormatBase.pStr(exp['end_date'], 'Present')}',
                  style: const TextStyle(fontSize: 11, color: _dark)),
            ),
            if (ResumeFormatBase.pStr(exp['description']).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ResumeFormatBase.pStr(exp['description']),
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ],
        ),
      );

  Widget _eduCard(Map<String, dynamic> edu) => ResumeFormatBase.pCard(
        bg: Colors.white,
        leftBorder: _primary,
        radius: 14,
        shadows: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(edu['degree'], 'Degree'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(edu['institute'], 'Institute'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
            const SizedBox(height: 6),
            Wrap(
              children: [
                if (ResumeFormatBase.pStr(edu['year_of_passing']).isNotEmpty)
                  _tag('📅 ${edu['year_of_passing']}'),
                if (ResumeFormatBase.pStr(edu['cgpa_percentage']).isNotEmpty)
                  _tag(
                      '📊 ${ResumeFormatBase.pStr(edu['result_type'], 'Score')}: ${edu['cgpa_percentage']}'),
              ],
            ),
          ],
        ),
      );

  Widget _tag(String t) => Container(
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration:
            BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(fontSize: 11, color: _dark)),
      );

  Widget _projCard(Map<String, dynamic> p) {
    final techs = ResumeFormatBase.pList(p['technologies'])
        .map((e) => e.toString())
        .toList();
    return ResumeFormatBase.pCard(
      bg: Colors.white,
      leftBorder: _primary,
      radius: 14,
      shadows: const [
        BoxShadow(
            color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3)),
      ],
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
            Wrap(children: techs.map(_chip).toList()),
          ],
        ],
      ),
    );
  }
}