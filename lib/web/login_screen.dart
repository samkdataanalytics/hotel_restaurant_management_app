import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:go_router/go_router.dart';

import '../providers/app_auth_provider.dart';
import '../router.dart';
import '../services/auth_identity.dart';
import 'auth/auth_scaffold.dart';
import 'brand_kit.dart';
import 'cms/data/site_providers.dart';
import 'cms/defaults/site_defaults.dart';
import 'cms/model/json_reader.dart';
import 'cms/render/seo_scope.dart';
import 'cms/sections/auth_copy_section.dart';

/// Staff and owner sign-in.
///
/// Light, on the brand palette, sharing [AuthScaffold] with signup so the two
/// screens cannot drift apart.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email or username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Staff sign in by username; resolveSignInEmail builds the synthetic
    // {username}@staff.internal address. Shared with the staff mobile app.
    final email = resolveSignInEmail(input);

    // Sign in via the Riverpod auth notifier — GoRouter's redirect handles
    // navigation on success.
    final err = await ref.read(authProvider.notifier).signIn(email, password);

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _isLoading = false;
        _error = null;
      });
      if (err == 'EMAIL_NOT_CONFIRMED') {
        context.go('${AppRoutes.verifyEmail}?email=${Uri.encodeComponent(email)}');
        return;
      }
      _showAuthError(err);
    }
  }

  /// Supabase messages are written for developers; these name the next action.
  void _showAuthError(String message) {
    final m = message.toLowerCase();
    final String title;
    final String detail;

    if (m.contains('invalid login') ||
        m.contains('invalid credentials') ||
        m.contains('user not found')) {
      title = 'Account not found';
      detail = 'No account matches these credentials. Check your email or '
          'username and password, or create a new account.';
    } else if (m.contains('wrong password') || m.contains('invalid password')) {
      title = 'Incorrect password';
      detail = 'The password you entered is incorrect. Please try again.';
    } else if (m.contains('email not confirmed')) {
      title = 'Email not verified';
      detail = 'Please verify your email address before signing in.';
    } else {
      title = 'Sign-in failed';
      detail = message;
    }

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LK.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: LK.danger.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.priority_high_rounded, color: LK.danger, size: 24),
        ),
        title: Text(title, style: LK.h3(context), textAlign: TextAlign.center),
        content: Text(detail, style: LK.small, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CtaButton(
              label: 'Try again',
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  /// The wording, from the `page:auth` document (or as it shipped).
  LoginCopy _copy() {
    LoginCopy? find(List<dynamic> sections) {
      for (final s in sections) {
        if (s.type == 'loginCopy' && s.enabled) return LoginCopy.fromJson(s.content);
      }
      return null;
    }

    return find(ref.watch(siteDocumentProvider('page:auth')).sections) ??
        find(siteDefaultDocument('page:auth').sections)!;
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy();
    return SeoScope(
        seo: J({'title': copy.metaTitle}),
        fallbackTitle: 'Sign in — HotRest',
        child: AuthScaffold(
          title: copy.title,
          subtitle: copy.subtitle,
          footer: AuthFooterPrompt(
            question: copy.footerQuestion,
            action: copy.footerAction,
            onTap: () => context.go(AppRoutes.signup),
          ),
          children: [
            AuthField(
              controller: _emailController,
              label: copy.identifierLabel,
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            AuthField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: copy.passwordLabel,
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _isLoading ? null : _login(),
              trailing: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: LK.muted,
                  size: 20,
                ),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              AuthInlineError(_error!),
            ],
            const SizedBox(height: 24),
            if (_isLoading)
              const AuthBusyButton()
            else
              CtaButton(label: copy.submitLabel, expand: true, onTap: _login),
          ],
        ));
  }
}
