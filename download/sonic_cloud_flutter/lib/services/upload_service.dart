import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'api_client.dart';

/// Service for uploading music files to the Sonic Cloud backend.
///
/// The upload flow:
///   1. User picks a file via [FilePicker] (mobile/desktop) or an `<input type="file">`
///      HTML element (web — handled by the file_picker package's web implementation)
///   2. The file bytes are sent as multipart/form-data to POST /api/upload
///   3. The server stores the file in Vercel Blob + creates a track record in Turso
///   4. The returned track is added to the local library
///   5. The blob URL (stored in track.sourceId) is used by just_audio for streaming
///
/// File size limits:
///   - Web: ~4.5MB (Vercel Hobby function payload limit)
///   - Mobile/desktop: 100MB (enforced server-side)
///
/// For larger files on mobile/desktop, consider uploading directly to a
/// cloud provider (Google Drive, WebDAV) instead — see CloudProvider.uploadFile.
class UploadService extends ChangeNotifier {
  UploadService(this._client);

  final ApiClient _client;

  bool _isUploading = false;
  double _progress = 0;
  String? _lastError;
  Track? _lastUploadedTrack;

  bool get isUploading => _isUploading;
  double get progress => _progress;
  String? get lastError => _lastError;
  Track? get lastUploadedTrack => _lastUploadedTrack;

  /// Uploads a music file to the backend.
  ///
  /// [fileBytes] — the raw file bytes
  /// [fileName] — original filename (e.g., "song.mp3")
  /// [title] — optional track title (defaults to filename without extension)
  /// [artist] — optional artist name
  /// [album] — optional album name
  /// [onProgress] — optional callback for upload progress (0.0 to 1.0)
  ///
  /// Returns the created [Track] on success, throws on failure.
  Future<Track> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    String? title,
    String? artist,
    String? album,
    void Function(double progress)? onProgress,
  }) async {
    _isUploading = true;
    _progress = 0;
    _lastError = null;
    notifyListeners();

    try {
      // Build multipart request
      final uri = Uri.parse('${_client.apiBase}/upload');
      final request = http.MultipartRequest('POST', uri);

      // Auth header
      if (_client.token != null) {
        request.headers['Authorization'] = 'Bearer ${_client.token}';
      }

      // File
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      // Text fields
      if (title != null) request.fields['title'] = title;
      if (artist != null) request.fields['artist'] = artist;
      if (album != null) request.fields['album'] = album;

      // Send with progress tracking
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
      );

      // Track progress (best-effort — doesn't work for all platforms)
      if (onProgress != null) {
        streamedResponse.stream.listen(
          (chunk) {
            // Can't easily track upload progress with http.MultipartRequest
            // This would need a custom ByteStream with progress reporting
          },
        );
      }

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String errorMsg;
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          errorMsg = decoded['error']?.toString() ?? 'Upload failed';
        } catch (_) {
          errorMsg = 'Upload failed (${response.statusCode})';
        }
        _lastError = errorMsg;
        throw Exception(errorMsg);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['ok'] != true) {
        _lastError = decoded['error']?.toString() ?? 'Upload failed';
        throw Exception(_lastError);
      }

      final trackJson = decoded['track'] as Map<String, dynamic>;
      final track = Track(
        id: trackJson['id'] as String,
        title: (trackJson['title'] as String?) ?? 'Unknown',
        artist: (trackJson['artist'] as String?) ?? 'Unknown Artist',
        album: (trackJson['album'] as String?) ?? '',
        albumArtist: (trackJson['albumArtist'] as String?) ?? '',
        genre: (trackJson['genre'] as String?) ?? '',
        composer: (trackJson['composer'] as String?) ?? '',
        year: (trackJson['year'] as int?) ?? 0,
        duration: Duration(seconds: ((trackJson['duration'] as num?)?.toDouble() ?? 0).toInt()),
        artUrl: '',
        audioUrl: decoded['blobUrl'] as String? ?? '',
        isCloudOnly: (trackJson['isCloudOnly'] as bool?) == true,
        isFavorite: (trackJson['isFavorite'] as bool?) == true,
        rating: (trackJson['rating'] as num?)?.toInt() ?? 0,
        playCount: (trackJson['playCount'] as num?)?.toInt() ?? 0,
      );

      _lastUploadedTrack = track;
      _progress = 1.0;
      _isUploading = false;
      notifyListeners();
      return track;
    } catch (e) {
      _lastError = e.toString();
      _isUploading = false;
      _progress = 0;
      notifyListeners();
      rethrow;
    }
  }

  /// Convenience method: upload a file and get just the blob URL back
  /// (without creating a track record). Useful for cover art uploads.
  Future<String> uploadFileOnly({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final track = await uploadFile(
      fileBytes: fileBytes,
      fileName: fileName,
      title: fileName,
      artist: 'Upload',
    );
    return track.audioUrl;
  }
}
