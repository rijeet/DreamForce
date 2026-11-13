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

  Future<void> exchangeGoogleIdToken(String idToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/v1/auth/google'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (response.statusCode != 201) {
      throw AuthApiException(_message(response.body));
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
    final response = await switch (method) {
      'GET' => http.get(uri, headers: headers),
      'POST' => http.post(uri, headers: headers, body: jsonEncode(body)),
      'PATCH' => http.patch(uri, headers: headers, body: jsonEncode(body)),
      'PUT' => http.put(uri, headers: headers, body: jsonEncode(body)),
      _ => throw ArgumentError.value(method, 'method'),
    };
    if (response.statusCode == 401) {
      await _refresh();
      return request(method, path, body: body, idempotencyKey: idempotencyKey);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(_message(response.body));
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

  String _message(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['code'] as String? ?? 'The API request failed.';
    } catch (_) {
      return 'The API request failed.';
    }
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);
  final String message;
}
