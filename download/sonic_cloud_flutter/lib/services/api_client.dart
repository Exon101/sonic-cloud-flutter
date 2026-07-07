import 'dart:convert';
import 'package:http/http.dart' as http;

/// Error thrown by [ApiClient] when the server returns a non-2xx response or
/// the request itself fails.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => 'ApiException($statusCode${code != null ? '/$code' : ''}): $message';
}

/// Minimal HTTP client for the Sonic Cloud Vercel serverless API.
///
/// Wraps `package:http` with:
/// - Configurable base URL (default: the live dev deployment).
/// - Bearer-token auth header injection.
/// - JSON encoding/decoding with the `{ok: true|false, ...}` envelope.
/// - Typed [ApiException] on failure.
///
/// The base URL is mutable so the Settings screen can change it at runtime.
class ApiClient {
  ApiClient({
    String baseUrl = 'https://sonic-cloud-kappa.vercel.app',
    http.Client? httpClient,
  })  : _baseUrl = baseUrl,
        _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String _baseUrl;
  String? _token;

  /// Notifier for auth state changes (sign-in / sign-out / token refresh).
  final List<void Function()> _authListeners = [];

  String get baseUrl => _baseUrl;
  String get apiBase => '$baseUrl/api';
  String? get token => _token;

  void setBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    // Strip trailing slash so callers can concatenate paths cleanly.
    _baseUrl = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  void setToken(String? token) {
    _token = token;
    for (final fn in _authListeners) {
      fn();
    }
  }

  void addAuthListener(void Function() fn) => _authListeners.add(fn);
  void removeAuthListener(void Function() fn) => _authListeners.remove(fn);

  /// Performs a JSON request and returns the decoded body.
  ///
  /// Throws [ApiException] on network error, non-2xx status, or `ok: false`.
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$apiBase/${path.replaceFirst(RegExp(r'^/+'), '')}')
        .replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };

    http.Response response;
    try {
      final bodyStr = body != null ? jsonEncode(body) : null;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
        case 'POST':
          response = await _httpClient.post(uri, headers: headers, body: bodyStr);
        case 'PUT':
          response = await _httpClient.put(uri, headers: headers, body: bodyStr);
        case 'PATCH':
          response = await _httpClient.patch(uri, headers: headers, body: bodyStr);
        case 'DELETE':
          response = await _httpClient.delete(uri, headers: headers);
        default:
          throw ApiException('Unsupported method: $method', code: 'bad_method');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e', code: 'network');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Invalid JSON response (${response.statusCode})',
        statusCode: response.statusCode,
        code: 'invalid_response',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['error']?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
        code: decoded['code']?.toString(),
      );
    }

    if (decoded['ok'] != true) {
      throw ApiException(
        decoded['error']?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
        code: decoded['code']?.toString(),
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      request('GET', path, query: query);
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, Map<String, String>? query}) =>
      request('POST', path, body: body, query: query);
  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body, Map<String, String>? query}) =>
      request('PUT', path, body: body, query: query);
  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body, Map<String, String>? query}) =>
      request('PATCH', path, body: body, query: query);
  Future<Map<String, dynamic>> delete(String path, {Map<String, String>? query}) =>
      request('DELETE', path, query: query);

  void dispose() {
    _httpClient.close();
    _authListeners.clear();
  }
}
