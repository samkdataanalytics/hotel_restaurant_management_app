import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_auth_provider.dart';
import '../../../services/auth_identity.dart';

/// Staff sign-in.
///
/// Accepts a username or an email in one field, exactly like the web login:
/// `resolveSignInEmail` is shared with `lib/web/login_screen.dart` so the
/// `{username}@staff.internal` rule cannot drift between the two.
class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final identifier = _identifier.text.trim();
    final password = _password.text;

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your username and password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final email = resolveSignInEmail(identifier);
    final err = await ref.read(authProvider.notifier).signIn(email, password);

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _busy = false;
        _error = _friendly(err);
      });
      return;
    }

    // No navigation here. StaffSession watches authProvider, so it rebuilds on
    // its own, and the router's refreshListenable redirects off /login once the
    // new session resolves. Pushing a route here would race that redirect.
  }

  /// Supabase messages are written for developers. Staff need the next action.
  String _friendly(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login') ||
        m.contains('invalid credentials') ||
        m.contains('user not found')) {
      return 'That username or password is not right. Check with your manager '
          'if you have forgotten it.';
    }
    if (raw == 'EMAIL_NOT_CONFIRMED' || m.contains('not confirmed')) {
      return 'This email is not verified yet. Verify it on the web, then sign '
          'in here.';
    }
    if (m.contains('network') || m.contains('socket') || m.contains('failed host')) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.restaurant_rounded, size: 56, color: scheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    'HotRest Staff',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to start your shift',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 36),

                  TextField(
                    controller: _identifier,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.visiblePassword,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(
                      labelText: 'Username or email',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.go,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                      ),
                    ),
                    onSubmitted: (_) => _busy ? null : _signIn(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 20, color: scheme.onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: scheme.onErrorContainer,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
