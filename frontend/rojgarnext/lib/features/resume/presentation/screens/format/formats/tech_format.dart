// lib/features/resume/presentation/screens/format/formats/tech_format.dart
import '../resume_format_base.dart';

class TechFormat extends ResumeFormatBase {
  @override
  String get id => 'tech';
  @override
  String get name => 'Tech / IT Specialist';
  @override
  String get icon => '💻';
  @override
  String get description => 'Skills-Focused Technical Resume';
  @override
  String get color => '#00C853';
  @override
  String get styleKey => 'tech';
  @override
  String get templateType => 'tech';
  @override
  String get badgeText => 'Developer';

  @override
  String generateHtml(Map<String, dynamic> resumeData) {
    final name = getString(resumeData, 'user_info', 'full_name');
    final email = getString(resumeData, 'contact_info', 'email');
    final phone = getString(resumeData, 'contact_info', 'phone');
    final github = getString(resumeData, 'social_links', 'github');
    final linkedin = getString(resumeData, 'social_links', 'linkedin');
    final portfolio = getString(resumeData, 'social_links', 'portfolio');
    final summary = getString(resumeData, 'professional_summary', '');
    final education = getList(resumeData, 'education');
    final experience = getList(resumeData, 'experience');
    final skills = getSkills(resumeData);
    final certifications = getList(resumeData, 'certifications');
    final projects = getList(resumeData, 'projects');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(name)} - Technical Resume</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Fira Code', 'Courier New', monospace;
      background: #0a0e27;
      padding: 30px 20px;
      line-height: 1.6;
    }
    .resume-container {
      max-width: 1000px;
      margin: 0 auto;
      background: #0f172a;
      border: 1px solid #334155;
      border-radius: 12px;
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #00C853, #00E676);
      padding: 35px 30px;
      color: #0a0e27;
      text-align: center;
      border-bottom: 2px solid #00FF88;
    }
    .name { 
      font-size: 36px; 
      font-weight: 700; 
      letter-spacing: 2px;
      font-family: 'Fira Code', monospace;
    }
    .contact-info {
      display: flex;
      justify-content: center;
      flex-wrap: wrap;
      gap: 16px;
      margin-top: 12px;
      font-size: 13px;
    }
    .contact-info span { 
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(0,0,0,0.1);
      padding: 4px 14px;
      border-radius: 20px;
    }
    .section {
      padding: 20px 30px;
    }
    .section-title {
      font-size: 18px;
      font-weight: 600;
      color: #00E676;
      border-bottom: 2px solid #00E676;
      padding-bottom: 8px;
      margin-bottom: 16px;
      font-family: 'Fira Code', monospace;
    }
    .card-item {
      padding: 14px 16px;
      margin-bottom: 12px;
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 10px;
    }
    .card-title { font-size: 15px; font-weight: 600; color: #00E676; }
    .card-subtitle { font-size: 13px; color: #94a3b8; }
    .card-meta {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 6px;
      padding-top: 6px;
      border-top: 1px solid #1e293b;
    }
    .meta-badge {
      background: #0f172a;
      color: #94a3b8;
      padding: 3px 10px;
      border-radius: 16px;
      font-size: 10px;
      border: 1px solid #334155;
    }
    .skill-chip {
      display: inline-block;
      background: #00E67620;
      color: #00E676;
      padding: 5px 14px;
      border-radius: 8px;
      font-size: 12px;
      margin: 3px;
      border: 1px solid #00E676;
      font-family: 'Fira Code', monospace;
    }
    .two-column {
      display: grid;
      grid-template-columns: 1fr 1.2fr;
      gap: 20px;
      padding: 0 30px 20px 30px;
    }
    .summary-text {
      font-size: 14px;
      line-height: 1.7;
      padding: 16px 20px;
      background: #1e293b;
      border-left: 4px solid #00E676;
      border-radius: 8px;
      color: #e2e8f0;
    }
    .social-link {
      color: #00E676;
      text-decoration: none;
      margin-right: 16px;
      font-size: 12px;
    }
    @media (max-width: 768px) {
      body { padding: 15px; }
      .section { padding: 16px; }
      .header { padding: 20px 16px; }
      .name { font-size: 28px; }
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
        ${github.isNotEmpty ? '<span>🐙 ${escapeHtml(github)}</span>' : ''}
        ${linkedin.isNotEmpty ? '<span>🔗 ${escapeHtml(linkedin)}</span>' : ''}
      </div>
    </div>
    
    <div class="section">
      <div class="section-title">// SUMMARY</div>
      <div class="summary-text">${escapeHtml(summary)}</div>
    </div>
    
    <div class="two-column">
      <div>
        <div style="padding: 0 0 16px 0;">
          <div class="section-title">// SKILLS</div>
          ${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}
        </div>
        ${buildCertificationsSection(certifications)}
      </div>
      <div>
        <div style="padding: 0 0 16px 0;">
          <div class="section-title">// EXPERIENCE</div>
          ${experience.map((exp) => '''
            <div class="card-item">
              <div class="card-title">${escapeHtml(exp['role'])}</div>
              <div class="card-subtitle">${escapeHtml(exp['company'])}</div>
              <div class="card-meta">
                <span class="meta-badge">📅 ${escapeHtml(exp['start_date'])} - ${escapeHtml(exp['end_date'] ?? 'Present')}</span>
              </div>
              ${exp['description'].toString().isNotEmpty ? '<div style="margin-top:6px;font-size:12px;color:#94a3b8;">${escapeHtml(exp['description'])}</div>' : ''}
            </div>
          ''').join('')}
        </div>
      </div>
    </div>
    
    <div class="section">
      <div class="section-title">// EDUCATION</div>
      ${education.map((edu) => '''
        <div class="card-item">
          <div class="card-title">${escapeHtml(edu['degree'])}</div>
          <div class="card-subtitle">${escapeHtml(edu['institute'])}</div>
          <div class="card-meta">
            <span class="meta-badge">📅 ${escapeHtml(edu['year_of_passing'].toString())}</span>
            ${edu['cgpa_percentage']?.toString().isNotEmpty == true ? '<span class="meta-badge">📊 ${escapeHtml(edu['cgpa_percentage'])}</span>' : ''}
          </div>
        </div>
      ''').join('')}
    </div>
    
    ${buildProjectsSection(projects)}
    
    <div style="padding: 16px 30px; border-top: 1px solid #334155; text-align: center; color: #64748b; font-size: 12px;">
      ${portfolio.isNotEmpty ? '<a href="${escapeHtml(portfolio)}" class="social-link">🌐 Portfolio</a>' : ''}
      Built with RojgarNext
    </div>
  </div>
</body>
</html>
    ''';
  }
}