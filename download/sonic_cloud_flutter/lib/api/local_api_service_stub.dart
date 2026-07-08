// Web stub for LocalApiService.
//
// On web, the local API server can't run (browsers can't bind ports).
// This stub provides a no-op class with the same constructor signature
// so code that references LocalApiService compiles.

import '../models/models.dart';
import '../services/playback_service.dart';
import '../services/universal_library_service.dart';

class LocalApiService {
  LocalApiService(PlaybackService playback, UniversalLibraryService library);

  Future<void> start({int port = 8765}) async {
    throw UnsupportedError('LocalApiService.start not supported on web');
  }

  Future<void> stop() async {}
  void broadcastState() {}
}
