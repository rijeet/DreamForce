import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class DreamForceAuthApi {
  const DreamForceAuthApi();

  static const termsAcceptedVersion = 'terms-v1-2026-11-14';
  static const screenTimeConsentVersion = 'screen-time-sync-v1';

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dream-force-backend.vercel.app',
  );
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'dream_force_access_token';
  static const _refreshKey = 'dream_force_refresh_token';
  static const _timeout = Duration(seconds: 25);
  static const _refreshWindowCapSeconds = 60;
  static Future<void>? _refreshInFlight;

  Future<void> exchangeGoogleIdToken(
    String idToken, {
    String? timezone,
    required String termsVersion,
    String? screenTimeConsentVersion,
  }) async {
    if (kDebugMode) await checkReadiness();
    final requestBody = <String, String>{
      'idToken': idToken,
      'termsAcceptedVersion': termsVersion,
    };
    if (timezone != null) requestBody['timezone'] = timezone;
    if (screenTimeConsentVersion != null) {
      requestBody['screenTimeConsentVersion'] = screenTimeConsentVersion;
    }
    final response = await _send(
      () => http.post(
        Uri.parse('$_baseUrl/v1/auth/google'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(requestBody),
      ),
    );
    if (response.statusCode != 201) {
      throw AuthApiException(_message(response.body, response.statusCode));
    }
    final decoded = _decodeObject(response.body);
    final tokens = decoded;
    if (tokens['accessToken'] is! String || tokens['refreshToken'] is! String) {
      throw const AuthApiException(
        'The server response was incomplete. Please retry, and contact support if it continues. (INVALID_TOKEN_RESPONSE)',
      );
    }
    await _storage.write(
      key: _accessKey,
      value: tokens['accessToken'] as String,
    );
    await _storage.write(
      key: _refreshKey,
      value: tokens['refreshToken'] as String,
    );
  }

  Future<void> checkReadiness() async {
    final response = await _send(
      () => http.get(Uri.parse('$_baseUrl/v1/ready')),
    );
    if (response.statusCode == 200) return;
    if (response.statusCode == 503) {
      final body = _decodeObject(response.body);
      final database = body['database'] == 'ok' ? 'connected' : 'not connected';
      if (database == 'connected') return;
      throw AuthApiException(
        'Dream Force database is not connected in this development environment. Check the API terminal and apps/api/.env.local.',
      );
    }
    throw AuthApiException(
      'Backend readiness check failed (HTTP ${response.statusCode}).',
    );
  }

  Future<bool> hasSession() async =>
      await _storage.read(key: _accessKey) != null ||
      await _storage.read(key: _refreshKey) != null;

  Future<http.Response> request(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
  }) async {
    var token = await _storage.read(key: _accessKey);
    if (token == null || _accessTokenNeedsRefresh(token)) {
      if (token == null && await _storage.read(key: _refreshKey) == null) {
        throw const AuthApiException('Sign in again to sync your data.');
      }
      await _refreshIfNeeded(token);
      token = await _storage.read(key: _accessKey);
      if (token == null) {
        throw const AuthApiException(
          'Could not finish session renewal. Sign in again. (ACCESS_TOKEN_MISSING)',
        );
      }
    }
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _sendAuthenticated(
      method,
      uri,
      token,
      body: body,
      idempotencyKey: idempotencyKey,
    );
    if (response.statusCode == 401) {
      await _refreshIfNeeded(token);
      final refreshedToken = await _storage.read(key: _accessKey);
      if (refreshedToken == null) {
        throw const AuthApiException(
          'Could not finish session renewal. Sign in again. (ACCESS_TOKEN_MISSING)',
        );
      }
      final retriedResponse = await _sendAuthenticated(
        method,
        uri,
        refreshedToken,
        body: body,
        idempotencyKey: idempotencyKey,
      );
      if (retriedResponse.statusCode == 401) {
        throw const AuthApiException(
          'The server rejected the refreshed access token. Check the API configuration or try signing in again. (ACCESS_TOKEN_REJECTED)',
        );
      }
      if (retriedResponse.statusCode < 200 ||
          retriedResponse.statusCode >= 300) {
        throw AuthApiException(
          _message(retriedResponse.body, retriedResponse.statusCode),
        );
      }
      return retriedResponse;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(_message(response.body, response.statusCode));
    }
    return response;
  }

  Future<http.Response> _sendAuthenticated(
    String method,
    Uri uri,
    String token, {
    Object? body,
    String? idempotencyKey,
  }) {
    final headers = <String, String>{
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
    if (idempotencyKey != null) headers['idempotency-key'] = idempotencyKey;
    return _send(
      () => switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => http.patch(uri, headers: headers, body: jsonEncode(body)),
        'PUT' => http.put(uri, headers: headers, body: jsonEncode(body)),
        'DELETE' => http.delete(uri, headers: headers),
        _ => throw ArgumentError.value(method, 'method'),
      },
    );
  }

  Future<void> _refreshIfNeeded(String? rejectedAccessToken) {
    final existingRefresh = _refreshInFlight;
    if (existingRefresh != null) return existingRefresh;

    // Claim the lock before any await so overlapping requests share one rotation.
    final refresh = _performRefresh(rejectedAccessToken);
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  bool _accessTokenNeedsRefresh(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return false;
      final expiration = payload['exp'];
      if (expiration is! num) return false;
      final issuedAt = payload['iat'];
      final tokenLifetime = issuedAt is num
          ? (expiration - issuedAt).toInt()
          : _refreshWindowCapSeconds;
      final refreshWindow = min(
        _refreshWindowCapSeconds,
        max(5, tokenLifetime ~/ 3),
      );
      return expiration <=
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + refreshWindow;
    } catch (_) {
      // Expiry parsing is an optimization only. The API remains authoritative.
      return false;
    }
  }

  Future<void> _performRefresh(String? rejectedAccessToken) async {
    final latestAccessToken = await _storage.read(key: _accessKey);
    if (rejectedAccessToken != null &&
        latestAccessToken != null &&
        latestAccessToken != rejectedAccessToken &&
        !_accessTokenNeedsRefresh(latestAccessToken)) {
      return;
    }

    final refreshToken = await _storage.read(key: _refreshKey);
    if (refreshToken == null) {
      await clearSession();
      throw const AuthApiException(
        'No saved refresh token is available. Sign in again. (REFRESH_TOKEN_MISSING)',
      );
    }
    final response = await _send(
      () => http.post(
        Uri.parse('$_baseUrl/v1/auth/refresh'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseCode = _responseCode(response.body);
      if (responseCode == 'REFRESH_TOKEN_INVALID' ||
          responseCode == 'REFRESH_TOKEN_REPLAYED') {
        final latestRefreshToken = await _storage.read(key: _refreshKey);
        if (latestRefreshToken != null && latestRefreshToken != refreshToken) {
          return;
        }
        await clearSession();
        throw const AuthApiException('Session expired. Sign in again.');
      }
      final code = response.statusCode == 429
          ? 'REFRESH_RATE_LIMITED'
          : 'REFRESH_UNAVAILABLE';
      throw AuthApiException(
        response.statusCode == 429
            ? 'Too many session refresh attempts. Wait a moment and retry. ($code)'
            : 'Could not renew the session because the server is unavailable. Check your connection and retry. ($code)',
      );
    }
    final tokens = _decodeObject(response.body);
    if (tokens['accessToken'] is! String ||
        tokens['refreshToken'] is! String ||
        tokens['expiresIn'] is! num) {
      throw const AuthApiException(
        'The refresh response was incomplete. Retry or contact support. (INVALID_REFRESH_RESPONSE)',
      );
    }
    // Persist the rotated refresh token first. If writing the access token
    // fails, the new refresh token can still recover the session next time.
    await _storage.write(
      key: _refreshKey,
      value: tokens['refreshToken'] as String,
    );
    await _storage.write(
      key: _accessKey,
      value: tokens['accessToken'] as String,
    );
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: _refreshKey);
    try {
      if (refreshToken != null) {
        await _send(
          () => http.post(
            Uri.parse('$_baseUrl/v1/auth/logout'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          ),
        );
      }
    } finally {
      await clearSession();
    }
  }

  static String newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const AuthApiException(
        'The server took too long to respond. Check your connection and retry. (NETWORK_TIMEOUT)',
      );
    } on http.ClientException {
      throw const AuthApiException(
        'Could not reach the Dream Force server. Check your internet connection and API_BASE_URL. (NETWORK_UNAVAILABLE)',
      );
    }
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    throw const AuthApiException(
      'The server returned an unreadable response. Retry or contact support. (INVALID_SERVER_RESPONSE)',
    );
  }

  String? _responseCode(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map<String, dynamic> && value['code'] is String) {
        return value['code'] as String;
      }
    } catch (_) {}
    return null;
  }

  String _message(String body, int status) {
    final decoded = _decodeObject(body);
    final code = decoded['code'] as String? ?? 'HTTP_$status';
    final issues = decoded['issues'];
    final fieldDetails = issues is List
        ? issues
              .whereType<Map>()
              .map((item) => '${item['field']}: ${item['message']}')
              .join('; ')
        : '';
    final suffix = fieldDetails.isEmpty ? '' : ' Details: $fieldDetails';
    return switch (code) {
      'INVALID_REQUEST' =>
        'The sign-in request was rejected.$suffix (INVALID_REQUEST)',
      'GOOGLE_AUDIENCE_MISMATCH' => 'Google OAuth client IDs do not match. Use the same Web client ID in the app and Vercel. (GOOGLE_AUDIENCE_MISMATCH)',
      'GOOGLE_ISSUER_MISMATCH' => 'Google returned an unexpected token issuer. Check the backend GOOGLE_ISSUER setting. (GOOGLE_ISSUER_MISMATCH)',
      'GOOGLE_TOKEN_EXPIRED' =>
        'Google sign-in expired. Try signing in again. (GOOGLE_TOKEN_EXPIRED)',
      'GOOGLE_TOKEN_INVALID' => 'Google could not verify this sign-in token. Check the OAuth client ID and Android package/SHA-1 registration. (GOOGLE_TOKEN_INVALID)',
      'GOOGLE_IDENTITY_INVALID' => 'Google did not return a verified email for this account. Choose a verified Google account. (GOOGLE_IDENTITY_INVALID)',
      'GOOGLE_CODE_REJECTED' => 'Google rejected the authorization code. Check the OAuth client configuration. (GOOGLE_CODE_REJECTED)',
      'INVALID_API_RESPONSE' =>
        'The backend returned an invalid response. Check the Vercel deployment logs. (INVALID_API_RESPONSE)$suffix',
      'INTERNAL_ERROR' => 'The backend failed while processing sign-in. Check Vercel logs and confirm required environment variables are set. (INTERNAL_ERROR)',
      'SCREEN_TIME_SYNC_CONSENT_REQUIRED' => 'Enable screen-time sync consent in Insights before uploading this data. (SCREEN_TIME_SYNC_CONSENT_REQUIRED)',
      'HTTP_429' =>
        'Too many sign-in attempts. Wait a moment and retry. (HTTP_429)',
      _ => 'Sign-in failed with HTTP $status ($code).$suffix',
    };
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
