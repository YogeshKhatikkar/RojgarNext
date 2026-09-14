// lib/features/resume/presentation/screens/format/formats/government_format.dart
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

  static const Color _navy = Color(0xFF1A237E);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _lightNavy = Color(0xFFE8EAF6);
  static const Color _border = Color(0xFFDDDDDD);
  static const Color _softBg = Color(0xFFFAFAFA);

  @override
  String generateHtml(Map<String, dynamic> resumeData) {
    final name = getString(resumeData, 'user_info', 'full_name');
    final email = getString(resumeData, 'contact_info', 'email');
    final phone = getString(resumeData, 'contact_info', 'phone');
    final location = getLocation(resumeData);
    final dob = getString(resumeData, 'user_info', 'date_of_birth');
    final gender = getString(resumeData, 'user_info', 'gender');
    final nationality = getString(resumeData, 'user_info', 'nationality');
    final category = getString(resumeData, 'user_info', 'category');
    final education = getList(resumeData, 'education');
    final experience = getList(resumeData, 'experience');
    final certifications = getList(resumeData, 'certifications');

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Times New Roman',serif;background:#f5f5f0;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;border:2px solid #1A237E;padding:30px}
.header{text-align:center;border-bottom:3px solid #1A237E;padding-bottom:15px;margin-bottom:20px}
.name{font-size:28px;font-weight:bold;color:#1A237E;letter-spacing:1px}
.contact-info{display:flex;justify-content:center;flex-wrap:wrap;gap:20px;margin-top:10px;font-size:14px}
.section-title{font-size:16px;font-weight:bold;color:#1A237E;border-bottom:2px solid #FFD700;padding-bottom:5px;margin:20px 0 10px 0;text-transform:uppercase}
table{width:100%;border-collapse:collapse;margin-bottom:15px}
th,td{border:1px solid #1A237E;padding:8px 12px;font-size:13px;text-align:left}
th{background:#E8EAF6;color:#1A237E;font-weight:bold}
.card-item{padding:12px;margin-bottom:10px;border:1px solid #ddd;background:#fafafa}
.card-title{font-weight:bold;color:#1A237E;font-size:14px}
.card-subtitle{font-size:13px;color:#555}
</style></head><body>
<div class="resume-container">
  <div class="header">
    <div class="name">${escapeHtml(name)}</div>
    <div style="font-size:14px;color:#555;">Assistant Engineer (Civil)</div>
    <div class="contact-info">
      <span>📞 ${escapeHtml(phone)}</span>
      <span>📧 ${escapeHtml(email)}</span>
      <span>📍 ${escapeHtml(location)}</span>
    </div>
  </div>
  
  <div class="section-title">Personal Details</div>
  <table>
    <tr><th width="30%">Date of Birth</th><td>${escapeHtml(dob)}</td></tr>
    <tr><th>Gender</th><td>${escapeHtml(gender)}</td></tr>
    <tr><th>Nationality</th><td>${escapeHtml(nationality)}</td></tr>
    <tr><th>Category</th><td>${escapeHtml(category)}</td></tr>
  </table>

  <div class="section-title">Educational Qualification</div>
  <table>
    <tr><th>Qualification</th><th>Board / University</th><th>Year</th><th>Percentage</th></tr>
    ${education.map((e) {
      final x = pMap(e);
      return '<tr><td>${escapeHtml(pStr(x['degree']))}</td><td>${escapeHtml(pStr(x['institute']))}</td><td>${escapeHtml(pStr(x['year_of_passing']))}</td><td>${escapeHtml(pStr(x['cgpa_percentage']))}%</td></tr>';
    }).join('')}
  </table>

  <div class="section-title">Professional Experience</div>
  ${experience.map((e) {
    final x = pMap(e);
    return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div><div style="margin-top:6px;font-size:13px;">${escapeHtml(pStr(x['description']))}</div></div>';
  }).join('')}

  <div class="section-title">Certifications & Training</div>
  ${certifications.map((c) => '<div class="card-item" style="font-size:13px;">• ${escapeHtml(pCert(pMap(c)))}</div>').join('')}
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
    final dob = pStr(u['date_of_birth']);
    final gender = pStr(u['gender']);
    final nationality = pStr(u['nationality']);
    final category = pStr(u['category']);
    final exp = pList(data['experience']);
    final edu = pList(data['education']);
    final certs = pList(data['certifications']);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _navy, width: 3))),
            child: Column(
              children: [
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _navy, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text("Assistant Engineer (Civil)", style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("📞 $phone", style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    Text("📧 $email", style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    Text("📍 $location", style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _govTitle("PERSONAL DETAILS"),
          Table(
            border: TableBorder.all(color: _navy),
            columnWidths: const {0: FractionColumnWidth(0.3), 1: FractionColumnWidth(0.7)},
            children: [
              _tableRow("Date of Birth", dob),
              _tableRow("Gender", gender),
              _tableRow("Nationality", nationality),
              _tableRow("Category", category),
            ],
          ),
          const SizedBox(height: 16),
          _govTitle("EDUCATIONAL QUALIFICATION"),
          Table(
            border: TableBorder.all(color: _navy),
            columnWidths: const {0: FractionColumnWidth(0.3), 1: FractionColumnWidth(0.3), 2: FractionColumnWidth(0.2), 3: FractionColumnWidth(0.2)},
            children: [
              const TableRow(
                decoration: BoxDecoration(color: _lightNavy),
                children: [
                  Padding(padding: EdgeInsets.all(8), child: Text("Qualification", style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text("Board / University", style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text("Year", style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text("Percentage", style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 12))),
                ],
              ),
              ...edu.map((e) {
                final x = pMap(e);
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(pStr(x['degree']), style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(pStr(x['institute']), style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(pStr(x['year_of_passing']), style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text("${pStr(x['cgpa_percentage'])}%", style: const TextStyle(fontSize: 12))),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          _govTitle("PROFESSIONAL EXPERIENCE"),
          ...exp.map((e) => _expCard(pMap(e))),
          const SizedBox(height: 16),
          _govTitle("CERTIFICATIONS & TRAINING"),
          ...certs.map((c) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text("• ${pCert(pMap(c))}", style: const TextStyle(fontSize: 12, color: _navy)))),
        ],
      ),
    );
  }

  Widget _govTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 4),
        Container(height: 2, width: 50, color: _gold),
      ],
    ),
  );

  TableRow _tableRow(String label, String value) => TableRow(
    children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 12))),
      Padding(padding: const EdgeInsets.all(8), child: Text(value, style: const TextStyle(fontSize: 12))),
    ],
  );

  Widget _expCard(Map<String, dynamic> exp) => pCard(
    bg: _softBg, borderColor: _border, radius: 0,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pStr(exp['role'], 'Role'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 2),
        Text("${pStr(exp['company'])} | ${pStr(exp['start_date'])} - ${pStr(exp['end_date'], 'Present')}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (pStr(exp['description']).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(pStr(exp['description']), style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ],
    ),
  );
}