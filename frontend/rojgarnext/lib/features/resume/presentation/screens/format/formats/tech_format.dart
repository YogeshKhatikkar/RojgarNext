// lib/features/resume/presentation/screens/format/formats/tech_format.dart
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

  static const Color _bg = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF00E676);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _text = Color(0xFFE2E8F0);
  static const Color _border = Color(0xFF334155);

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
    final projects = getList(resumeData, 'projects');

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Fira Code',monospace;background:#0a0e27;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#0f172a;border:1px solid #334155;border-radius:12px;overflow:hidden;display:flex;flex-direction:column}
.header{background:#0a0e27;padding:25px 30px;border-bottom:2px solid #00E676;display:flex;justify-content:space-between;align-items:center}
.name{font-size:30px;font-weight:700;color:#00E676;letter-spacing:2px}
.contact-info{text-align:right;font-size:13px;color:#94a3b8}
.columns{display:flex;padding:20px}
.col{flex:1;padding:0 15px}
.col:first-child{border-right:1px solid #334155}
.col:last-child{border-left:1px solid #334155}
.section-title{font-size:16px;font-weight:600;color:#00E676;border-bottom:2px solid #00E676;padding-bottom:6px;margin:15px 0 10px 0}
.card-item{padding:12px;margin-bottom:10px;background:#1e293b;border:1px solid #334155;border-radius:8px}
.card-title{color:#00E676;font-weight:600;font-size:14px}
.card-subtitle{font-size:12px;color:#94a3b8}
.summary-text{font-size:13px;line-height:1.6;padding:12px;background:#1e293b;border-left:4px solid #00E676;border-radius:6px;color:#e2e8f0}
.skill-chip{display:inline-block;background:rgba(0,230,118,.12);color:#00E676;padding:4px 10px;border-radius:6px;font-size:11px;margin:3px;border:1px solid #00E676}
</style></head><body>
<div class="resume-container">
  <div class="header">
    <div>
      <div class="name">${escapeHtml(name)}</div>
      <div style="color:#94a3b8;font-size:14px;">Full Stack Developer | Python | Flutter | FastAPI</div>
    </div>
    <div class="contact-info">
      📞 ${escapeHtml(phone)}<br>📧 ${escapeHtml(email)}<br>📍 ${escapeHtml(location)}
    </div>
  </div>
  <div class="columns">
    <div class="col">
      <div class="section-title">// SUMMARY</div>
      <div class="summary-text">${escapeHtml(summary)}</div>
      <div class="section-title">// SKILLS</div>
      ${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}
      <div class="section-title">// TOOLS & DEVOPS</div>
      <div style="display:flex;flex-wrap:wrap;gap:6px;">
        <span class="skill-chip">Docker</span>
        <span class="skill-chip">Git</span>
        <span class="skill-chip">AWS</span>
      </div>
    </div>
    <div class="col">
      <div class="section-title">// WORK EXPERIENCE</div>
      ${experience.map((e) {
        final x = pMap(e);
        return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div><div style="margin-top:6px;font-size:12px;color:#94a3b8;">${escapeHtml(pStr(x['description']))}</div></div>';
      }).join('')}
      <div class="section-title">// EDUCATION</div>
      ${education.map((e) {
        final x = pMap(e);
        return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['degree']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['institute']))} | ${escapeHtml(pStr(x['year_of_passing']))}</div></div>';
      }).join('')}
    </div>
    <div class="col">
      <div class="section-title">// KEY STRENGTHS</div>
      <div class="card-item"><div style="color:#00E676;">Problem Solving</div></div>
      <div class="card-item"><div style="color:#00E676;">Team Collaboration</div></div>
      <div class="section-title">// FEATURED PROJECTS</div>
      ${projects.map((p) {
        final x = pMap(p);
        return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['title']))}</div><div style="font-size:12px;margin-top:4px;color:#94a3b8;">${escapeHtml(pStr(x['description']))}</div></div>';
      }).join('')}
    </div>
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
      color: _bg,
      child: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0E27),
              border: Border(bottom: BorderSide(color: _accent, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _accent, letterSpacing: 2, fontFamily: 'monospace')),
                    const SizedBox(height: 4),
                    const Text("Full Stack Developer | Python | Flutter | FastAPI", style: TextStyle(color: _muted, fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("📞 $phone", style: const TextStyle(color: _muted, fontSize: 11)),
                    Text("📧 $email", style: const TextStyle(color: _muted, fontSize: 11)),
                    Text("📍 $location", style: const TextStyle(color: _muted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          // COLUMNS
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // COL 1
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: _border))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _techTitle("// SUMMARY"),
                        pInfoBox(summary, bg: _card, leftBorder: _accent, textStyle: const TextStyle(fontSize: 12, height: 1.5, color: _text)),
                        const SizedBox(height: 16),
                        _techTitle("// SKILLS"),
                        Wrap(spacing: 6, runSpacing: 6, children: skills.map((s) => _techChip(s)).toList()),
                        const SizedBox(height: 16),
                        _techTitle("// TOOLS & DEVOPS"),
                        Wrap(spacing: 6, runSpacing: 6, children: ["Docker", "Git", "AWS", "Linux"].map((t) => _techChip(t)).toList()),
                      ],
                    ),
                  ),
                ),
                // COL 2
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: _border))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _techTitle("// WORK EXPERIENCE"),
                        ...exp.map((e) => _expCard(pMap(e))),
                        const SizedBox(height: 16),
                        _techTitle("// EDUCATION"),
                        ...edu.map((e) => _eduCard(pMap(e))),
                      ],
                    ),
                  ),
                ),
                // COL 3
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _techTitle("// KEY STRENGTHS"),
                        _strengthItem("Problem Solving"),
                        _strengthItem("Team Collaboration"),
                        _strengthItem("Clean Code"),
                        const SizedBox(height: 16),
                        _techTitle("// FEATURED PROJECTS"),
                        ...projects.map((p) => _projCard(pMap(p))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _techTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _accent, fontFamily: 'monospace')),
        const SizedBox(height: 4),
        Container(height: 1.5, width: 40, color: _accent),
      ],
    ),
  );

  Widget _techChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: _accent.withOpacity(0.12), border: Border.all(color: _accent), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: const TextStyle(fontSize: 10, color: _accent, fontFamily: 'monospace')),
  );

  Widget _strengthItem(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: _card, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: _accent, fontSize: 12)),
    ),
  );

  Widget _expCard(Map<String, dynamic> exp) => pCard(
    bg: _card, borderColor: _border, radius: 8,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(exp['role'], 'Role'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
        const SizedBox(height: 2),
        Text("${pStr(exp['company'])} | ${pStr(exp['start_date'])} - ${pStr(exp['end_date'], 'Present')}", style: const TextStyle(fontSize: 11, color: _muted)),
        if (pStr(exp['description']).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(pStr(exp['description']), style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFFCBD5E1))),
        ],
      ],
    ),
  );

  Widget _eduCard(Map<String, dynamic> edu) => pCard(
    bg: _card, borderColor: _border, radius: 8,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(edu['degree'], 'Degree'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
        const SizedBox(height: 2),
        Text("${pStr(edu['institute'])} | ${pStr(edu['year_of_passing'])}", style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    ),
  );

  Widget _projCard(Map<String, dynamic> p) => pCard(
    bg: _card, borderColor: _border, radius: 8,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(p['title'], 'Project'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
        if (pStr(p['description']).isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(pStr(p['description']), style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFFCBD5E1))),
        ],
      ],
    ),
  );
}