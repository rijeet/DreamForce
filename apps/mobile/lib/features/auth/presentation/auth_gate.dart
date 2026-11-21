import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dream_force/features/profile/domain/profile_options.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_ui/material_ui.dart';

import '../data/dream_force_auth_api.dart';

class SignedInUser {
  const SignedInUser(this.email, this.name, this.photoUrl);
  final String email;
  final String? name;
  final String? photoUrl;
}

class AuthGate extends StatefulWidget {
  const AuthGate({required this.child, super.key});
  final Widget Function(SignedInUser user, Future<void> Function() onLogout)
  child;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  SignedInUser? _user;
  String? _error;
  var _loading = true;
  var _signingIn = false;
  var _termsAccepted = false;
  var _screenTimeSyncConsent = false;
  var _googleReady = false;
  var _canRetryRestore = false;
  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      _canRetryRestore = false;
      final api = const DreamForceAuthApi();
      if (await api.hasSession()) {
        if (kDebugMode) await api.checkReadiness();
        final profile = jsonDecode(
          (await api.request('GET', '/v1/me')).body,
        ) as Map<String, dynamic>;
        final email = profile['email'];
        if (email is! String || email.isEmpty) {
          await api.clearSession();
          throw const AuthApiException(
            'The saved account could not be restored. Sign in again.',
          );
        }
        if (profile['termsAcceptedVersion'] !=
            DreamForceAuthApi.termsAcceptedVersion) {
          await api.clearSession();
          _error = 'Please review and accept the current Terms and Privacy notice to continue.';
        } else {
          _user = SignedInUser(
            email,
            profile['displayName'] as String?,
            profile['avatarUrl'] as String?,
          );
          if (profile['country'] != profileCountry ||
              profile['timezone'] != profileTimezone) {
            try {
              await api.request(
                'PATCH',
                '/v1/me',
                body: {
                  'profile': {
                    'country': profileCountry,
                    'timezone': profileTimezone,
                  },
                },
              );
            } catch (_) {
              // A restored session stays usable if only the fixed profile fields fail to sync.
            }
          }
        }
      }
    } catch (error) {
      _error = error is AuthApiException
          ? error.message
          : 'Could not restore sign-in. Check the network, then retry. (${_safeError(error)})';
      try {
        _canRetryRestore = await const DreamForceAuthApi().hasSession();
      } catch (_) {
        _canRetryRestore = false;
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _googleReady = true;
  }

  Future<void> _signIn() async {
    if (_serverClientId.isEmpty) {
      setState(
        () => _error =
            'Add GOOGLE_SERVER_CLIENT_ID with --dart-define before signing in.',
      );
      return;
    }
    setState(() => _signingIn = true);
    try {
      await _ensureGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthApiException(
          'Google sign-in returned no ID token. Set the app’s GOOGLE_SERVER_CLIENT_ID to the Web application OAuth client ID. (GOOGLE_ID_TOKEN_MISSING)',
        );
      }
      await const DreamForceAuthApi().exchangeGoogleIdToken(
        idToken,
        termsVersion: DreamForceAuthApi.termsAcceptedVersion,
        screenTimeConsentVersion: _screenTimeSyncConsent
            ? DreamForceAuthApi.screenTimeConsentVersion
            : null,
      );
      if (mounted) {
        setState(
          () => _user = SignedInUser(
            account.email,
            account.displayName,
            account.photoUrl,
          ),
        );
      }
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Google sign-in could not finish. Check the Android package name and SHA-1 registration, Web client ID, and network. (${_safeError(error)})',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _signingIn = false);
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    try {
      await const DreamForceAuthApi().logout();
    } catch (error) {
      _error =
          'Local session cleared; server logout could not be confirmed. (${_safeError(error)})';
      await const DreamForceAuthApi().clearSession();
    }
    try {
      if (_serverClientId.isNotEmpty) {
        await _ensureGoogle();
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {
      // Dream Force credentials are already cleared; Google sign-out is best effort.
    }
    if (mounted) {
      setState(() {
        _user = null;
        _loading = false;
      });
    }
  }

  String _safeError(Object error) {
    final message = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return message.length > 180 ? '${message.substring(0, 180)}…' : message;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SplashScreen();
    if (_user != null) return widget.child(_user!, _logout);
    if (_canRetryRestore) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _error ?? 'Could not restore sign-in.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _loading = true);
                    unawaited(_restore());
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AccountScreen(
      error: _error,
      loading: _signingIn,
      termsAccepted: _termsAccepted,
      screenTimeSyncConsent: _screenTimeSyncConsent,
      onTermsAcceptedChanged: (value) => setState(() => _termsAccepted = value),
      onScreenTimeSyncConsentChanged: (value) =>
          setState(() => _screenTimeSyncConsent = value),
      onSignIn: _signIn,
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/logo.jpg',
              width: 104,
              height: 104,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Dream Force',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    required this.error,
    required this.loading,
    required this.termsAccepted,
    required this.screenTimeSyncConsent,
    required this.onTermsAcceptedChanged,
    required this.onScreenTimeSyncConsentChanged,
    required this.onSignIn,
    super.key,
  });
  final String? error;
  final bool loading;
  final bool termsAccepted;
  final bool screenTimeSyncConsent;
  final ValueChanged<bool> onTermsAcceptedChanged;
  final ValueChanged<bool> onScreenTimeSyncConsentChanged;
  final VoidCallback onSignIn;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1936 / 544,
            child: Image.asset(
              'assets/images/cover.jpg',
              fit: BoxFit.contain,
              semanticLabel: 'Consistency Over Intensity',
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Create account',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in with Google to protect your activities, plans, and session history.',
          ),
          const SizedBox(height: 24),
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!),
              ),
            ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: termsAccepted,
            onChanged: loading
                ? null
                : (value) => onTermsAcceptedChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I have read the Privacy Policy and agree to the Terms and Conditions.',
            ),
          ),
          CheckboxListTile(
            value: screenTimeSyncConsent,
            onChanged: loading
                ? null
                : (value) => onScreenTimeSyncConsentChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I consent to sync daily screen-time summaries to my account.',
            ),
            subtitle: const Text(
              'App names, daily totals, local dates, and time zone are stored in your account for Screen time Insights. No event timeline is uploaded. Turn sync off any time in Insights to delete synced data.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: loading || !termsAccepted ? null : onSignIn,
            icon: const Icon(Icons.account_circle_outlined),
            label: Text(
              loading ? 'Connecting to Google…' : 'Continue with Google',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Screen-time sync is optional and also requires Android Usage Access.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
