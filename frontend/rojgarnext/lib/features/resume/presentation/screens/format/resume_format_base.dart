// lib/features/resume/presentation/screens/format/resume_format_base.dart
import 'package:flutter/material.dart';

abstract class ResumeFormatBase {
  String get id;
  String get name;
  String get icon;
  String get description;
  String get color;
  String get styleKey;
  String get templateType;
  String get badgeText;

  String generateHtml(Map<String, dynamic> resumeData);
  Widget buildPreview(BuildContext context, Map<String, dynamic> resumeData);

  // ==================== HTML HELPERS ====================
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

  // ==================== HTML ESCAPE METHOD (FIXED) ====================
  /// Escapes special characters to prevent HTML injection/rendering issues.
  String escapeHtml(String text) {
    if (text.isEmpty) return '';
    return text.replaceAllMapped(
      RegExp('[&<>"\']'), // <-- escaped single quote, non-raw string
      (match) {
        switch (match.group(0)) {
          case '&':
            return '&amp;';
          case '<':
            return '&lt;';
          case '>':
            return '&gt;';
          case '"':
            return '&quot;';
          case "'":
            return '&#039;';
          default:
            return match.group(0)!;
        }
      },
    );
  }

  // ==================== PREVIEW DATA HELPERS ====================
  Map<String, dynamic> pMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  List<dynamic> pList(dynamic v) => v is List ? v : [];

  String pStr(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  List<String> pSkills(dynamic v) {
    if (v is! Map) return [];
    final all = v['all'];
    if (all is! List) return [];
    return all
        .map((e) => e is Map ? pStr(e['name']) : e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> pLangs(List<dynamic> langs) {
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

  String pCert(Map<String, dynamic> c) {
    return [pStr(c['name']), pStr(c['issuer']), pStr(c['year'])]
        .where((s) => s.isNotEmpty)
        .join(' - ');
  }

  String pLocation(Map<String, dynamic> data) {
    final c = pMap(data['contact_info']);
    final a = pMap(c['current_address']);
    final parts = [pStr(a['city']), pStr(a['state'])]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  // ==================== SHARED PREVIEW WIDGETS ====================
  Widget pSectionTitle(String title,
      {required Color color,
      bool uppercase = false,
      bool underline = true,
      Color? underlineColor,
      double fontSize = 18,
      double underlineWidth = 60}) {
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

  Widget pInfoBox(String text,
      {required Color bg,
      Color? leftBorder,
      double radius = 8,
      TextStyle? textStyle}) {
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

  Widget pCard(
      {required Widget child,
      Color bg = const Color(0xFFFAFAFA),
      Color? leftBorder,
      Color? borderColor,
      double radius = 8,
      List<BoxShadow>? shadows}) {
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