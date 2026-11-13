import 'dart:convert';

import 'package:http/http.dart' as http;

class DreamForceAuthApi {
  const DreamForceAuthApi();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dream-force-backend.vercel.app',
  );

  Future<void> exchangeGoogleIdToken(String idToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/v1/auth/google'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (response.statusCode != 201) {
      throw AuthApiException(_message(response.body));
    }
  }

  String _message(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['code'] as String? ??
          'Google account could not be verified.';
    } catch (_) {
      return 'Google account could not be verified.';
    }
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);
  final String message;
}
