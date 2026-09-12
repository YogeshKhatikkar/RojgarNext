// lib/features/resume/presentation/screens/format/formats/executive_format.dart
// ✅ EXECUTIVE — Black/Gold premium + italic cream boxes
// 🔧 Style changes: edit ONLY this file

import 'package:flutter/material.dart';
import '../resume_format_base.dart';

class ExecutiveFormat extends ResumeFormatBase {
  @override String get id => 'executive';
  @override String get name => 'Executive Leadership';
  @override String get icon => '👔';
  @override String get description => 'Premium Professional Format';
  @override String get color => '#BF360C';
  @override String get styleKey => 'executive';
  @override String get templateType => 'executive';
  @override String get badgeText => 'Premium';

  // ==================== COLORS ====================
  static const Color _dark = Color(0xFF2C1810);
  static const Color _dark2 = Color(0xFF4A2818);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cream = Color(0xFFFFF9EF);

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
body{font-family:'Playfair Display',Georgia,serif;background:#fdfbf7;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;border:1px solid #d4af37;border-radius:8px;overflow:hidden}
.header{background:linear-gradient(135deg,#2c1810,#4a2818);padding:45px 35px;color:#fff;border-bottom:3px solid #d4af37;text-align:center}
.name{font-size:42px;font-weight:bold;letter-spacing:3px}
.contact-info{display:flex;justify-content:center;flex-wrap:wrap;gap:24px;margin-top:15px;font-size:14px}
.section{padding:25px 35px}
.section-title{font-size:20px;font-weight:bold;color:#2c1810;border-bottom:2px solid #d4af37;padding-bottom:10px;margin-bottom:20px}
.card-item{padding:15px 18px;margin-bottom:12px;background:#fff9ef;border-left:4px solid #d4af37;border-radius:4px}
.skill-chip{display:inline-block;background:rgba(212,175,55,.12);color:#4a2818;padding:5px 14px;border-radius:25px;font-size:12px;margin:3px;border:1px solid #d4af37}
.summary-text{font-size:15px;line-height:1.7;padding:18px 22px;background:#fff9ef;border-left:4px solid #d4af37;font-style:italic}
@media(max-width:768px){.section{padding:18px}.name{font-size:30px}}
</style></head><body>
<div class="resume-container">
<div class="header"><div class="name">${escapeHtml(name)}</div>
<div class="contact-info">
${email.isNotEmpty ? '<span>📧 ${escapeHtml(email)}</span>' : ''}
${phone.isNotEmpty ? '<span>📞 ${escapeHtml(phone)}</span>' : ''}
${location.isNotEmpty ? '<span>📍 ${escapeHtml(location)}</span>' : ''}
</div></div>
<div class="section"><div class="section-title">EXECUTIVE SUMMARY</div><div class="summary-text">${escapeHtml(summary)}</div></div>
<div class="section"><div class="section-title">CORE COMPETENCIES</div>
${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>
<div class="section"><div class="section-title">PROFESSIONAL EXPERIENCE</div>
${experience.map((exp) => '''
<div class="card-item"><div style="font-weight:bold;color:#2c1810;font-size:16px;">${escapeHtml(exp['role'])}</div>
<div style="font-size:13px;color:#666;font-style:italic;">${escapeHtml(exp['company'])}</div>
<div style="font-size:11px;color:#888;margin-top:6px;">${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</div>
${exp['description'].toString().isNotEmpty ? '<div style="margin-top:8px;font-size:13px;">${escapeHtml(exp['description'])}</div>' : ''}</div>
''').join('')}
</div>
<div class="section"><div class="section-title">EDUCATION</div>
${education.map((edu) => '''
<div class="card-item"><div style="font-weight:bold;font-size:15px;color:#2c1810;">${escapeHtml(edu['degree'])}</div>
<div style="font-size:13px;color:#666;font-style:italic;">${escapeHtml(edu['institute'])}</div>
<div style="font-size:11px;color:#888;margin-top:4px;">Year: ${escapeHtml(edu['year_of_passing'].toString())}</div></div>
''').join('')}
</div>
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_dark, _dark2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(bottom: BorderSide(color: _gold, width: 3)),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: Colors.white)),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  if (email.isNotEmpty) _goldLine('📧 $email'),
                  if (phone.isNotEmpty) _goldLine('📞 $phone'),
                  if (location.isNotEmpty) _goldLine('📍 $location'),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Executive Summary',
                    color: _dark, uppercase: true, underlineColor: _gold),
                ResumeFormatBase.pInfoBox(summary,
                    bg: _cream,
                    leftBorder: _gold,
                    textStyle: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                        color: _dark)),
                const SizedBox(height: 20),
              ],
              if (skills.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Core Competencies',
                    color: _dark, uppercase: true, underlineColor: _gold),
                Wrap(children: skills.map(_execChip).toList()),
                const SizedBox(height: 20),
              ],
              if (exp.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Professional Experience',
                    color: _dark, uppercase: true, underlineColor: _gold),
                ...exp.map((e) => _expCard(ResumeFormatBase.pMap(e))),
                const SizedBox(height: 20),
              ],
              if (edu.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Education',
                    color: _dark, uppercase: true, underlineColor: _gold),
                ...edu.map((e) => _eduCard(ResumeFormatBase.pMap(e))),
                const SizedBox(height: 20),
              ],
              if (certs.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Certifications',
                    color: _dark, uppercase: true, underlineColor: _gold),
                ...certs.map((x) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                          '• ${ResumeFormatBase.pCert(ResumeFormatBase.pMap(x))}',
                          style: const TextStyle(fontSize: 13, color: _dark)),
                    )),
                const SizedBox(height: 20),
              ],
              if (projects.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Key Projects',
                    color: _dark, uppercase: true, underlineColor: _gold),
                ...projects.map((p) => _projCard(ResumeFormatBase.pMap(p))),
                const SizedBox(height: 20),
              ],
              if (langs.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Languages',
                    color: _dark, uppercase: true, underlineColor: _gold),
                Wrap(
                    children:
                        ResumeFormatBase.pLangs(langs).map(_execChip).toList()),
                const SizedBox(height: 20),
              ],
              if (objective.isNotEmpty) ...[
                ResumeFormatBase.pSectionTitle('Career Objective',
                    color: _dark, uppercase: true, underlineColor: _gold),
                ResumeFormatBase.pInfoBox(objective,
                    bg: _cream,
                    leftBorder: _gold,
                    textStyle: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                        color: _dark)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _goldLine(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12, color: _gold, letterSpacing: 0.5)),
      );

  Widget _execChip(String text) => Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _gold.withOpacity(0.12),
          border: Border.all(color: _gold),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: _dark,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5)),
      );

  Widget _expCard(Map<String, dynamic> exp) => ResumeFormatBase.pCard(
        bg: _cream,
        leftBorder: _gold,
        radius: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(exp['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _dark)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(exp['company'], 'Company'),
                style: const TextStyle(
                    fontSize: 13, color: _dark2, fontStyle: FontStyle.italic)),
            const SizedBox(height: 6),
            Text(
              '${ResumeFormatBase.pStr(exp['start_date'])} - ${ResumeFormatBase.pStr(exp['end_date'], 'Present')}',
              style: const TextStyle(
                  fontSize: 11, color: _dark, letterSpacing: 0.5),
            ),
            if (ResumeFormatBase.pStr(exp['description']).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ResumeFormatBase.pStr(exp['description']),
                  style:
                      const TextStyle(fontSize: 13, height: 1.5, color: _dark)),
            ],
          ],
        ),
      );

  Widget _eduCard(Map<String, dynamic> edu) => ResumeFormatBase.pCard(
        bg: _cream,
        leftBorder: _gold,
        radius: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(edu['degree'], 'Degree'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _dark)),
            const SizedBox(height: 3),
            Text(ResumeFormatBase.pStr(edu['institute'], 'Institute'),
                style: const TextStyle(
                    fontSize: 13, color: _dark2, fontStyle: FontStyle.italic)),
            if (ResumeFormatBase.pStr(edu['year_of_passing']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Year: ${edu['year_of_passing']}',
                  style: const TextStyle(fontSize: 11, color: _dark)),
            ],
          ],
        ),
      );

  Widget _projCard(Map<String, dynamic> p) => ResumeFormatBase.pCard(
        bg: _cream,
        leftBorder: _gold,
        radius: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFormatBase.pStr(p['title'], 'Project'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _dark)),
            if (ResumeFormatBase.pStr(p['description']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ResumeFormatBase.pStr(p['description']),
                  style:
                      const TextStyle(fontSize: 13, height: 1.5, color: _dark)),
            ],
          ],
        ),
      );
}