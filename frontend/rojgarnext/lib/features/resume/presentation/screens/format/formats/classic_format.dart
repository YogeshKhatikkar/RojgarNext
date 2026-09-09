// lib/features/resume/presentation/screens/format/formats/classic_format.dart
// ✅ FIXED: Added safe .toString() for year_of_passing to handle int values

import '../resume_format_base.dart';

class ClassicFormat extends ResumeFormatBase {
  @override
  String get id => 'classic';

  @override
  String get name => 'Classic Professional';

  @override
  String get icon => '📄';

  @override
  String get description => 'Clean & Traditional Design';

  @override
  String get color => '#1E3A8A';

  @override
  String get styleKey => 'classic';

  @override
  String get templateType => 'classic';

  @override
  String get badgeText => 'Most Popular';

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

    // Build languages HTML
    final languagesHtml = languages.map((lang) {
      final langName = lang['name']?.toString() ?? '';
      final proficiency = lang['proficiency']?.toString() ?? '';
      final displayText = proficiency.isNotEmpty ? '$langName - $proficiency' : langName;
      return '<span class="skill-chip">${escapeHtml(displayText)}</span>';
    }).join(' ');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(name)} - Professional Resume</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Georgia', 'Times New Roman', serif;
      background: #f8f8f8;
      padding: 30px 20px;
      line-height: 1.6;
    }
    .resume-container {
      max-width: 1000px;
      margin: 0 auto;
      background: white;
      box-shadow: 0 10px 40px rgba(0,0,0,0.1);
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #1E3A8A, #3B82F6);
      padding: 40px 35px;
      color: white;
      text-align: center;
    }
    .name { font-size: 36px; font-weight: bold; margin-bottom: 8px; }
    .contact-info {
      display: flex;
      justify-content: center;
      flex-wrap: wrap;
      gap: 20px;
      margin-top: 15px;
      font-size: 14px;
    }
    .contact-info span { 
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    .section {
      padding: 25px 35px;
      border-bottom: 1px solid #eef2f6;
    }
    .section:last-child { border-bottom: none; }
    .section-title {
      font-size: 20px;
      font-weight: bold;
      color: #1E3A8A;
      border-bottom: 2px solid #1E3A8A;
      padding-bottom: 10px;
      margin-bottom: 20px;
    }
    .card-item {
      padding: 15px 18px;
      margin-bottom: 12px;
      background: #fafafa;
      border-radius: 8px;
      border-left: 4px solid #1E3A8A;
    }
    .card-title { font-size: 16px; font-weight: bold; }
    .card-subtitle { font-size: 14px; opacity: 0.8; }
    .card-meta {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 8px;
      padding-top: 8px;
      border-top: 1px dashed #ddd;
    }
    .meta-badge {
      background: white;
      padding: 3px 12px;
      border-radius: 20px;
      font-size: 11px;
      border: 1px solid #ddd;
    }
    .skill-chip {
      display: inline-block;
      background: #f0f0f0;
      padding: 5px 14px;
      border-radius: 20px;
      font-size: 12px;
      margin: 3px;
      color: #333;
    }
    .two-column {
      display: grid;
      grid-template-columns: 1fr 1.2fr;
      gap: 25px;
      padding: 0 35px 25px 35px;
    }
    .summary-text {
      font-size: 15px;
      line-height: 1.7;
      padding: 15px 20px;
      background: #f8f8f8;
      border-radius: 8px;
    }
    @media (max-width: 768px) {
      body { padding: 15px; }
      .section { padding: 18px; }
      .header { padding: 25px 18px; }
      .name { font-size: 28px; }
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
      <div class="section-title">📌 Professional Summary</div>
      <div class="summary-text">${escapeHtml(summary)}</div>
    </div>
    
    <div class="two-column">
      <div>
        <div style="padding: 0 0 20px 0;">
          <div class="section-title">⚡ Skills</div>
          ${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}
        </div>
        ${buildCertificationsSection(certifications)}
        <div style="padding: 20px 0;">
          <div class="section-title">🌐 Languages</div>
          $languagesHtml
        </div>
      </div>
      <div>
        <div style="padding: 0 0 20px 0;">
          <div class="section-title">💼 Work Experience</div>
          ${experience.map((exp) => '''
            <div class="card-item">
              <div class="card-title">${escapeHtml(exp['role'])}</div>
              <div class="card-subtitle">${escapeHtml(exp['company'])}</div>
              <div class="card-meta">
                <span class="meta-badge">📅 ${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</span>
              </div>
              ${exp['description'].toString().isNotEmpty ? '<div style="margin-top:8px;font-size:13px;">${escapeHtml(exp['description'])}</div>' : ''}
            </div>
          ''').join('')}
        </div>
      </div>
    </div>
    
    <div class="section">
      <div class="section-title">🎓 Education</div>
      ${education.map((edu) => '''
        <div class="card-item">
          <div class="card-title">${escapeHtml(edu['degree'])}</div>
          <div class="card-subtitle">${escapeHtml(edu['institute'])}</div>
          <div class="card-meta">
            <span class="meta-badge">📅 Year: ${escapeHtml(edu['year_of_passing'].toString())}</span>
            ${edu['cgpa_percentage']?.toString().isNotEmpty == true ? '<span class="meta-badge">📊 ${escapeHtml(edu['result_type'])}: ${escapeHtml(edu['cgpa_percentage'])}</span>' : ''}
          </div>
        </div>
      ''').join('')}
    </div>
    
    ${buildProjectsSection(projects)}
    
    <div class="section">
      <div class="section-title">🎯 Career Objective</div>
      <div class="summary-text">${escapeHtml(careerObjective)}</div>
    </div>
    
    ${buildSocialSection(socialLinks)}
  </div>
</body>
</html>
    ''';
  }
}