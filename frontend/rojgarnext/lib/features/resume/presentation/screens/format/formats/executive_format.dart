// lib/features/resume/presentation/screens/format/formats/executive_format.dart
import '../resume_format_base.dart';

class ExecutiveFormat extends ResumeFormatBase {
  @override
  String get id => 'executive';

  @override
  String get name => 'Executive Leadership';

  @override
  String get icon => '👔';

  @override
  String get description => 'Premium Professional Format';

  @override
  String get color => '#BF360C';

  @override
  String get styleKey => 'executive';

  @override
  String get templateType => 'executive';

  @override
  String get badgeText => 'Premium';

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

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(name)} - Executive Resume</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Playfair Display', 'Georgia', serif;
      background: #fdfbf7;
      padding: 30px 20px;
      line-height: 1.6;
    }
    .resume-container {
      max-width: 1000px;
      margin: 0 auto;
      background: white;
      border: 1px solid #d4af37;
      border-radius: 8px;
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #2c1810, #4a2818);
      padding: 45px 35px;
      color: white;
      border-bottom: 3px solid #d4af37;
      text-align: center;
    }
    .name { font-size: 42px; font-weight: bold; letter-spacing: 3px; }
    .contact-info {
      display: flex;
      justify-content: center;
      flex-wrap: wrap;
      gap: 24px;
      margin-top: 15px;
      font-size: 14px;
    }
    .section { padding: 25px 35px; }
    .section-title {
      font-size: 20px;
      font-weight: bold;
      color: #2c1810;
      border-bottom: 2px solid #d4af37;
      padding-bottom: 10px;
      margin-bottom: 20px;
    }
    .card-item {
      padding: 15px 18px;
      margin-bottom: 12px;
      background: #fff9ef;
      border-left: 4px solid #d4af37;
      border-radius: 4px;
    }
    .card-title { font-size: 16px; font-weight: bold; color: #2c1810; }
    .card-subtitle { font-size: 14px; color: #666; }
    .skill-chip {
      display: inline-block;
      background: #d4af3720;
      color: #4a2818;
      padding: 5px 14px;
      border-radius: 25px;
      font-size: 12px;
      margin: 3px;
      border: 1px solid #d4af37;
    }
    .summary-text {
      font-size: 15px;
      line-height: 1.7;
      padding: 18px 22px;
      background: #fff9ef;
      border-left: 4px solid #d4af37;
      font-style: italic;
    }
    .two-column {
      display: grid;
      grid-template-columns: 1fr 1.2fr;
      gap: 25px;
      padding: 0 35px 25px 35px;
    }
    @media (max-width: 768px) {
      .section { padding: 18px; }
      .header { padding: 25px 18px; }
      .name { font-size: 30px; }
      .two-column { grid-template-columns: 1fr; padding: 0 18px 18px 18px; }
    }
  </style>
</head>
<body>
  <div class="resume-container">
    <div class="header">
      <div class="name">${escapeHtml(name)}</div>
      <div class="contact-info">
        ${email.isNotEmpty ? '<span>📧 ${escapeHtml(email)}</span>' : ''}
        ${phone.isNotEmpty ? '<span>📞 ${escapeHtml(phone)}</span>' : ''}
        ${location.isNotEmpty ? '<span>📍 ${escapeHtml(location)}</span>' : ''}
      </div>
    </div>
    <div class="section">
      <div class="section-title">Executive Summary</div>
      <div class="summary-text">${escapeHtml(summary)}</div>
    </div>
    <div class="two-column">
      <div>
        <div style="padding:0 0 20px 0;">
          <div class="section-title">Core Skills</div>
          ${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}
        </div>
      </div>
      <div>
        <div style="padding:0 0 20px 0;">
          <div class="section-title">Experience</div>
          ${experience.map((exp) => '''
            <div class="card-item">
              <div class="card-title">${escapeHtml(exp['role'])}</div>
              <div class="card-subtitle">${escapeHtml(exp['company'])}</div>
              <div style="font-size:12px;color:#888;margin-top:4px;">${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</div>
            </div>
          ''').join('')}
        </div>
      </div>
    </div>
    <div class="section">
      <div class="section-title">Education</div>
      ${education.map((edu) => '''
        <div class="card-item">
          <div class="card-title">${escapeHtml(edu['degree'])}</div>
          <div class="card-subtitle">${escapeHtml(edu['institute'])}</div>
        </div>
      ''').join('')}
    </div>
  </div>
</body>
</html>
    ''';
  }
}