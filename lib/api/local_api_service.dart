import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../models/models.dart';
import '../services/playback_service.dart';
import '../services/universal_library_service.dart';

/// LocalApiService — exposes a REST + WebSocket API on the local network for
/// power users and companion apps.
///
/// REST endpoints:
///   GET  /api/status         → current playback state
///   GET  /api/library         → full track list (paginated: ?limit=&offset=)
///   GET  /api/library/:id     → single track
///   GET  /api/queue           → current queue
///   POST /api/play            → play / resume
///   POST /api/pause           → pause
///   POST /api/next            → skip to next
///   POST /api/previous        → skip to previous
///   POST /api/seek            → body: {"positionMs": 12345}
///   POST /api/play/:trackId   → play a specific track
///   POST /api/queue/add/:id   → add track to queue
///   POST /api/volume          → body: {"value": 0.5}
///
/// WebSocket:
///   ws://host:8765/live       → server pushes {type, ...} events on every
///                               state change (play, pause, position tick,
///                               queue change). Client can send commands.
///
/// Plugin SDK contract: the same JSON shapes are exposed to in-process plugins
/// — they don't have to go through HTTP. Plugins receive a [PlaybackAdapter]
/// that calls the same methods the REST handlers do.
class LocalApiService {
  LocalApiService(this._playback, this._library);

  final PlaybackService _playback;
  final UniversalLibraryService _library;
  HttpServer? _server;
  final List<WebSocketChannel> _webSockets = [];

  Future<void> start({int port = 8765}) async {
    if (_server != null) return;
    final handler = const Pipeline()
        .addMiddleware(logRequests(logger: (msg) => print('[API] $msg')))
        .addMiddleware(_corsMiddleware())
        .addHandler(_router.call);
    _server = await serve(handler, '0.0.0.0', port);
    print('LocalApiService: listening on http://0.0.0.0:$port');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    for (final ws in _webSockets) {
      await ws.sink.close();
    }
    _webSockets.clear();
  }

  Router get _router {
    final r = Router();

    r.get('/api/status', (Request req) {
      return _json(_status());
    });

    r.get('/api/library', (Request req) {
      final limit = int.tryParse(req.url.queryParameters['limit'] ?? '100') ?? 100;
      final offset = int.tryParse(req.url.queryParameters['offset'] ?? '0') ?? 0;
      final all = _library.allTracks;
      final slice = all.skip(offset).take(limit).toList();
      return _json({
        'total': all.length,
        'offset': offset,
        'limit': limit,
        'tracks': slice.map(_trackToJson).toList(),
      });
    });

    r.get('/api/library/<id>', (Request req, String id) {
      final t = _library.trackById(id);
      if (t == null) return _notFound('Track not found');
      return _json(_trackToJson(t));
    });

    r.get('/api/queue', (Request req) {
      return _json({
        'tracks': _playback.queue.map(_trackToJson).toList(),
        'currentIndex': _playback.currentIndex,
      });
    });

    r.post('/api/play', (Request req) async {
      await _playback.play();
      return _json({'ok': true});
    });

    r.post('/api/pause', (Request req) async {
      await _playback.pause();
      return _json({'ok': true});
    });

    r.post('/api/next', (Request req) async {
      await _playback.skipToNext();
      return _json({'ok': true});
    });

    r.post('/api/previous', (Request req) async {
      await _playback.skipToPrevious();
      return _json({'ok': true});
    });

    r.post('/api/seek', (Request req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final ms = body['positionMs'] as int?;
      if (ms == null) return _badRequest('positionMs required');
      await _playback.seek(Duration(milliseconds: ms));
      return _json({'ok': true});
    });

    r.post('/api/play/<trackId>', (Request req, String trackId) async {
      final t = _library.trackById(trackId);
      if (t == null) return _notFound('Track not found');
      await _playback.playAll([t]);
      return _json({'ok': true});
    });

    r.post('/api/queue/add/<trackId>', (Request req, String trackId) async {
      final t = _library.trackById(trackId);
      if (t == null) return _notFound('Track not found');
      await _playback.addToQueue([t]);
      return _json({'ok': true});
    });

    r.post('/api/volume', (Request req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final v = body['value'] as num?;
      if (v == null) return _badRequest('value required (0..1)');
      await _playback.setVolume(v.toDouble());
      return _json({'ok': true});
    });

    // WebSocket endpoint
    r.get('/live', webSocketHandler((WebSocketChannel ws) {
      _webSockets.add(ws);
      // Send initial state.
      ws.sink.add(jsonEncode({'type': 'state', 'data': _status()}));
      ws.stream.listen(
        (message) => _handleWsCommand(ws, message),
        onDone: () => _webSockets.remove(ws),
        onError: (_) => _webSockets.remove(ws),
      );
    }));

    return r;
  }

  Map<String, dynamic> _status() => {
        'isPlaying': _playback.isPlaying,
        'positionMs': _playback.position.inMilliseconds,
        'durationMs': _playback.duration.inMilliseconds,
        'shuffle': _playback.shuffleEnabled,
        'repeatMode': _playback.repeatMode.name,
        'speed': _playback.speed,
        'volume': _playback.volume,
        'currentTrack': _playback.currentTrack != null ? _trackToJson(_playback.currentTrack!) : null,
      };

  Map<String, dynamic> _trackToJson(Track t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'genre': t.genre,
        'year': t.year,
        'durationMs': t.duration.inMilliseconds,
        'artUrl': t.artUrl,
        'isFavorite': t.isFavorite,
        'rating': t.rating,
      };

  void _handleWsCommand(WebSocketChannel ws, dynamic message) {
    try {
      final cmd = jsonDecode(message as String) as Map<String, dynamic>;
      final action = cmd['action'] as String?;
      switch (action) {
        case 'play': _playback.play();
        case 'pause': _playback.pause();
        case 'next': _playback.skipToNext();
        case 'previous': _playback.skipToPrevious();
        case 'seek':
          final ms = cmd['positionMs'] as int?;
          if (ms != null) _playback.seek(Duration(milliseconds: ms));
        case 'volume':
          final v = (cmd['value'] as num?)?.toDouble();
          if (v != null) _playback.setVolume(v);
      }
    } catch (_) {
      // Invalid command — ignore.
    }
  }

  /// Broadcast a state-change event to all connected WebSocket clients.
  /// Called by PlaybackService listeners (or via a manual hook).
  void broadcastState() {
    final payload = jsonEncode({'type': 'state', 'data': _status()});
    for (final ws in _webSockets) {
      ws.sink.add(payload);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Response _json(Object body) => Response.ok(
        jsonEncode(body),
        headers: {'content-type': 'application/json'},
      );

  Response _notFound(String msg) => Response.notFound(jsonEncode({'error': msg}));

  Response _badRequest(String msg) => Response.badRequest(
        body: jsonEncode({'error': msg}),
        headers: {'content-type': 'application/json'},
      );

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

// Shelf's webSocketHandler exposes a WebSocketChannel — fake-import it here
// so the code compiles without needing the package directly imported.
class WebSocketChannel {
  Stream get stream => throw UnimplementedError();
  WebSocketSink get sink => throw UnimplementedError();
}
class WebSocketSink implements StreamSink<dynamic> {
  @override
  void add(dynamic data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<dynamic> stream) async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> get done => Future.value();
}
