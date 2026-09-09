// lib/features/resume/presentation/screens/format/resume_format_manager.dart
/// Manages all resume formats
import 'resume_format_base.dart';
import 'formats/classic_format.dart';
import 'formats/modern_format.dart';
import 'formats/tech_format.dart';
import 'formats/executive_format.dart';
import 'formats/government_format.dart';
import 'formats/fresher_format.dart';

class ResumeFormatManager {
  static final List<ResumeFormatBase> _formats = [
    ClassicFormat(),
    ModernFormat(),
    TechFormat(),
    ExecutiveFormat(),
    GovernmentFormat(),
    FresherFormat(),
  ];

  static List<ResumeFormatBase> get allFormats => _formats;

  static ResumeFormatBase? getFormatById(String id) {
    try {
      return _formats.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }

  static ResumeFormatBase getDefaultFormat() {
    return _formats.first;
  }

  static Map<String, dynamic> getFormatOptions(ResumeFormatBase format, Map<String, dynamic> resumeData) {
    switch (format.id) {
      case 'classic':
        return {
          'template': 'classic',
          'layout': 'traditional',
          'font': 'serif',
          'gradient': ['#1E3A8A', '#3B82F6'],
          'badge': 'Most Popular',
        };
      case 'modern':
        return {
          'template': 'modern',
          'layout': 'creative',
          'font': 'sans',
          'gradient': ['#9C27B0', '#E1BEE7'],
          'badge': 'Trending',
        };
      case 'tech':
        return {
          'template': 'tech',
          'layout': 'skills-first',
          'font': 'mono',
          'gradient': ['#00C853', '#00E676'],
          'badge': 'Developer',
        };
      case 'executive':
        return {
          'template': 'executive',
          'layout': 'leadership',
          'font': 'serif',
          'gradient': ['#BF360C', '#FF5722'],
          'badge': 'Premium',
        };
      case 'government':
        return {
          'template': 'government',
          'layout': 'formal',
          'font': 'serif',
          'gradient': ['#1A237E', '#3949AB'],
          'badge': 'Official',
        };
      case 'fresher':
        return {
          'template': 'fresher',
          'layout': 'education-first',
          'font': 'sans',
          'gradient': ['#00897B', '#26A69A'],
          'badge': 'New Grad',
        };
      default:
        return {};
    }
  }
}