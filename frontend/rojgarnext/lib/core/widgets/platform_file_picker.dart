// lib/core/widgets/platform_file_picker.dart
// ✅ COMPLETE FILE PICKER - Works on ALL Platforms (Mobile, Web, Desktop)

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/platform_utils.dart';

class PlatformFilePicker {
  /// Pick a file with platform-aware error handling
  static Future<PlatformFileResult?> pickFile({
    required List<String> allowedExtensions,
    bool allowMultiple = false,
  }) async {
    try {
      // ✅ Works on all platforms (Mobile, Web, Desktop)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: true, // ✅ CRITICAL: Gets bytes for web compatibility
      );

      if (result == null) return null;

      final file = result.files.first;
      
      return PlatformFileResult(
        name: file.name,
        bytes: file.bytes,
        size: file.size,
        path: file.path,
        extension: file.extension ?? '',
      );
    } catch (e) {
      debugPrint('❌ File picker error: $e');
      throw Exception(PlatformUtils.getFilePickerErrorMessage(e));
    }
  }

  /// Pick image file (JPG, JPEG, PNG)
  static Future<PlatformFileResult?> pickImage() async {
    return pickFile(allowedExtensions: ['jpg', 'jpeg', 'png']);
  }

  /// Pick document file (PDF, DOC, DOCX)
  static Future<PlatformFileResult?> pickDocument() async {
    return pickFile(allowedExtensions: ['pdf', 'doc', 'docx']);
  }

  /// Pick PDF file only
  static Future<PlatformFileResult?> pickPDF() async {
    return pickFile(allowedExtensions: ['pdf']);
  }

  /// Pick any file type
  static Future<PlatformFileResult?> pickAnyFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      
      if (result == null) return null;
      final file = result.files.first;
      return PlatformFileResult(
        name: file.name,
        bytes: file.bytes,
        size: file.size,
        path: file.path,
        extension: file.extension ?? '',
      );
    } catch (e) {
      debugPrint('❌ File picker error: $e');
      throw Exception(PlatformUtils.getFilePickerErrorMessage(e));
    }
  }
}

class PlatformFileResult {
  final String name;
  final Uint8List? bytes;
  final int size;
  final String? path;
  final String extension;

  PlatformFileResult({
    required this.name,
    this.bytes,
    required this.size,
    this.path,
    required this.extension,
  });

  bool get hasBytes => bytes != null;
  bool get hasPath => path != null && path!.isNotEmpty;
}