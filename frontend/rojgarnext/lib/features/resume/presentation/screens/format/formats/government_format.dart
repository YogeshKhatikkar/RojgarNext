// lib/features/resume/presentation/screens/format/formats/government_format.dart
import '../resume_format_base.dart';

class GovernmentFormat extends ResumeFormatBase {
  @override
  String get id => 'government';
  @override
  String get name => 'Government / PSU';
  @override
  String get icon => '🏛️';
  @override
  String get description => 'Formal Government Layout';
  @override
  String get color => '#1A237E';
  @override
  String get styleKey => 'government';
  @override
  String get templateType => 'government';
  @override
  String get badgeText => 'Official';

  @override
  String generateHtml(Map<String, dynamic> resumeData) {
    final name = getString(resumeData, 'user_info', 'full_name');
    final email = getString(resumeData, 'contact_info', 'email');
    final phone = getString(resumeData, 'contact_info', 'phone');
    final location = getLocation(resumeData);
    final education = getList(resumeData, 'education');
    final experience = getList(resumeData, 'experience');
    final skills = getSkills(resumeData);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(name)} - Government Resume</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Times New Roman', serif;
      background: #f5f5f0;
      padding: 30px 20px;
      line-height: 1.6;
    }
    .resume-container {
      max-width: 1000px;
      margin: 0 auto;
      background: white;
      border: 2px solid #1A237E;
      overflow: hidden;
    }
    .header {
      background: #1A237E;
      padding: 35px 30px;
      color: white;
      text-align: center;
      border-bottom: 3px solid #FFD700;
    }
    .name { font-size: 34px; font-weight: bold; letter-spacing: 1px; }
    .contact-info {
      display: flex;
      justify-content: center;
      flex-wrap: wrap;
      gap: 20px;
      margin-top: 12px;
      font-size: 13px;
    }
    .section { padding: 22px 30px; border-bottom: 1px solid #eee; }
    .section-title {
      font-size: 18px;
      font-weight: bold;
      color: #1A237E;
      border-bottom: 2px solid #FFD700;
      padding-bottom: 8px;
      margin-bottom: 16px;
    }
    .card-item { padding: 12px 16px; margin-bottom: 10px; border: 1px solid #ddd; background: #fafafa; }
    .card-title { font-weight: bold; color: #1A237E; }
    .skill-chip {
      display: inline-block;
      background: #e8eaf6;
      color: #1A237E;
      padding: 4px 12px;
      border-radius: 15px;
      font-size: 12px;
      margin: 2px;
    }
    .two-column {
      display: grid;
      grid-template-columns: 1fr 1.2fr;
      gap: 20px;
      padding: 0 30px 20px 30px;
    }
    @media (max-width: 768px) {
      .section { padding: 16px; }
      .header { padding: 20px 16px; }
      .name { font-size: 26px; }
      .two-column { grid-template-columns: 1fr; padding: 0 16px 16px 16px; }
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
    <div class="two-column">
      <div>
        <div style="padding:0 0 16px 0;">
          <div class="section-title">Skills</div>
          ${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}
        </div>
      </div>
      <div>
        <div style="padding:0 0 16px 0;">
          <div class="section-title">Experience</div>
          ${experience.map((exp) => '''
            <div class="card-item">
              <div class="card-title">${escapeHtml(exp['role'])}</div>
              <div>${escapeHtml(exp['company'])}</div>
              <div style="font-size:12px;color:#666;">${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</div>
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
          <div>${escapeHtml(edu['institute'])}</div>
          <div style="font-size:12px;color:#666;">Year: ${escapeHtml(edu['year_of_passing'].toString())}</div>
        </div>
      ''').join('')}
    </div>
  </div>
</body>
</html>
    ''';
  }
}