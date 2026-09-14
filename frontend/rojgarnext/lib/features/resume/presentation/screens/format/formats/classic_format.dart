// lib/features/resume/presentation/screens/format/formats/classic_format.dart
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

  static const Color _primary = Color(0xFF1E3A8A);
  static const Color _secondary = Color(0xFF3B82F6);
  static const Color _bg = Color(0xFFF8F8F8);
  static const Color _cardBg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF555555);

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

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$name</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Georgia,serif;background:#f8f8f8;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;box-shadow:0 10px 40px rgba(0,0,0,.1);overflow:hidden;display:flex}
.sidebar{width:30%;background:#1E3A8A;color:#fff;padding:30px 20px}
.main{width:70%;padding:30px 35px}
.header{text-align:center;margin-bottom:20px}
.name{font-size:32px;font-weight:bold;color:#1E3A8A}
.sidebar .section-title{font-size:16px;font-weight:bold;color:#fff;border-bottom:2px solid #fff;padding-bottom:5px;margin:20px 0 10px 0;text-transform:uppercase}
.sidebar .skill-chip{display:inline-block;background:rgba(255,255,255,.15);padding:4px 10px;border-radius:15px;font-size:12px;margin:3px}
.sidebar .item{font-size:13px;color:#E2E8F0;margin-bottom:6px;padding-left:10px;position:relative}
.main .section-title{font-size:20px;font-weight:bold;color:#1E3A8A;border-bottom:2px solid #1E3A8A;padding-bottom:10px;margin-bottom:20px;text-transform:uppercase}
.card-item{padding:15px;margin-bottom:12px;background:#FAFAFA;border-radius:8px;border-left:4px solid #1E3A8A}
.card-title{font-size:16px;font-weight:bold;color:#111}
.card-subtitle{font-size:14px;color:#555}
.summary-text{font-size:14px;line-height:1.7;padding:15px;background:#F8F8F8;border-radius:8px}
</style></head><body>
<div class="resume-container">
  <div class="sidebar">
    <div style="text-align:center;margin-bottom:20px;">
      <div style="font-size:24px;font-weight:bold;">${escapeHtml(name)}</div>
      <div style="font-size:12px;color:#93C5FD;">Software Developer</div>
    </div>
    <div class="section-title">Contact</div>
    <div class="item">📧 ${escapeHtml(email)}</div>
    <div class="item">📞 ${escapeHtml(phone)}</div>
    <div class="item">📍 ${escapeHtml(location)}</div>
    
    <div class="section-title">Skills</div>
    <div>${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>
    
    <div class="section-title">Certifications</div>
    ${certifications.map((c) => '<div class="item">${escapeHtml(pCert(pMap(c)))}</div>').join('')}
  </div>
  <div class="main">
    <div class="section-title">Professional Summary</div>
    <div class="summary-text">${escapeHtml(summary)}</div>
    
    <div class="section-title" style="margin-top:25px;">Work Experience</div>
    ${experience.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div><div style="margin-top:8px;font-size:13px;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}
    
    <div class="section-title" style="margin-top:25px;">Education</div>
    ${education.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['degree']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['institute']))} | ${escapeHtml(pStr(x['year_of_passing']))}</div></div>';
    }).join('')}
    
    <div class="section-title" style="margin-top:25px;">Projects</div>
    ${projects.map((p) {
      final x = pMap(p);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['title']))}</div><div style="font-size:13px;margin-top:4px;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}
  </div>
</div>
</body></html>''';
  }

  @override
  Widget buildPreview(BuildContext context, Map<String, dynamic> data) {
    final u = pMap(data['user_info']);
    final c = pMap(data['contact_info']);
    final name = pStr(u['full_name'], 'Your Name');
    final email = pStr(c['email']);
    final phone = pStr(c['phone']);
    final location = pLocation(data);
    final summary = pStr(data['professional_summary']);
    final exp = pList(data['experience']);
    final edu = pList(data['education']);
    final skills = pSkills(data['skills']);
    final certs = pList(data['certifications']);
    final projects = pList(data['projects']);

    return Container(
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDEBAR
          Container(
            width: 240,
            color: _primary,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      const Text("Software Developer", style: TextStyle(fontSize: 11, color: Color(0xFF93C5FD))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sidebarTitle("CONTACT"),
                _sidebarItem("📧 $email"),
                _sidebarItem("📞 $phone"),
                _sidebarItem("📍 $location"),
                const SizedBox(height: 16),
                _sidebarTitle("SKILLS"),
                Wrap(spacing: 6, runSpacing: 6, children: skills.map((s) => _sidebarChip(s)).toList()),
                const SizedBox(height: 16),
                _sidebarTitle("CERTIFICATIONS"),
                ...certs.map((c) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text("• ${pCert(pMap(c))}", style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0))))),
              ],
            ),
          ),
          // RIGHT MAIN CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _mainTitle("PROFESSIONAL SUMMARY"),
                  pInfoBox(summary, bg: _bg),
                  const SizedBox(height: 20),
                  _mainTitle("WORK EXPERIENCE"),
                  ...exp.map((e) => _expCard(pMap(e))),
                  const SizedBox(height: 20),
                  _mainTitle("EDUCATION"),
                  ...edu.map((e) => _eduCard(pMap(e))),
                  const SizedBox(height: 20),
                  _mainTitle("PROJECTS"),
                  ...projects.map((p) => _projCard(pMap(p))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
  );

  Widget _sidebarItem(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0))),
  );

  Widget _sidebarChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.white)),
  );

  Widget _mainTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(height: 2, width: 50, color: _primary),
      ],
    ),
  );

  Widget _expCard(Map<String, dynamic> exp) => pCard(
    bg: _cardBg, leftBorder: _primary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(exp['role'], 'Role'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 2),
        Text("${pStr(exp['company'])} | ${pStr(exp['start_date'])} - ${pStr(exp['end_date'], 'Present')}", style: const TextStyle(fontSize: 13, color: _muted)),
        if (pStr(exp['description']).isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(pStr(exp['description']), style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ],
    ),
  );

  Widget _eduCard(Map<String, dynamic> edu) => pCard(
    bg: _cardBg, leftBorder: _primary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(edu['degree'], 'Degree'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text("${pStr(edu['institute'])} | ${pStr(edu['year_of_passing'])}", style: const TextStyle(fontSize: 13, color: _muted)),
      ],
    ),
  );

  Widget _projCard(Map<String, dynamic> p) => pCard(
    bg: _cardBg, leftBorder: _primary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(p['title'], 'Project'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        if (pStr(p['description']).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(pStr(p['description']), style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ],
    ),
  );
}