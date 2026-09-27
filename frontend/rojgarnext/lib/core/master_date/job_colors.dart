// lib/core/master_date/job_colors.dart
// ✅ MASTER DATA FOR JOB COLOR TYPES
// Colors supported: blue, green, red, orange, purple, teal, pink,
//                   indigo, amber, cyan, grey, white

import 'package:flutter/material.dart';

class JobColorMasterData {
  /// All allowed color type keys — MUST match backend regex
  static const List<String> colorKeys = [
    'blue',
    'green',
    'red',
    'orange',
    'purple',
    'teal',
    'pink',
    'indigo',
    'amber',
    'cyan',
    'grey',
    'white',
  ];

  /// Human-readable labels
  static const Map<String, String> colorLabels = {
    'blue': 'Blue',
    'green': 'Green',
    'red': 'Red',
    'orange': 'Orange',
    'purple': 'Purple',
    'teal': 'Teal',
    'pink': 'Pink',
    'indigo': 'Indigo',
    'amber': 'Amber',
    'cyan': 'Cyan',
    'grey': 'Grey',
    'white': 'White',
  };

  /// Icon for each color
  static const Map<String, IconData> colorIcons = {
    'blue': Icons.work,
    'green': Icons.account_balance,
    'red': Icons.local_fire_department,
    'orange': Icons.trending_up,
    'purple': Icons.wifi,
    'teal': Icons.medical_services,
    'pink': Icons.favorite,
    'indigo': Icons.school,
    'amber': Icons.star,
    'cyan': Icons.water_drop,
    'grey': Icons.business,
    'white': Icons.light_mode,
  };

  /// Primary color for each key
  static const Map<String, Color> primaryColors = {
    'blue': Color(0xFF2563EB),
    'green': Color(0xFF10B981),
    'red': Color(0xFFEF4444),
    'orange': Color(0xFFF59E0B),
    'purple': Color(0xFF8B5CF6),
    'teal': Color(0xFF14B8A6),
    'pink': Color(0xFFEC4899),
    'indigo': Color(0xFF4F46E5),
    'amber': Color(0xFFD97706),
    'cyan': Color(0xFF06B6D4),
    'grey': Color(0xFF6B7280),
    'white': Color(0xFF9CA3AF),
  };

  /// Secondary (lighter) color for gradient
  static const Map<String, Color> secondaryColors = {
    'blue': Color(0xFF60A5FA),
    'green': Color(0xFF34D399),
    'red': Color(0xFFF87171),
    'orange': Color(0xFFFBBF24),
    'purple': Color(0xFFA78BFA),
    'teal': Color(0xFF2DD4BF),
    'pink': Color(0xFFF472B6),
    'indigo': Color(0xFF818CF8),
    'amber': Color(0xFFFCD34D),
    'cyan': Color(0xFF22D3EE),
    'grey': Color(0xFF9CA3AF),
    'white': Color(0xFFE5E7EB),
  };

  /// Background tint color (for chips/cards)
  static const Map<String, Color> tintColors = {
    'blue': Color(0xFFEFF6FF),
    'green': Color(0xFFECFDF5),
    'red': Color(0xFFFEF2F2),
    'orange': Color(0xFFFFFBEB),
    'purple': Color(0xFFF5F3FF),
    'teal': Color(0xFFF0FDFA),
    'pink': Color(0xFFFDF2F8),
    'indigo': Color(0xFFEEF2FF),
    'amber': Color(0xFFFFFBEB),
    'cyan': Color(0xFFECFEFF),
    'grey': Color(0xFFF3F4F6),
    'white': Color(0xFFF9FAFB),
  };

  static Color getPrimary(String? key) {
    if (key == null) return primaryColors['blue']!;
    final k = key.toLowerCase().trim();
    return primaryColors[k] ?? primaryColors['blue']!;
  }

  static Color getSecondary(String? key) {
    if (key == null) return secondaryColors['blue']!;
    final k = key.toLowerCase().trim();
    return secondaryColors[k] ?? secondaryColors['blue']!;
  }

  static Color getTint(String? key) {
    if (key == null) return tintColors['blue']!;
    final k = key.toLowerCase().trim();
    return tintColors[k] ?? tintColors['blue']!;
  }

  static String getLabel(String? key) {
    if (key == null) return 'Blue';
    final k = key.toLowerCase().trim();
    return colorLabels[k] ?? 'Blue';
  }

  static IconData getIcon(String? key) {
    if (key == null) return colorIcons['blue']!;
    final k = key.toLowerCase().trim();
    return colorIcons[k] ?? colorIcons['blue']!;
  }

  static LinearGradient getGradient(String? key) {
    return LinearGradient(
      colors: [getPrimary(key), getSecondary(key)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static String normalize(String? raw) {
    if (raw == null) return 'blue';
    final k = raw.toLowerCase().trim();
    if (colorKeys.contains(k)) return k;
    if (k == 'gray') return 'grey';
    return 'blue';
  }
}