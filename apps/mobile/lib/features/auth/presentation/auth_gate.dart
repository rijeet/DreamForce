import 'dart:async';

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
  final Widget Function(SignedInUser user) child;
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
  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      if (_serverClientId.isNotEmpty) {
        await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
        final account = await GoogleSignIn.instance
            .attemptLightweightAuthentication();
        if (account != null && await const DreamForceAuthApi().hasSession()) {
          _user = SignedInUser(
            account.email,
            account.displayName,
            account.photoUrl,
          );
        }
      }
    } catch (error) {
      _error =
          'Could not restore sign-in. Confirm GOOGLE_SERVER_CLIENT_ID, Android package/SHA-1 setup, and the network, then retry. (${_safeError(error)})';
    }
    if (mounted) {
      setState(() => _loading = false);
    }
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
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthApiException(
          'Google sign-in returned no ID token. Set the app’s GOOGLE_SERVER_CLIENT_ID to the Web application OAuth client ID. (GOOGLE_ID_TOKEN_MISSING)',
        );
      }
      await const DreamForceAuthApi().exchangeGoogleIdToken(idToken);
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

  String _safeError(Object error) {
    final message = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return message.length > 180 ? '${message.substring(0, 180)}…' : message;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SplashScreen();
    if (_user != null) return widget.child(_user!);
    return AccountScreen(error: _error, loading: _signingIn, onSignIn: _signIn);
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
    required this.onSignIn,
    super.key,
  });
  final String? error;
  final bool loading;
  final VoidCallback onSignIn;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo.jpg',
                height: 92,
                fit: BoxFit.cover,
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
            FilledButton.icon(
              onPressed: loading ? null : onSignIn,
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(
                loading ? 'Connecting to Google…' : 'Continue with Google',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'By continuing, you agree to the Privacy Policy and Terms.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
}
