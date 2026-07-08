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

/// Shows a bottom sheet for uploading music files.
///
/// Supports:
///   - Single audio file (mp3, flac, wav, aac, ogg, m4a, opus)
///   - Multiple audio files (batch upload)
///   - ZIP archives (server extracts + processes audio + lyrics + metadata)
///   - .lrc lyrics files (auto-paired with tracks by filename)
///   - metadata.json (describes track titles/artists/albums)
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
  final List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  String? _error;
  Map<String, dynamic>? _results;

  @override
  void initState() {
    super.initState();
    widget.uploadService.addListener(_onUploadChange);
  }

  @override
  void dispose() {
    widget.uploadService.removeListener(_onUploadChange);
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

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a', 'opus', 'zip', 'lrc', 'json'],
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'File picker failed: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _upload() async {
    if (_selectedFiles.isEmpty) {
      setState(() => _error = 'Please select at least one file');
      return;
    }

    final filesWithoutBytes = _selectedFiles.where((f) => f.bytes == null || f.bytes!.isEmpty);
    if (filesWithoutBytes.isNotEmpty) {
      setState(() => _error = 'Could not read ${filesWithoutBytes.length} file(s).');
      return;
    }

    if (kIsWeb) {
      final totalSize = _selectedFiles.fold<int>(0, (sum, f) => sum + f.size);
      if (totalSize > 4 * 1024 * 1024) {
        setState(() => _error = 'Total size ${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB exceeds web limit (~4.5MB). Use mobile/desktop app.');
        return;
      }
    }

    setState(() {
      _error = null;
      _isUploading = true;
      _results = null;
    });

    try {
      final filesList = _selectedFiles.map((f) => (bytes: f.bytes!, name: f.name)).toList();
      final result = await widget.uploadService.uploadMultiple(files: filesList);

      setState(() {
        _results = result;
        _isUploading = false;
      });

      final tracks = (result['tracks'] as List?) ?? [];
      for (final t in tracks) {
        final trackJson = t as Map<String, dynamic>;
        final track = Track(
          id: trackJson['id'] as String,
          title: (trackJson['title'] as String?) ?? 'Unknown',
          artist: (trackJson['artist'] as String?) ?? 'Unknown Artist',
          album: (trackJson['album'] as String?) ?? '',
          albumArtist: '',
          genre: '',
          composer: '',
          year: (trackJson['year'] as int?) ?? 0,
          duration: Duration(seconds: ((trackJson['duration'] as num?)?.toDouble() ?? 0).toInt()),
          artUrl: '',
          audioUrl: (trackJson['sourceId'] as String?) ?? '',
          isCloudOnly: true,
          isFavorite: false,
          rating: 0,
          playCount: 0,
        );
        widget.onUploaded(track);
      }

      if ((result['errorCount'] as int? ?? 0) == 0 && mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_isUploading) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isUploading = false;
        });
      }
    }
  }

  IconData _fileIcon(String name) {
    final ext = name.toLowerCase();
    if (ext.endsWith('.zip')) return Icons.folder_zip_outlined;
    if (ext.endsWith('.lrc') || ext.endsWith('.txt')) return Icons.lyrics_outlined;
    if (ext.endsWith('.json')) return Icons.description_outlined;
    return Icons.audio_file;
  }

  Color _fileIconColor(String name) {
    if (name.toLowerCase().endsWith('.zip')) return Colors.amber;
    if (name.toLowerCase().endsWith('.lrc')) return Colors.green;
    if (name.toLowerCase().endsWith('.json')) return Colors.blue;
    return AppColors.secondaryContainer;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
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
            Text('Upload Music', style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'Audio, ZIP, lyrics (.lrc), or metadata (.json)\nZIP can contain music + lyrics + metadata together',
              style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: _isUploading ? null : _pickFiles,
              child: GlassCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                borderRadius: 16,
                child: Column(
                  children: [
                    Icon(_selectedFiles.isEmpty ? Icons.upload_file : Icons.library_music, size: 48, color: AppColors.secondaryContainer),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _selectedFiles.isEmpty ? 'Tap to select files' : '${_selectedFiles.length} file(s) selected',
                      style: AppTypography.bodyMd.copyWith(color: _selectedFiles.isEmpty ? AppColors.onSurfaceVariant : AppColors.onSurface),
                    ),
                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_formatFileSize(_selectedFiles.fold(0, (s, f) => s + f.size)),
                          style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_selectedFiles.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (ctx, i) {
                    final file = _selectedFiles[i];
                    return ListTile(
                      leading: Icon(_fileIcon(file.name), color: _fileIconColor(file.name), size: 28),
                      title: Text(file.name, style: const TextStyle(color: AppColors.onSurface, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_formatFileSize(file.size), style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                      trailing: _isUploading ? null : IconButton(icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant, size: 20), onPressed: () => _removeFile(i)),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_isUploading) ...[
              const LinearProgressIndicator(backgroundColor: AppColors.surfaceContainerHighest, color: AppColors.secondaryContainer),
              const SizedBox(height: AppSpacing.sm),
              Text('Uploading ${_selectedFiles.length} file(s)…', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_results != null) ...[
              _ResultsCard(results: _results!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.4))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_results == null)
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_isUploading || _selectedFiles.isEmpty) ? null : _upload,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryContainer, foregroundColor: AppColors.onSecondary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: _isUploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_rounded),
                  label: Text(_isUploading ? 'Uploading…' : 'Upload ${_selectedFiles.length} file(s)'),
                ),
              )
            else
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceContainerHigh, foregroundColor: AppColors.onSurface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Done'),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.results});
  final Map<String, dynamic> results;

  @override
  Widget build(BuildContext context) {
    final trackCount = results['trackCount'] as int? ?? 0;
    final lyricsCount = results['lyricsCount'] as int? ?? 0;
    final errorCount = results['errorCount'] as int? ?? 0;
    final totalSize = results['totalSize'] as int? ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text('Upload Complete', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface)),
          ]),
          const SizedBox(height: 8),
          _StatRow(label: 'Tracks uploaded', value: '$trackCount', color: AppColors.secondaryContainer),
          if (lyricsCount > 0) _StatRow(label: 'Lyrics paired', value: '$lyricsCount', color: Colors.green),
          if (errorCount > 0) _StatRow(label: 'Errors', value: '$errorCount', color: Colors.red),
          _StatRow(label: 'Total size', value: totalSize < 1024 * 1024 ? '${(totalSize / 1024).toStringAsFixed(1)} KB' : '${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB', color: AppColors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
