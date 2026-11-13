import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class DreamForceAuthApi {
  const DreamForceAuthApi();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dream-force-backend.vercel.app',
  );
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'dream_force_access_token';
  static const _refreshKey = 'dream_force_refresh_token';
  static const _timeout = Duration(seconds: 25);

  Future<void> exchangeGoogleIdToken(String idToken) async {
    final response = await _send(
      () => http.post(
        Uri.parse('$_baseUrl/v1/auth/google'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
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

  Future<bool> hasSession() async =>
      await _storage.read(key: _accessKey) != null;

  Future<http.Response> request(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
  }) async {
    final token = await _storage.read(key: _accessKey);
    if (token == null) {
      throw const AuthApiException('Sign in again to sync your data.');
    }
    final headers = <String, String>{
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
    if (idempotencyKey != null) headers['idempotency-key'] = idempotencyKey;
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _send(
      () => switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => http.patch(uri, headers: headers, body: jsonEncode(body)),
        'PUT' => http.put(uri, headers: headers, body: jsonEncode(body)),
        _ => throw ArgumentError.value(method, 'method'),
      },
    );
    if (response.statusCode == 401) {
      await _refresh();
      return request(method, path, body: body, idempotencyKey: idempotencyKey);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(_message(response.body, response.statusCode));
    }
    return response;
  }

  Future<void> _refresh() async {
    final refreshToken = await _storage.read(key: _refreshKey);
    if (refreshToken == null) {
      throw const AuthApiException('Session expired. Sign in again.');
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/v1/auth/refresh'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      await clearSession();
      throw const AuthApiException('Session expired. Sign in again.');
    }
    final tokens = jsonDecode(response.body) as Map<String, dynamic>;
    await _storage.write(
      key: _accessKey,
      value: tokens['accessToken'] as String,
    );
    await _storage.write(
      key: _refreshKey,
      value: tokens['refreshToken'] as String,
    );
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
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
      'HTTP_429' =>
        'Too many sign-in attempts. Wait a moment and retry. (HTTP_429)',
      _ => 'Sign-in failed with HTTP $status ($code).$suffix',
    };
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);
  final String message;
}
