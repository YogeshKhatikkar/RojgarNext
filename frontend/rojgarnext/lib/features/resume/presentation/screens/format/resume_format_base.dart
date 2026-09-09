// lib/features/resume/presentation/screens/format/resume_format_base.dart
// ✅ Base class with all helper methods for resume formats

import 'dart:convert';

abstract class ResumeFormatBase {
  String get id;
  String get name;
  String get icon;
  String get description;
  String get color;
  String get styleKey;
  String get templateType;
  String get badgeText;

  /// Generate the complete HTML for the resume
  String generateHtml(Map<String, dynamic> resumeData);

  // ==================== HELPER METHODS ====================

  /// Safely get a string from nested map
  String getString(Map<String, dynamic> data, String section, String key) {
    try {
      final sectionData = data[section] as Map<String, dynamic>?;
      if (sectionData == null) return '';
      final value = sectionData[key];
      return value?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Get location string from contact_info
  String getLocation(Map<String, dynamic> data) {
    try {
      final contact = data['contact_info'] as Map<String, dynamic>?;
      if (contact == null) return '';
      final address = contact['current_address'] as Map<String, dynamic>?;
      if (address != null) {
        final city = address['city']?.toString() ?? '';
        final state = address['state']?.toString() ?? '';
        if (city.isNotEmpty && state.isNotEmpty) return '$city, $state';
        if (city.isNotEmpty) return city;
        if (state.isNotEmpty) return state;
      }
      return contact['location']?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Get a list from a key
  List<dynamic> getList(Map<String, dynamic> data, String key) {
    try {
      final list = data[key] as List<dynamic>?;
      return list ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Get skills list (from skills.all)
  List<String> getSkills(Map<String, dynamic> data) {
    try {
      final skills = data['skills'] as Map<String, dynamic>?;
      if (skills == null) return [];
      final all = skills['all'] as List<dynamic>?;
      if (all == null) return [];
      return all.map((s) => (s as Map)['name']?.toString() ?? s.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get a map (for social links)
  Map<String, String> getMap(Map<String, dynamic> data, String key) {
    try {
      final map = data[key] as Map<String, dynamic>?;
      if (map == null) return {};
      return Map<String, String>.from(map.map((k, v) => MapEntry(k, v.toString())));
    } catch (e) {
      return {};
    }
  }

  /// Escape HTML characters to prevent XSS and ensure valid display
  String escapeHtml(String text) {
    if (text.isEmpty) return '';
    final Map<String, String> escapeMap = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;',
    };
    return text.replaceAllMapped(RegExp('[&<>"\']'), (match) => escapeMap[match.group(0)]!);
  }

  /// Build certifications section HTML (if certifications exist)
  String buildCertificationsSection(List<dynamic> certifications) {
    if (certifications.isEmpty) return '';
    final certHtml = certifications.map((cert) {
      final name = cert['name']?.toString() ?? '';
      final issuer = cert['issuer']?.toString() ?? '';
      final year = cert['year']?.toString() ?? '';
      final details = [name, issuer, year].where((s) => s.isNotEmpty).join(' - ');
      return '''
        <div style="padding: 4px 0;">
          <span class="skill-chip">${escapeHtml(details)}</span>
        </div>
      ''';
    }).join('');
    return '''
      <div style="padding: 20px 0;">
        <div class="section-title">📜 Certifications</div>
        $certHtml
      </div>
    ''';
  }

  /// Build projects section HTML (if projects exist)
  String buildProjectsSection(List<dynamic> projects) {
    if (projects.isEmpty) return '';
    final projectHtml = projects.map((proj) {
      final title = proj['title']?.toString() ?? 'Project';
      final description = proj['description']?.toString() ?? '';
      final technologies = (proj['technologies'] as List?)?.map((t) => t.toString()).toList() ?? [];
      final techHtml = technologies.isNotEmpty
          ? '<div style="margin-top:6px;">${technologies.map((t) => '<span class="skill-chip">${escapeHtml(t)}</span>').join(' ')}</div>'
          : '';
      return '''
        <div class="card-item">
          <div class="card-title">${escapeHtml(title)}</div>
          ${description.isNotEmpty ? '<div style="font-size:13px;margin-top:4px;">${escapeHtml(description)}</div>' : ''}
          $techHtml
        </div>
      ''';
    }).join('');
    return '''
      <div class="section">
        <div class="section-title">🛠️ Projects</div>
        $projectHtml
      </div>
    ''';
  }

  /// Build social links section (if any social links exist)
  String buildSocialSection(Map<String, String> socialLinks) {
    final filtered = socialLinks.entries.where((e) => e.value.isNotEmpty).toList();
    if (filtered.isEmpty) return '';
    final linksHtml = filtered.map((e) {
      final icon = _getSocialIcon(e.key);
      return '''
        <div style="margin: 4px 0;">
          <span style="font-weight:500;">$icon</span>
          <a href="${escapeHtml(e.value)}" target="_blank" style="color:#1E3A8A;text-decoration:underline;">${escapeHtml(e.value)}</a>
        </div>
      ''';
    }).join('');
    return '''
      <div class="section">
        <div class="section-title">🔗 Social Links</div>
        $linksHtml
      </div>
    ''';
  }

  String _getSocialIcon(String key) {
    final icons = {
      'linkedin': '🔗',
      'github': '🐙',
      'portfolio': '🌐',
      'twitter': '🐦',
      'facebook': '📘',
      'instagram': '📸',
      'youtube': '▶️',
      'personal_website': '🌐',
    };
    return icons[key] ?? '🔗';
  }
}