import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as webpkg;

import '../providers/app_auth_provider.dart';
import '../router.dart';
import 'auth/auth_scaffold.dart';
import 'brand_kit.dart';
import 'cms/data/site_providers.dart';
import 'cms/defaults/site_defaults.dart';
import 'cms/model/json_reader.dart';
import 'cms/render/seo_scope.dart';
import 'cms/sections/auth_copy_section.dart';

/// Create an account.
///
/// Shares [AuthScaffold] with sign-in. The signup logic is unchanged: the plan
/// slug from the landing page is held in SharedPreferences for onboarding to
/// pick up, and Supabase's email-enumeration behaviour is still handled.
class SignupScreen extends ConsumerStatefulWidget {
  /// Slug forwarded from the landing page, e.g. "starter".
  final String? plan;
  const SignupScreen({super.key, this.plan});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _emailSent = false;
  String? _error;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final origin = webpkg.window.location.origin;
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: '$origin${AppRoutes.emailVerified}',
      );

      if (!mounted) return;

      if (res.user == null) {
        setState(() {
          _isLoading = false;
          _error = 'Sign up failed. Please try again.';
        });
        return;
      }

      // Supabase returns a fake success for existing emails (email enumeration
      // protection). The identities list is empty when the email is already
      // registered.
      if (res.user!.identities != null && res.user!.identities!.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'An account with this email already exists. Sign in instead.';
        });
        return;
      }

      // If a session comes back immediately (email confirmation disabled),
      // load the auth context then let the router move on — keeping the plan
      // the visitor picked on the pricing table.
      if (res.session != null) {
        final plan = widget.plan;
        if (plan != null && plan.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_plan', plan);
        }
        await ref.read(authProvider.notifier).reload();
        // GoRouter's redirect takes over → onboarding, since a new user has
        // no organisation or property yet.
        return;
      }

      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Unexpected error: $e';
      });
    }
  }

  /// The wording, from the `page:auth` document (or as it shipped).
  SignupCopy _copy() {
    SignupCopy? find(List<dynamic> sections) {
      for (final s in sections) {
        if (s.type == 'signupCopy' && s.enabled) return SignupCopy.fromJson(s.content);
      }
      return null;
    }

    return find(ref.watch(siteDocumentProvider('page:auth')).sections) ??
        find(siteDefaultDocument('page:auth').sections)!;
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy();
    if (_emailSent) return _sentScaffold(copy);

    return SeoScope(
      seo: J({'title': copy.metaTitle}),
      fallbackTitle: 'Create your account — HotRest',
      child: AuthScaffold(
      title: copy.title,
      subtitle: copy.subtitle,
      banner: copy.trialBanner.isEmpty ? null : TrialBanner(text: copy.trialBanner),
      footer: AuthFooterPrompt(
        question: copy.footerQuestion,
        action: copy.footerAction,
        onTap: () => context.go(AppRoutes.login),
      ),
      children: [
        AuthField(
          controller: _emailController,
          label: copy.emailLabel,
          icon: Icons.mail_outline_rounded,
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
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _confirmFocus.requestFocus(),
          trailing: IconButton(
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: LK.muted,
              size: 20,
            ),
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          ),
        ),
        if (copy.passwordHint.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(copy.passwordHint, style: LK.micro.copyWith(fontSize: 12)),
          ),
        ],
        const SizedBox(height: 10),
        AuthField(
          controller: _confirmController,
          focusNode: _confirmFocus,
          label: copy.confirmLabel,
          icon: Icons.lock_person_outlined,
          obscure: _obscureConfirm,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _isLoading ? null : _signup(),
          trailing: IconButton(
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: LK.muted,
              size: 20,
            ),
            tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
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
          CtaButton(label: copy.submitLabel, expand: true, onTap: _signup),
        if (copy.terms.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            copy.terms,
            textAlign: TextAlign.center,
            style: LK.micro.copyWith(fontSize: 11.5),
          ),
        ],
      ],
    ));
  }

  Widget _sentScaffold(SignupCopy copy) => AuthScaffold(
        title: copy.sentTitle,
        subtitle: copy.sentSubtitle,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: LK.teal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LK.teal.withValues(alpha: 0.22)),
            ),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: LK.teal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_outlined,
                      color: LK.teal, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  copy.sentLead,
                  textAlign: TextAlign.center,
                  style: LK.small,
                ),
                const SizedBox(height: 4),
                Text(
                  _emailController.text.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: LK.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  copy.sentHelp,
                  textAlign: TextAlign.center,
                  style: LK.micro.copyWith(fontSize: 12.5, height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          CtaButton(
            label: copy.sentPrimary,
            expand: true,
            onTap: () => context.go(AppRoutes.login),
          ),
          const SizedBox(height: 12),
          GhostButton(
            label: copy.sentSecondary,
            expand: true,
            onTap: () => setState(() {
              _emailSent = false;
              _error = null;
            }),
          ),
        ],
      );
}
