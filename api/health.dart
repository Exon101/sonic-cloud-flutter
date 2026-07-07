import 'dart:io';
import 'dart:convert';

Future<void> handler(HttpRequest request) async {
  final response = {
    'status': 'ok',
    'service': 'sonic-cloud',
    'version': '4.5.0',
    'timestamp': DateTime.now().toIso8601String(),
  };
  
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(response));
  await request.response.close();
}
