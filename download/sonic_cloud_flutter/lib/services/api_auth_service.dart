import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Manages the user's authenticated session against the Sonic Cloud API.
///
/// Wraps [ApiClient] with:
/// - Token persistence in [SharedPreferences] (survives app restart).
/// - A [currentUser] stream that emits on sign-in / sign-out.
/// - Idempotent [restoreSession] that's safe to call from `main.dart`'s
///   `initState`.
///
/// The "Log In Anonymously" path is the default — it gives the user a working
/// account (and a token) without requiring an email address. The "Sign in
/// with Email" path is idempotent: the same email returns the same userId
/// across calls, so it can be used as a lightweight "sync across devices"
/// mechanism without a password flow.
class ApiAuthService extends ChangeNotifier {
  ApiAuthService(this._client, this._prefs);

  final ApiClient _client;
  final SharedPreferences _prefs;

  static const _kToken = 'api_token';
  static const _kUserId = 'api_user_id';
  static const _kUserEmail = 'api_user_email';
  static const _kUserIsAnon = 'api_user_anon';
  static const _kDeviceId = 'api_device_id';
  static const _kBaseUrl = 'api_base_url';

  UserAccount? _user;
  String? _deviceId;

  UserAccount? get currentUser => _user;
  bool get isAuthenticated => _user != null;
  String? get deviceId => _deviceId;

  /// Restores a saved session, if any. Safe to call multiple times.
  Future<bool> restoreSession() async {
    // Restore base URL first so subsequent requests hit the right host.
    final baseUrl = _prefs.getString(_kBaseUrl);
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _client.setBaseUrl(baseUrl);
    }

    final token = _prefs.getString(_kToken);
    if (token == null) return false;

    _deviceId = _prefs.getString(_kDeviceId);

    _client.setToken(token);
    // Validate the token by calling /auth/me.
    try {
      final res = await _client.get('auth/me');
      final userJson = res['user'] as Map<String, dynamic>;
      _user = UserAccount(
        id: userJson['id'] as String,
        email: (userJson['email'] as String?) ?? '',
        isAnonymous: _prefs.getBool(_kUserIsAnon) ?? false,
        name: _prefs.getString(_kUserEmail) ?? '',
        tier: _userTier(_prefs.getBool(_kUserIsAnon) ?? false),
      );
      notifyListeners();
      return true;
    } catch (_) {
      // Token is invalid or expired — clear and treat as signed out.
      await _clearStoredSession();
      _client.setToken(null);
      return false;
    }
  }

  Future<UserAccount> signInAnonymously() async {
    final deviceId = _ensureDeviceId();
    final res = await _client.post('auth/signin', body: {
      'anonymous': true,
      'deviceId': deviceId,
    });
    return _persistSession(res, isAnonymous: true);
  }

  Future<UserAccount> signInWithEmail(String email) async {
    final deviceId = _ensureDeviceId();
    final res = await _client.post('auth/signin', body: {
      'email': email,
      'deviceId': deviceId,
    });
    return _persistSession(res, isAnonymous: false, email: email);
  }

  Future<void> signOut() async {
    // Best-effort: revoke our own session server-side, then clear locally.
    try {
      await _client.delete('devices', query: {'prefix': (_client.token ?? '').substring(0, 8)});
    } catch (_) {
      // Server may already be unreachable — proceed with local sign-out.
    }
    await _clearStoredSession();
    _client.setToken(null);
    _user = null;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    _client.setBaseUrl(url);
    await _prefs.setString(_kBaseUrl, url);
  }

  String _ensureDeviceId() {
    final existing = _prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'dev_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    _prefs.setString(_kDeviceId, id);
    _deviceId = id;
    return id;
  }

  Future<UserAccount> _persistSession(
    Map<String, dynamic> res, {
    required bool isAnonymous,
    String? email,
  }) async {
    final token = res['token'] as String;
    final userId = res['userId'] as String;
    final userJson = res['user'] as Map<String, dynamic>?;
    final emailFromServer = userJson?['email'] as String?;

    _client.setToken(token);
    await _prefs.setString(_kToken, token);
    await _prefs.setString(_kUserId, userId);
    await _prefs.setBool(_kUserIsAnon, isAnonymous);
    if (email != null || emailFromServer != null) {
      await _prefs.setString(_kUserEmail, email ?? emailFromServer ?? '');
    }

    _user = UserAccount(
      id: userId,
      email: email ?? emailFromServer ?? '',
      isAnonymous: isAnonymous,
      name: email ?? emailFromServer ?? 'Anonymous User',
      tier: _userTier(isAnonymous),
    );
    notifyListeners();
    return _user!;
  }

  Future<void> _clearStoredSession() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kUserEmail);
    await _prefs.remove(_kUserIsAnon);
  }

  String _userTier(bool isAnonymous) => isAnonymous ? 'Guest' : 'Premium Member';
}
