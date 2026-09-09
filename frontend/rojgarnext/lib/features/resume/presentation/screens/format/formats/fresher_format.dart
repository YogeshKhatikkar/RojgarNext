// lib/features/resume/presentation/screens/format/formats/fresher_format.dart
import '../resume_format_base.dart';

class FresherFormat extends ResumeFormatBase {
  @override
  String get id => 'fresher';
  @override
  String get name => 'Fresher / Entry Level';
  @override
  String get icon => '🎓';
  @override
  String get description => 'Education-Focused Design';
  @override
  String get color => '#00897B';
  @override
  String get styleKey => 'fresher';
  @override
  String get templateType => 'fresher';
  @override
  String get badgeText => 'New Grad';

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
    final certifications = getList(resumeData, 'certifications');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(name)} - Fresher Resume</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #e0f2f1, #b2dfdb);
      padding: 30px 20px;
      line-height: 1.6;
    }
    .resume-container {
      max-width: 1000px;
      margin: 0 auto;
      background: white;
      border-radius: 20px;
      overflow: hidden;
      box-shadow: 0 10px 40px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #00897B, #26A69A);
      padding: 35px 30px;
      color: white;
      text-align: center;
      border-radius: 20px 20px 0 0;
    }
    .name { font-size: 34px; font-weight: bold; }
    .contact-info {
      display: flex;
      justify-content: center;
      flex-wrap: wrap;
      gap: 18px;
      margin-top: 12px;
      font-size: 13px;
    }
    .section { padding: 22px 30px; }
    .section-title {
      font-size: 18px;
      font-weight: 600;
      color: #00897B;
      border-bottom: 2px solid #26A69A;
      padding-bottom: 8px;
      margin-bottom: 16px;
    }
    .card-item {
      padding: 12px 16px;
      margin-bottom: 10px;
      background: #f5f5f5;
      border-radius: 12px;
    }
    .card-title { font-weight: bold; color: #00897B; }
    .card-subtitle { font-size: 13px; color: #555; }
    .skill-chip {
      display: inline-block;
      background: #e0f2f1;
      color: #00897B;
      padding: 5px 14px;
      border-radius: 20px;
      font-size: 12px;
      margin: 3px;
      font-weight: 500;
    }
    .summary-text {
      font-size: 14px;
      line-height: 1.7;
      padding: 16px 20px;
      background: #f5f5f5;
      border-radius: 12px;
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
    <div class="section">
      <div class="section-title">About Me</div>
      <div class="summary-text">${escapeHtml(summary)}</div>
    </div>
    <div class="two-column">
      <div>
        <div style="padding:0 0 16px 0;">
          <div class="section-title">Skills</div>
          ${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}
        </div>
        ${buildCertificationsSection(certifications)}
      </div>
      <div>
        <div style="padding:0 0 16px 0;">
          <div class="section-title">Education</div>
          ${education.map((edu) => '''
            <div class="card-item">
              <div class="card-title">${escapeHtml(edu['degree'])}</div>
              <div class="card-subtitle">${escapeHtml(edu['institute'])}</div>
              <div style="font-size:12px;color:#888;">Year: ${escapeHtml(edu['year_of_passing'].toString())}</div>
            </div>
          ''').join('')}
        </div>
        ${experience.isNotEmpty ? '''
          <div style="padding:0 0 16px 0;">
            <div class="section-title">Experience</div>
            ${experience.map((exp) => '''
              <div class="card-item">
                <div class="card-title">${escapeHtml(exp['role'])}</div>
                <div class="card-subtitle">${escapeHtml(exp['company'])}</div>
                <div style="font-size:12px;color:#888;">${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</div>
              </div>
            ''').join('')}
          </div>
        ''' : ''}
        ${buildProjectsSection(projects)}
      </div>
    </div>
  </div>
</body>
</html>
    ''';
  }
}