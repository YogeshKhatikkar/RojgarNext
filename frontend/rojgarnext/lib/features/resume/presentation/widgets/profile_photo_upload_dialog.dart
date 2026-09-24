// lib/features/resume/presentation/widgets/profile_photo_upload_dialog.dart
// ✅ Has static show() → returns uploaded URL (String?)
// ✅ Uses UserProfileProvider → auto-syncs everywhere
// ✅ Shows current photo preview if provided

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rojgarnext/core/widgets/platform_file_picker.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/user/providers/user_profile_provider.dart';

class ProfilePhotoUploadDialog extends StatefulWidget {
  final VoidCallback? onUploadSuccess;
  final String? currentPhotoUrl;

  const ProfilePhotoUploadDialog({
    super.key,
    this.onUploadSuccess,
    this.currentPhotoUrl,
  });

  /// ✅ STATIC SHOW METHOD — returns the uploaded URL (or null if cancelled)
  /// Usage:
  ///   final url = await ProfilePhotoUploadDialog.show(context, currentPhotoUrl: url);
  static Future<String?> show(
    BuildContext context, {
    String? currentPhotoUrl,
  }) async {
    return showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProfilePhotoUploadDialog(
        currentPhotoUrl: currentPhotoUrl,
      ),
    );
  }

  @override
  State<ProfilePhotoUploadDialog> createState() =>
      _ProfilePhotoUploadDialogState();
}

class _ProfilePhotoUploadDialogState extends State<ProfilePhotoUploadDialog> {
  bool _isPicking = false;

  Future<void> _pickAndUpload() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final result = await PlatformFilePicker.pickImage();
      if (result == null || result.bytes == null) {
        if (mounted) setState(() => _isPicking = false);
        return;
      }

      final bytes = result.bytes!;
      if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;
        showMessage(context, "Image too large. Max: 5MB", isError: true);
        if (mounted) setState(() => _isPicking = false);
        return;
      }

      if (!mounted) return;
      final provider =
          Provider.of<UserProfileProvider>(context, listen: false);

      final ok = await provider.uploadProfilePhoto(
        fileBytes: bytes,
        fileName: result.name,
      );

      if (!mounted) return;
      if (ok) {
        final newUrl = provider.profilePhotoUrl ?? '';
        showMessage(context, "✅ Profile photo updated!");
        widget.onUploadSuccess?.call();
        Navigator.of(context).pop(newUrl); // ✅ returns String?
      } else {
        showMessage(
          context,
          provider.errorMessage ?? "Upload failed",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting =
        widget.currentPhotoUrl != null && widget.currentPhotoUrl!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Preview existing photo (if any)
            if (hasExisting)
              ClipOval(
                child: Image.network(
                  widget.currentPhotoUrl!,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (hasExisting) const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Upload Profile Photo",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Photo will be auto-applied to resume & dashboard instantly.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Consumer<UserProfileProvider>(
              builder: (context, provider, _) {
                if (provider.isUploadingPhoto) {
                  return const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text("Uploading & rebuilding resume..."),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isPicking ? null : _pickAndUpload,
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text("Select Photo"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}