import 'dart:io';
import 'dart:convert';

// In-memory playback state (would be replaced with a database in production)
Map<String, dynamic> _playbackState = {
  'isPlaying': false,
  'currentTrack': null,
  'position': 0,
  'duration': 0,
  'queue': [],
};

Future<void> handler(HttpRequest request) async {
  // CORS headers
  request.response.headers
    ..add('Access-Control-Allow-Origin', '*')
    ..add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..add('Access-Control-Allow-Headers', 'Content-Type');
  
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
    return;
  }
  
  if (request.method == 'GET') {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(_playbackState));
    await request.response.close();
    return;
  }
  
  if (request.method == 'POST') {
    final body = await utf8.decoder.bind(request).join();
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      _playbackState = {..._playbackState, ...data};
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'updated', 'state': _playbackState}));
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': e.toString()}));
    }
    await request.response.close();
    return;
  }
  
  request.response.statusCode = HttpStatus.methodNotAllowed;
  await request.response.close();
}
