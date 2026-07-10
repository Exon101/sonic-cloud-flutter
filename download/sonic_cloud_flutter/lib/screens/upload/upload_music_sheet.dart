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
    builder: (ctx) => _UploadMusicSheet(uploadService: uploadService, onUploaded: onUploaded),
  );
}

class _UploadMusicSheet extends StatefulWidget {
  const _UploadMusicSheet({required this.uploadService, required this.onUploaded});
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
    if (mounted) setState(() { _isUploading = widget.uploadService.isUploading; _error = widget.uploadService.lastError; });
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
        setState(() { _selectedFiles.addAll(result.files); _error = null; });
      }
    } catch (e) {
      setState(() => _error = 'File picker failed: $e');
    }
  }

  void _removeFile(int i) => setState(() => _selectedFiles.removeAt(i));

  Future<void> _upload() async {
    if (_selectedFiles.isEmpty) { setState(() => _error = 'Select at least one file'); return; }
    if (_selectedFiles.any((f) => f.bytes == null || f.bytes!.isEmpty)) {
      setState(() => _error = 'Could not read some files'); return;
    }
    if (kIsWeb) {
      final total = _selectedFiles.fold(0, (s, f) => s + f.size);
      if (total > 4 * 1024 * 1024) {
        setState(() => _error = 'Total ${(total / 1024 / 1024).toStringAsFixed(1)}MB exceeds web limit (~4.5MB)'); return;
      }
    }
    setState(() { _error = null; _isUploading = true; _results = null; });
    try {
      final filesList = _selectedFiles.map((f) => (bytes: f.bytes!, name: f.name)).toList();
      final result = await widget.uploadService.uploadMultiple(files: filesList);
      setState(() { _results = result; _isUploading = false; });
      for (final t in (result['tracks'] as List?) ?? []) {
        final tj = t as Map<String, dynamic>;
        widget.onUploaded(Track(
          id: tj['id'] as String,
          title: (tj['title'] as String?) ?? 'Unknown',
          artist: (tj['artist'] as String?) ?? 'Unknown Artist',
          album: (tj['album'] as String?) ?? '',
          albumArtist: '', genre: '', composer: '',
          year: (tj['year'] as int?) ?? 0,
          duration: Duration(seconds: ((tj['duration'] as num?)?.toDouble() ?? 0).toInt()),
          artUrl: '', audioUrl: (tj['sourceId'] as String?) ?? '',
          isCloudOnly: true, isFavorite: false, rating: 0, playCount: 0,
        ));
      }
      if ((result['errorCount'] as int? ?? 0) == 0 && mounted) {
        Future.delayed(const Duration(seconds: 3), () { if (mounted && !_isUploading) Navigator.of(context).pop(); });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isUploading = false; });
    }
  }

  String _fmt(int b) => b < 1024 ? '$b B' : b < 1048576 ? '${(b / 1024).toStringAsFixed(1)} KB' : '${(b / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: AppSpacing.edgeMargin, right: AppSpacing.edgeMargin, top: AppSpacing.lg),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.lg), decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2)))),
        Text('Upload Music', style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('Audio, ZIP, lyrics (.lrc), or metadata (.json)', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: _isUploading ? null : _pickFiles,
          child: GlassCard(padding: const EdgeInsets.all(AppSpacing.xl), borderRadius: 16, child: Column(children: [
            Icon(_selectedFiles.isEmpty ? Icons.upload_file : Icons.library_music, size: 48, color: AppColors.secondaryContainer),
            const SizedBox(height: AppSpacing.sm),
            Text(_selectedFiles.isEmpty ? 'Tap to select files' : '${_selectedFiles.length} file(s) selected',
              style: AppTypography.bodyMd.copyWith(color: _selectedFiles.isEmpty ? AppColors.onSurfaceVariant : AppColors.onSurface)),
            if (_selectedFiles.isNotEmpty) ...[const SizedBox(height: 4), Text(_fmt(_selectedFiles.fold(0, (s, f) => s + f.size)), style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant))],
          ])),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_selectedFiles.isNotEmpty) ...[
          ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200), child: ListView.builder(shrinkWrap: true, itemCount: _selectedFiles.length, itemBuilder: (ctx, i) {
            final f = _selectedFiles[i];
            return ListTile(leading: Icon(f.name.toLowerCase().endsWith('.zip') ? Icons.folder_zip_outlined : Icons.audio_file, color: AppColors.secondaryContainer, size: 28),
              title: Text(f.name, style: const TextStyle(color: AppColors.onSurface, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_fmt(f.size), style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
              trailing: _isUploading ? null : IconButton(icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant, size: 20), onPressed: () => _removeFile(i)));
          })),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_isUploading) ...[const LinearProgressIndicator(backgroundColor: AppColors.surfaceContainerHighest, color: AppColors.secondaryContainer), const SizedBox(height: AppSpacing.sm), Text('Uploading ${_selectedFiles.length} file(s)…', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant), textAlign: TextAlign.center), const SizedBox(height: AppSpacing.md)],
        if (_results != null) ...[_ResultsCard(results: _results!), const SizedBox(height: AppSpacing.md)],
        if (_error != null) ...[Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.4))), child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)))])), const SizedBox(height: AppSpacing.md)],
        SizedBox(height: 48, child: _results == null ? ElevatedButton.icon(
          onPressed: (_isUploading || _selectedFiles.isEmpty) ? null : _upload,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryContainer, foregroundColor: AppColors.onSecondary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: _isUploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_rounded),
          label: Text(_isUploading ? 'Uploading…' : 'Upload ${_selectedFiles.length} file(s)'),
        ) : ElevatedButton(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceContainerHigh, foregroundColor: AppColors.onSurface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Done'))),
        const SizedBox(height: AppSpacing.lg),
      ])),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.results});
  final Map<String, dynamic> results;
  @override
  Widget build(BuildContext context) {
    return GlassCard(padding: const EdgeInsets.all(AppSpacing.md), borderRadius: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 20), const SizedBox(width: 8), Text('Upload Complete', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface))]),
      const SizedBox(height: 8),
      ...[('Tracks', results['trackCount'] ?? 0), ('Lyrics', results['lyricsCount'] ?? 0), ('Errors', results['errorCount'] ?? 0)].where((e) => e.$2 as int > 0 || e.$1 == 'Tracks').map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.$1, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)), Text('${e.$2}', style: TextStyle(color: e.$1 == 'Errors' ? Colors.red : AppColors.secondaryContainer, fontSize: 13, fontWeight: FontWeight.w600))]))),
    ]));
  }
}
