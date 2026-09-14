// lib/features/resume/presentation/screens/format/formats/fresher_format.dart
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

  static const Color _primary = Color(0xFF00897B);
  static const Color _secondary = Color(0xFF26A69A);
  static const Color _bg = Color(0xFFE0F2F1);
  static const Color _bodyBg = Color(0xFFF1FDFB);

  @override
  String generateHtml(Map<String, dynamic> resumeData) {
    final name = getString(resumeData, 'user_info', 'full_name');
    final email = getString(resumeData, 'contact_info', 'email');
    final phone = getString(resumeData, 'contact_info', 'phone');
    final location = getLocation(resumeData);
    final objective = getString(resumeData, 'career_objective', '');
    final education = getList(resumeData, 'education');
    final experience = getList(resumeData, 'experience');
    final skills = getSkills(resumeData);
    final certifications = getList(resumeData, 'certifications');
    final projects = getList(resumeData, 'projects');

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',sans-serif;background:linear-gradient(135deg,#e0f2f1,#b2dfdb);padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;border-radius:20px;overflow:hidden;box-shadow:0 10px 40px rgba(0,0,0,.1);display:flex}
.left-panel{width:30%;background:#E0F2F1;padding:25px}
.right-panel{width:70%;padding:25px}
.header{background:linear-gradient(135deg,#00897B,#26A69A);padding:25px;color:#fff;text-align:center;border-radius:15px;margin-bottom:20px}
.name{font-size:26px;font-weight:bold}
.section-title{font-size:16px;font-weight:600;color:#00897B;border-bottom:2px solid #26A69A;padding-bottom:6px;margin:20px 0 12px 0}
.card-item{padding:12px;margin-bottom:10px;background:#f5f5f5;border-radius:10px}
.card-title{font-weight:bold;color:#00897B;font-size:14px}
.card-subtitle{font-size:12px;color:#555}
.summary-text{font-size:13px;line-height:1.6;padding:12px;background:#f5f5f5;border-radius:10px}
.skill-bar{margin-bottom:6px}
.bar-bg{height:5px;background:#B2DFDB;border-radius:3px;margin-top:2px}
.bar-fill{height:5px;background:#00897B;border-radius:3px}
</style></head><body>
<div class="resume-container">
  <div class="left-panel">
    <div class="header">
      <div class="name">${escapeHtml(name)}</div>
      <div style="font-size:12px;margin-top:4px;">Fresher | ITI COPA</div>
      <div style="font-size:11px;margin-top:8px;">📞 ${escapeHtml(phone)}</div>
      <div style="font-size:11px;">📧 ${escapeHtml(email)}</div>
      <div style="font-size:11px;">📍 ${escapeHtml(location)}</div>
    </div>
    <div class="section-title">Key Skills</div>
    ${skills.map((s) => '<div class="skill-bar"><div style="font-size:12px;">${escapeHtml(s)}</div><div class="bar-bg"><div class="bar-fill" style="width:80%"></div></div></div>').join('')}
    <div class="section-title">Certifications</div>
    ${certifications.map((c) => '<div style="font-size:12px;margin-bottom:4px;">• ${escapeHtml(pCert(pMap(c)))}</div>').join('')}
  </div>
  <div class="right-panel">
    <div class="section-title">Career Objective</div>
    <div class="summary-text">${escapeHtml(objective)}</div>
    <div class="section-title">Education</div>
    ${education.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['degree']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['institute']))} | ${escapeHtml(pStr(x['year_of_passing']))}</div></div>';
    }).join('')}
    <div class="section-title">Projects</div>
    ${projects.map((p) {
      final x = pMap(p);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['title']))}</div><div style="font-size:12px;margin-top:4px;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}
    <div class="section-title">Internships / Experience</div>
    ${experience.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div></div>';
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
    final objective = pStr(data['career_objective']);
    final exp = pList(data['experience']);
    final edu = pList(data['education']);
    final skills = pSkills(data['skills']);
    final certs = pList(data['certifications']);
    final projects = pList(data['projects']);

    return Container(
      color: _bodyBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT PANEL
          Container(
            width: 240,
            color: _bg,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_primary, _secondary]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      const Text("Fresher | ITI COPA", style: TextStyle(fontSize: 11, color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text("📞 $phone", style: const TextStyle(fontSize: 11, color: Colors.white)),
                      Text("📧 $email", style: const TextStyle(fontSize: 11, color: Colors.white)),
                      Text("📍 $location", style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sidebarTitle("KEY SKILLS"),
                ...skills.map((s) => _skillBar(s)),
                const SizedBox(height: 16),
                _sidebarTitle("CERTIFICATIONS"),
                ...certs.map((c) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text("• ${pCert(pMap(c))}", style: const TextStyle(fontSize: 12)))),
              ],
            ),
          ),
          // RIGHT PANEL
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _mainTitle("CAREER OBJECTIVE"),
                  pInfoBox(objective, bg: _bg, radius: 12),
                  const SizedBox(height: 20),
                  _mainTitle("EDUCATION"),
                  ...edu.map((e) => _eduCard(pMap(e))),
                  const SizedBox(height: 20),
                  _mainTitle("PROJECTS"),
                  ...projects.map((p) => _projCard(pMap(p))),
                  const SizedBox(height: 20),
                  _mainTitle("INTERNSHIPS / EXPERIENCE"),
                  ...exp.map((e) => _expCard(pMap(e))),
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
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 1)),
  );

  Widget _skillBar(String name) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        const SizedBox(height: 3),
        LinearProgressIndicator(value: 0.8, backgroundColor: _secondary.withOpacity(0.3), color: _primary, minHeight: 5),
      ],
    ),
  );

  Widget _mainTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _primary)),
        const SizedBox(height: 4),
        Container(height: 2, width: 50, color: _primary),
      ],
    ),
  );

  Widget _expCard(Map<String, dynamic> exp) => pCard(
    bg: Colors.white, borderColor: _secondary.withOpacity(0.3), radius: 12,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(exp['role'], 'Role'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary)),
        const SizedBox(height: 2),
        Text("${pStr(exp['company'])} | ${pStr(exp['start_date'])} - ${pStr(exp['end_date'], 'Present')}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
  );

  Widget _eduCard(Map<String, dynamic> edu) => pCard(
    bg: Colors.white, borderColor: _secondary.withOpacity(0.3), radius: 12,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(edu['degree'], 'Degree'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary)),
        const SizedBox(height: 2),
        Text("${pStr(edu['institute'])} | ${pStr(edu['year_of_passing'])}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
  );

  Widget _projCard(Map<String, dynamic> p) => pCard(
    bg: Colors.white, borderColor: _secondary.withOpacity(0.3), radius: 12,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(p['title'], 'Project'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary)),
        if (pStr(p['description']).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(pStr(p['description']), style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ],
    ),
  );
}