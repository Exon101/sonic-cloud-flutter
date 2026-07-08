import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/upload_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart' as r;
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/glass_card.dart';

/// Shows a bottom sheet that lets the user pick an audio file from
/// their device and upload it to the Sonic Cloud backend.
///
/// On web, file_picker uses an <input type="file"> HTML element.
/// On mobile/desktop, it uses the native file picker.
///
/// After upload, the track is added to the local library and [onUploaded] fires.
Future<void> showUploadMusicSheet({
  required BuildContext context,
  required UploadService uploadService,
  required void Function(Track track) onUploaded,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(r.AppRadius.xl)),
    ),
    builder: (ctx) => _UploadMusicSheet(
      uploadService: uploadService,
      onUploaded: onUploaded,
    ),
  );
}

class _UploadMusicSheet extends StatefulWidget {
  const _UploadMusicSheet({
    required this.uploadService,
    required this.onUploaded,
  });

  final UploadService uploadService;
  final void Function(Track track) onUploaded;

  @override
  State<_UploadMusicSheet> createState() => _UploadMusicSheetState();
}

class _UploadMusicSheetState extends State<_UploadMusicSheet> {
  PlatformFile? _selectedFile;
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _albumCtrl = TextEditingController();
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.uploadService.addListener(_onUploadChange);
  }

  @override
  void dispose() {
    widget.uploadService.removeListener(_onUploadChange);
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    super.dispose();
  }

  void _onUploadChange() {
    if (mounted) {
      setState(() {
        _isUploading = widget.uploadService.isUploading;
        _error = widget.uploadService.lastError;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true, // Always get bytes — works on all platforms
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFile = file;
          if (_titleCtrl.text.isEmpty) {
            _titleCtrl.text = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
          }
        });
      }
    } catch (e) {
      setState(() => _error = 'File picker failed: $e');
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) {
      setState(() => _error = 'Please select a file first');
      return;
    }

    final file = _selectedFile!;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      setState(() => _error =
          'Could not read file bytes. On web, files must be <4.5MB. '
          'Try a smaller file or use the mobile/desktop app.');
      return;
    }

    // Warn on web for large files
    if (kIsWeb && bytes.length > 4 * 1024 * 1024) {
      setState(() => _error =
          'File is ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB. '
          'Web uploads are limited to ~4.5MB on Vercel Hobby plan. '
          'Try a smaller file or use the mobile/desktop app.');
      return;
    }

    setState(() {
      _error = null;
      _isUploading = true;
    });

    try {
      final track = await widget.uploadService.uploadFile(
        fileBytes: bytes,
        fileName: file.name,
        title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
        artist: _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : null,
        album: _albumCtrl.text.trim().isNotEmpty ? _albumCtrl.text.trim() : null,
      );
      widget.onUploaded(track);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.edgeMargin,
        right: AppSpacing.edgeMargin,
        top: AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'Upload Music',
              style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),

            // File picker
            GestureDetector(
              onTap: _isUploading ? null : _pickFile,
              child: GlassCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                borderRadius: 16,
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.audio_file : Icons.upload_file,
                      size: 48,
                      color: AppColors.secondaryContainer,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _selectedFile != null
                          ? _selectedFile!.name
                          : 'Tap to select an audio file',
                      style: AppTypography.bodyMd.copyWith(
                        color: _selectedFile != null
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(_selectedFile!.size),
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Metadata fields
            if (_selectedFile != null) ...[
              _Field(label: 'Title', controller: _titleCtrl),
              const SizedBox(height: AppSpacing.sm),
              _Field(label: 'Artist', controller: _artistCtrl),
              const SizedBox(height: AppSpacing.sm),
              _Field(label: 'Album', controller: _albumCtrl),
              const SizedBox(height: AppSpacing.md),
            ],

            // Progress
            if (_isUploading) ...[
              const LinearProgressIndicator(
                backgroundColor: AppColors.surfaceContainerHighest,
                color: AppColors.secondaryContainer,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Uploading…',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Upload button
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_isUploading || _selectedFile == null) ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.onSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_isUploading ? 'Uploading…' : 'Upload'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _Field({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      borderRadius: 12,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
          border: InputBorder.none,
        ),
        style: const TextStyle(color: AppColors.onSurface),
      ),
    );
  }
}
