// Barrel file that conditionally exports the right LocalApiService impl.
//
// On mobile/desktop: exports local_api_service_io.dart (real shelf server)
// On web: exports local_api_service_stub.dart (no-op, throws on start)

export 'local_api_service_stub.dart'
    if (dart.library.io) 'local_api_service_io.dart';
