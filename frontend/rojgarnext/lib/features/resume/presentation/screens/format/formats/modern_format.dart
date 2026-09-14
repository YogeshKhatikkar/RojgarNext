// lib/features/resume/presentation/screens/format/formats/modern_format.dart
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

  static const Color _primary = Color(0xFF9C27B0);
  static const Color _secondary = Color(0xFFE1BEE7);
  static const Color _dark = Color(0xFF4A148C);
  static const Color _bg = Color(0xFFF3E5F5);

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
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Poppins',sans-serif;background:#f5f7fa;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;border-radius:20px;overflow:hidden;box-shadow:0 10px 40px rgba(0,0,0,.1);display:flex}
.left-panel{width:35%;background:#F3E5F5;padding:25px}
.right-panel{width:65%;padding:25px}
.header{text-align:center;margin-bottom:20px}
.name{font-size:28px;font-weight:700;color:#4A148C}
.section-title{font-size:16px;font-weight:600;color:#9C27B0;border-bottom:2px solid #9C27B0;padding-bottom:6px;margin:20px 0 12px 0}
.skill-bar{margin-bottom:8px}
.skill-name{font-size:13px;color:#333;display:flex;justify-content:space-between}
.bar-bg{height:6px;background:#E1BEE7;border-radius:3px;margin-top:3px}
.bar-fill{height:6px;background:linear-gradient(90deg,#9C27B0,#E1BEE7);border-radius:3px}
.card-item{padding:12px;margin-bottom:10px;background:#fff;border-radius:12px;border-left:4px solid #9C27B0;box-shadow:0 2px 8px rgba(0,0,0,.05)}
.card-title{font-weight:700;color:#4A148C;font-size:15px}
.card-subtitle{font-size:12px;color:#777}
.summary-text{font-size:13px;line-height:1.6;padding:12px;background:#F3E5F5;border-radius:10px}
</style></head><body>
<div class="resume-container">
  <div class="left-panel">
    <div class="header">
      <div class="name">${escapeHtml(name)}</div>
      <div style="font-size:12px;color:#7B1FA2;">UI/UX Designer & Digital Creator</div>
      <div style="font-size:12px;color:#555;margin-top:8px;">📧 ${escapeHtml(email)}</div>
      <div style="font-size:12px;color:#555;">📞 ${escapeHtml(phone)}</div>
      <div style="font-size:12px;color:#555;">📍 ${escapeHtml(location)}</div>
    </div>
    <div class="section-title">About Me</div>
    <div class="summary-text">${escapeHtml(summary)}</div>
    <div class="section-title">My Skills</div>
    ${skills.take(6).map((s) => '<div class="skill-bar"><div class="skill-name"><span>${escapeHtml(s)}</span><span>90%</span></div><div class="bar-bg"><div class="bar-fill" style="width:90%"></div></div></div>').join('')}
    <div class="section-title">Tools</div>
    <div style="display:flex;flex-wrap:wrap;gap:8px;">
      <span style="padding:4px 10px;background:#9C27B0;color:#fff;border-radius:15px;font-size:11px;">Figma</span>
      <span style="padding:4px 10px;background:#9C27B0;color:#fff;border-radius:15px;font-size:11px;">Photoshop</span>
      <span style="padding:4px 10px;background:#9C27B0;color:#fff;border-radius:15px;font-size:11px;">Illustrator</span>
    </div>
  </div>
  <div class="right-panel">
    <div class="section-title">Experience</div>
    ${experience.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div><div style="margin-top:6px;font-size:12px;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}
    
    <div class="section-title">Featured Projects</div>
    ${projects.map((p) {
      final x = pMap(p);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['title']))}</div><div style="font-size:12px;margin-top:4px;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}
    
    <div class="section-title">Education</div>
    ${education.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['degree']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['institute']))} | ${escapeHtml(pStr(x['year_of_passing']))}</div></div>';
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
    final projects = pList(data['projects']);

    return Container(
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT PANEL
          Container(
            width: 260,
            color: _bg,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _dark), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      const Text("UI/UX Designer & Digital Creator", style: TextStyle(fontSize: 11, color: _primary)),
                      const SizedBox(height: 10),
                      Text("📧 $email", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      Text("📞 $phone", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      Text("📍 $location", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sidebarTitle("ABOUT ME"),
                pInfoBox(summary, bg: _bg, radius: 10, textStyle: const TextStyle(fontSize: 12, height: 1.5)),
                const SizedBox(height: 16),
                _sidebarTitle("MY SKILLS"),
                ...skills.take(6).map((s) => _skillBar(s)),
                const SizedBox(height: 16),
                _sidebarTitle("TOOLS"),
                Wrap(spacing: 6, runSpacing: 6, children: ["Figma", "Photoshop", "Illustrator"].map((t) => _toolChip(t)).toList()),
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
                  _mainTitle("EXPERIENCE"),
                  ...exp.map((e) => _expCard(pMap(e))),
                  const SizedBox(height: 16),
                  _mainTitle("FEATURED PROJECTS"),
                  ...projects.map((p) => _projCard(pMap(p))),
                  const SizedBox(height: 16),
                  _mainTitle("EDUCATION"),
                  ...edu.map((e) => _eduCard(pMap(e))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 1)),
  );

  Widget _skillBar(String name) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(name, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          const Text("90%", style: TextStyle(fontSize: 11, color: _primary)),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: 0.9, backgroundColor: _secondary.withOpacity(0.3), color: _primary, minHeight: 5),
      ],
    ),
  );

  Widget _toolChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.white)),
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
    bg: Colors.white, leftBorder: _primary, radius: 12,
    shadows: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3))],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(exp['role'], 'Role'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _dark)),
        const SizedBox(height: 2),
        Text("${pStr(exp['company'])} | ${pStr(exp['start_date'])} - ${pStr(exp['end_date'], 'Present')}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (pStr(exp['description']).isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(pStr(exp['description']), style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ],
    ),
  );

  Widget _eduCard(Map<String, dynamic> edu) => pCard(
    bg: Colors.white, leftBorder: _primary, radius: 12,
    shadows: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3))],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(edu['degree'], 'Degree'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text("${pStr(edu['institute'])} | ${pStr(edu['year_of_passing'])}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
  );

  Widget _projCard(Map<String, dynamic> p) => pCard(
    bg: Colors.white, leftBorder: _primary, radius: 12,
    shadows: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3))],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(p['title'], 'Project'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        if (pStr(p['description']).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(pStr(p['description']), style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ],
    ),
  );
}