import 'dart:io';
import 'dart:convert';

// In-memory library (would be replaced with a database in production)
List<Map<String, dynamic>> _tracks = [];

Future<void> handler(HttpRequest request) async {
  request.response.headers
    ..add('Access-Control-Allow-Origin', '*')
    ..add('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')
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
      ..write(jsonEncode({'tracks': _tracks, 'count': _tracks.length}));
    await request.response.close();
    return;
  }
  
  if (request.method == 'POST') {
    final body = await utf8.decoder.bind(request).join();
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      _tracks.add(data);
      request.response
        ..statusCode = HttpStatus.created
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'added', 'track': data}));
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': e.toString()}));
    }
    await request.response.close();
    return;
  }
  
  if (request.method == 'DELETE') {
    final trackId = request.uri.queryParameters['id'];
    if (trackId != null) {
      _tracks.removeWhere((t) => t['id'] == trackId);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'deleted', 'id': trackId}));
    } else {
      _tracks.clear();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'cleared'}));
    }
    await request.response.close();
    return;
  }
  
  request.response.statusCode = HttpStatus.methodNotAllowed;
  await request.response.close();
}
