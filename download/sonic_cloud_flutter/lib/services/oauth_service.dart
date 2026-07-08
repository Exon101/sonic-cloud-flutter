import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// OAuthService — manages OAuth2 flows for cloud providers.
///
/// Supported providers:
///   - Google Drive: uses `google_sign_in` package (native SDK on mobile)
///   - Dropbox: uses `flutter_web_auth_2` for OAuth2 authorization code flow
///   - OneDrive: uses `flutter_web_auth_2` for Microsoft identity platform
///   - Nextcloud: uses username/password (basic auth, no OAuth needed)
///   - WebDAV: uses username/password (basic auth)
///
/// Tokens are stored securely via [SecurityService.storeCloudCredentials].
class OAuthService extends ChangeNotifier {
  final googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.readonly'],
    // Replace with your own client ID from Google Cloud Console:
    // clientId: 'your-client-id.apps.googleusercontent.com',
  );

  /// Sign in to Google and return the access token.
  /// Throws on failure or if the user cancels.
  Future<String> signInGoogleDrive() async {
    try {
      final account = await googleSignIn.signIn();
      if (account == null) throw Exception('User cancelled Google sign-in');
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null) throw Exception('Failed to get Google access token');
      return token;
    } catch (e) {
      debugPrint('OAuthService.signInGoogleDrive failed: $e');
      rethrow;
    }
  }

  /// Sign out of Google.
  Future<void> signOutGoogleDrive() async {
    await googleSignIn.signOut();
  }

  /// Sign in to Dropbox via OAuth2 authorization code flow.
  /// Returns the access token.
  ///
  /// Prerequisites:
  ///   1. Register an app at https://www.dropbox.com/developers/apps
  ///   2. Set the redirect URI to: <your-app-scheme>://oauth2redirect
  ///   3. Replace [_dropboxClientId] with your app key
  Future<String> signInDropbox() async {
    final clientId = _dropboxClientId;
    final redirectUri = _redirectUri('dropbox');
    final authUrl =
        'https://www.dropbox.com/oauth2/authorize?response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=$redirectUri'
        '&token_access_type=online';

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: _callbackScheme,
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) throw Exception('No authorization code in callback');

      // Exchange code for token
      final tokenResp = await http.post(
        Uri.parse('https://api.dropboxapi.com/oauth2/token'),
        body: {
          'code': code,
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'redirect_uri': redirectUri,
        },
      );
      if (tokenResp.statusCode != 200) {
        throw Exception('Token exchange failed: ${tokenResp.body}');
      }
      final data = tokenResp.body;
      // Parse JSON manually to avoid extra deps
      final tokenMatch = RegExp(
        r'"access_token"\s*:\s*"([^"]+)"',
      ).firstMatch(data);
      if (tokenMatch == null) throw Exception('No access_token in response');
      return tokenMatch.group(1)!;
    } catch (e) {
      debugPrint('OAuthService.signInDropbox failed: $e');
      rethrow;
    }
  }

  /// Sign in to OneDrive/Microsoft via OAuth2.
  /// Returns the access token.
  ///
  /// Prerequisites:
  ///   1. Register an app at https://entra.microsoft.com
  ///   2. Add redirect URI: <your-app-scheme>://oauth2redirect
  ///   3. Replace [_msClientId] and [_msTenantId] with your values
  Future<String> signInOneDrive() async {
    final clientId = _msClientId;
    final tenantId = _msTenantId;
    final redirectUri = _redirectUri('onedrive');
    final authUrl =
        'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize'
        '?response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&scope=${Uri.encodeComponent('https://graph.microsoft.com/Files.Read offline_access')}';

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: _callbackScheme,
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) throw Exception('No authorization code in callback');

      final tokenResp = await http.post(
        Uri.parse(
          'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token',
        ),
        body: {
          'code': code,
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'scope': 'https://graph.microsoft.com/Files.Read offline_access',
        },
      );
      if (tokenResp.statusCode != 200) {
        throw Exception('Token exchange failed: ${tokenResp.body}');
      }
      final data = tokenResp.body;
      final tokenMatch = RegExp(
        r'"access_token"\s*:\s*"([^"]+)"',
      ).firstMatch(data);
      if (tokenMatch == null) throw Exception('No access_token in response');
      return tokenMatch.group(1)!;
    } catch (e) {
      debugPrint('OAuthService.signInOneDrive failed: $e');
      rethrow;
    }
  }

  /// Build a [CloudProviderConfig] from a successful OAuth sign-in.
  CloudProviderConfig configFromToken(
    CloudProviderKind kind,
    String token,
    String displayName,
  ) {
    return CloudProviderConfig(
      id: '${kind.name}_${DateTime.now().millisecondsSinceEpoch}',
      kind: kind,
      displayName: displayName,
      account: token,
      status: CloudProviderStatus.connected,
      streamMode: true,
    );
  }

  // ── Configuration constants ─────────────────────────────────────────────────
  //
  // Replace these with your own app credentials from each provider's developer
  // console. The redirect URI scheme must match your app's custom URL scheme
  // (configured in AndroidManifest.xml / Info.plist).
  //
  // For development/testing, these are placeholder values that won't work
  // until you register a real app. The UI will show an error message guiding
  // the user to set up credentials.

  static const _dropboxClientId = 'YOUR_DROPBOX_APP_KEY';
  static const _msClientId = 'YOUR_MICROSOFT_CLIENT_ID';
  static const _msTenantId = 'common'; // or your specific tenant ID
  static const _callbackScheme = 'soniccloud';

  static String _redirectUri(String provider) {
    return '$_callbackScheme://oauth2redirect/$provider';
  }

  /// Check if the OAuth credentials have been configured.
  bool get isGoogleDriveConfigured => true; // google_sign_in handles its own
  bool get isDropboxConfigured => _dropboxClientId != 'YOUR_DROPBOX_APP_KEY';
  bool get isOneDriveConfigured => _msClientId != 'YOUR_MICROSOFT_CLIENT_ID';
}
