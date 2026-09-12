// lib/features/resume/presentation/screens/format/resume_format_base.dart
// ✅ Base class — abstract buildPreview() + shared HTML & preview helpers
// Future style updates NEVER require changes in resume_format_popup.dart

import 'package:flutter/material.dart';

abstract class ResumeFormatBase {
  // ==================== METADATA ====================
  String get id;
  String get name;
  String get icon;
  String get description;
  String get color;
  String get styleKey;
  String get templateType;
  String get badgeText;

  /// HTML for PDF export / Copy HTML (unchanged)
  String generateHtml(Map<String, dynamic> resumeData);

  /// ✅ NATIVE Flutter preview — each format implements its own styling
  Widget buildPreview(BuildContext context, Map<String, dynamic> resumeData);

  // ==========================================================================
  // HTML HELPERS (kept for PDF export / Copy HTML)
  // ==========================================================================
  String getString(Map<String, dynamic> data, String section, String key) {
    try {
      final s = data[section] as Map<String, dynamic>?;
      if (s == null) return '';
      return s[key]?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String getLocation(Map<String, dynamic> data) {
    try {
      final c = data['contact_info'] as Map<String, dynamic>?;
      if (c == null) return '';
      final a = c['current_address'] as Map<String, dynamic>?;
      if (a != null) {
        final city = a['city']?.toString() ?? '';
        final state = a['state']?.toString() ?? '';
        if (city.isNotEmpty && state.isNotEmpty) return '$city, $state';
        if (city.isNotEmpty) return city;
        if (state.isNotEmpty) return state;
      }
      return c['location']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  List<dynamic> getList(Map<String, dynamic> data, String key) {
    try {
      return (data[key] as List<dynamic>?) ?? [];
    } catch (_) {
      return [];
    }
  }

  List<String> getSkills(Map<String, dynamic> data) {
    try {
      final s = data['skills'] as Map<String, dynamic>?;
      if (s == null) return [];
      final all = s['all'] as List<dynamic>?;
      if (all == null) return [];
      return all
          .map((e) => (e as Map)['name']?.toString() ?? e.toString())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, String> getMap(Map<String, dynamic> data, String key) {
    try {
      final m = data[key] as Map<String, dynamic>?;
      if (m == null) return {};
      return Map<String, String>.from(
        m.map((k, v) => MapEntry(k, v.toString())),
      );
    } catch (_) {
      return {};
    }
  }

  String escapeHtml(String text) {
    if (text.isEmpty) return '';
    return text.replaceAllMapped(
      RegExp('[&<>"\']'),
      (m) => const {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;',
      }[m.group(0)]!,
    );
  }

  String buildCertificationsSection(List<dynamic> certifications) {
    if (certifications.isEmpty) return '';
    final certHtml = certifications.map((cert) {
      final name = cert['name']?.toString() ?? '';
      final issuer = cert['issuer']?.toString() ?? '';
      final year = cert['year']?.toString() ?? '';
      final details =
          [name, issuer, year].where((s) => s.isNotEmpty).join(' - ');
      return '<div style="padding: 4px 0;">'
          '<span class="skill-chip">${escapeHtml(details)}</span>'
          '</div>';
    }).join();
    return '<div style="padding: 20px 0;">'
        '<div class="section-title">📜 Certifications</div>'
        '$certHtml</div>';
  }

  String buildProjectsSection(List<dynamic> projects) {
    if (projects.isEmpty) return '';
    final html = projects.map((proj) {
      final title = proj['title']?.toString() ?? 'Project';
      final description = proj['description']?.toString() ?? '';
      final technologies =
          (proj['technologies'] as List?)?.map((t) => t.toString()).toList() ??
              [];
      final techHtml = technologies.isNotEmpty
          ? '<div style="margin-top:6px;">'
              '${technologies.map((t) => '<span class="skill-chip">${escapeHtml(t)}</span>').join(' ')}'
              '</div>'
          : '';
      return '<div class="card-item">'
          '<div class="card-title">${escapeHtml(title)}</div>'
          '${description.isNotEmpty ? '<div style="font-size:13px;margin-top:4px;">${escapeHtml(description)}</div>' : ''}'
          '$techHtml</div>';
    }).join();
    return '<div class="section"><div class="section-title">🛠️ Projects</div>$html</div>';
  }

  String buildSocialSection(Map<String, String> socialLinks) {
    final filtered = socialLinks.entries.where((e) => e.value.isNotEmpty).toList();
    if (filtered.isEmpty) return '';
    final linksHtml = filtered.map((e) {
      final icon = _socialIcon(e.key);
      return '<div style="margin: 4px 0;">'
          '<span style="font-weight:500;">$icon</span> '
          '<a href="${escapeHtml(e.value)}" target="_blank" style="color:#1E3A8A;text-decoration:underline;">${escapeHtml(e.value)}</a>'
          '</div>';
    }).join();
    return '<div class="section"><div class="section-title">🔗 Social Links</div>$linksHtml</div>';
  }

  String _socialIcon(String key) {
    const icons = {
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

  // ==========================================================================
  // PREVIEW DATA HELPERS (static — usable inside any format)
  // ==========================================================================
  static Map<String, dynamic> pMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  static List<dynamic> pList(dynamic v) => v is List ? v : [];

  static String pStr(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  static List<String> pSkills(dynamic v) {
    if (v is! Map) return [];
    final all = v['all'];
    if (all is! List) return [];
    return all
        .map((e) => e is Map ? pStr(e['name']) : e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<String> pLangs(List<dynamic> langs) {
    return langs
        .map((l) {
          final x = pMap(l);
          final n = pStr(x['name']);
          final p = pStr(x['proficiency']);
          return p.isNotEmpty ? '$n ($p)' : n;
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String pCert(Map<String, dynamic> c) {
    return [
      pStr(c['name']),
      pStr(c['issuer']),
      pStr(c['year']),
    ].where((s) => s.isNotEmpty).join(' - ');
  }

  static String pLocation(Map<String, dynamic> data) {
    final c = pMap(data['contact_info']);
    final a = pMap(c['current_address']);
    final parts = [pStr(a['city']), pStr(a['state'])]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  // ==========================================================================
  // SHARED PREVIEW WIDGETS (each format can use these directly)
  // ==========================================================================
  static Widget pChip(
    String text, {
    Color bg = const Color(0xFFF0F0F0),
    Color fg = const Color(0xFF333333),
    Color? border,
    double radius = 20,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }

  static Widget pTag(
    String text, {
    Color bg = const Color(0xFFF0F0F0),
    Color fg = const Color(0xFF555555),
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
    );
  }

  static Widget pChipsWrap(
    List<String> items, {
    Color bg = const Color(0xFFF0F0F0),
    Color fg = const Color(0xFF333333),
    Color? border,
    double radius = 20,
  }) {
    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: items
          .map((s) => pChip(s, bg: bg, fg: fg, border: border, radius: radius))
          .toList(),
    );
  }

  static Widget pContactRow(
    IconData icon,
    String text, {
    required Color color,
  }) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  static Widget pSectionTitle(
    String title, {
    required Color color,
    bool uppercase = false,
    bool underline = true,
    Color? underlineColor,
    double fontSize = 18,
    double underlineWidth = 60,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uppercase ? title.toUpperCase() : title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: uppercase ? 1 : 0.3,
            ),
          ),
          if (underline)
            Container(
              margin: const EdgeInsets.only(top: 6),
              height: 2.5,
              width: underlineWidth,
              color: underlineColor ?? color,
            ),
        ],
      ),
    );
  }

  static Widget pInfoBox(
    String text, {
    required Color bg,
    Color? leftBorder,
    double radius = 8,
    TextStyle? textStyle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: leftBorder != null
            ? Border(left: BorderSide(color: leftBorder, width: 4))
            : null,
      ),
      child: Text(
        text,
        style: textStyle ??
            const TextStyle(
                fontSize: 14, height: 1.5, color: Color(0xFF222222)),
      ),
    );
  }

  static Widget pCard({
    required Widget child,
    Color bg = const Color(0xFFFAFAFA),
    Color? leftBorder,
    Color? borderColor,
    double radius = 8,
    List<BoxShadow>? shadows,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border(
          left: leftBorder != null
              ? BorderSide(color: leftBorder, width: 4)
              : BorderSide.none,
          top: borderColor != null
              ? BorderSide(color: borderColor)
              : BorderSide.none,
          right: borderColor != null
              ? BorderSide(color: borderColor)
              : BorderSide.none,
          bottom: borderColor != null
              ? BorderSide(color: borderColor)
              : BorderSide.none,
        ),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}