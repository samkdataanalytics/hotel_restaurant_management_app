import 'package:flutter/material.dart';

import '../../auth/auth_scaffold.dart';
import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../model/tokens.dart';
import '../registry/section_registry.dart';

/// The words on the sign-in screen. Behaviour (validation, errors from the server,
/// redirects) stays in code; only the wording a visitor reads before they type is
/// content.
class LoginCopy {
  const LoginCopy({
    required this.metaTitle,
    required this.title,
    required this.subtitle,
    required this.identifierLabel,
    required this.passwordLabel,
    required this.submitLabel,
    required this.footerQuestion,
    required this.footerAction,
  });

  factory LoginCopy.fromJson(J j) => LoginCopy(
        metaTitle: j.str('metaTitle'),
        title: expandTokens(j.str('title')),
        subtitle: expandTokens(j.str('subtitle')),
        identifierLabel: j.str('identifierLabel', 'Email or username'),
        passwordLabel: j.str('passwordLabel', 'Password'),
        submitLabel: j.str('submitLabel', 'Sign in'),
        footerQuestion: j.str('footerQuestion'),
        footerAction: j.str('footerAction', 'Create one'),
      );

  /// The browser tab title for this screen.
  final String metaTitle;
  final String title;
  final String subtitle;
  final String identifierLabel;
  final String passwordLabel;
  final String submitLabel;
  final String footerQuestion;
  final String footerAction;
}

class SignupCopy {
  const SignupCopy({
    required this.metaTitle,
    required this.title,
    required this.subtitle,
    required this.trialBanner,
    required this.emailLabel,
    required this.passwordLabel,
    required this.passwordHint,
    required this.confirmLabel,
    required this.submitLabel,
    required this.terms,
    required this.footerQuestion,
    required this.footerAction,
    required this.sentTitle,
    required this.sentSubtitle,
    required this.sentLead,
    required this.sentHelp,
    required this.sentPrimary,
    required this.sentSecondary,
  });

  factory SignupCopy.fromJson(J j) => SignupCopy(
        metaTitle: j.str('metaTitle'),
        title: expandTokens(j.str('title')),
        subtitle: expandTokens(j.str('subtitle')),
        trialBanner: expandTokens(j.str('trialBanner')),
        emailLabel: j.str('emailLabel', 'Work email'),
        passwordLabel: j.str('passwordLabel', 'Password'),
        passwordHint: j.str('passwordHint'),
        confirmLabel: j.str('confirmLabel', 'Confirm password'),
        submitLabel: j.str('submitLabel', 'Create account'),
        terms: expandTokens(j.str('terms')),
        footerQuestion: j.str('footerQuestion'),
        footerAction: j.str('footerAction', 'Sign in'),
        sentTitle: j.str('sentTitle'),
        sentSubtitle: j.str('sentSubtitle'),
        sentLead: j.str('sentLead'),
        sentHelp: j.str('sentHelp'),
        sentPrimary: j.str('sentPrimary', 'Go to sign in'),
        sentSecondary: j.str('sentSecondary', 'Use a different email'),
      );

  final String metaTitle;
  final String title;
  final String subtitle;
  final String trialBanner;
  final String emailLabel;
  final String passwordLabel;
  final String passwordHint;
  final String confirmLabel;
  final String submitLabel;
  final String terms;
  final String footerQuestion;
  final String footerAction;
  final String sentTitle;
  final String sentSubtitle;
  final String sentLead;
  final String sentHelp;
  final String sentPrimary;
  final String sentSecondary;
}

final loginCopyDefinition = SectionDefinition(
  type: 'loginCopy',
  label: 'Sign-in screen',
  builder: (context, SectionNode node) => AuthPreview.login(LoginCopy.fromJson(node.content)),
);

final signupCopyDefinition = SectionDefinition(
  type: 'signupCopy',
  label: 'Sign-up screen',
  builder: (context, SectionNode node) => AuthPreview.signup(SignupCopy.fromJson(node.content)),
);

/// The auth card with its fields, drawn for the studio preview. The live screens
/// use [AuthScaffold] and real inputs; this shows how the wording sits.
class AuthPreview extends StatelessWidget {
  const AuthPreview._(this._build);

  factory AuthPreview.login(LoginCopy c) => AuthPreview._((context) => [
        AuthCard(
          title: c.title,
          subtitle: c.subtitle,
          children: [
            _field(c.identifierLabel, Icons.person_outline_rounded),
            const SizedBox(height: 14),
            _field(c.passwordLabel, Icons.lock_outline_rounded),
            const SizedBox(height: 24),
            CtaButton(label: c.submitLabel, expand: true, onTap: () {}),
          ],
        ),
        const SizedBox(height: 22),
        _prompt(c.footerQuestion, c.footerAction),
      ]);

  factory AuthPreview.signup(SignupCopy c) => AuthPreview._((context) => [
        AuthCard(
          title: c.title,
          subtitle: c.subtitle,
          banner: c.trialBanner.isEmpty ? null : _Banner(c.trialBanner),
          children: [
            _field(c.emailLabel, Icons.mail_outline_rounded),
            const SizedBox(height: 14),
            _field(c.passwordLabel, Icons.lock_outline_rounded),
            if (c.passwordHint.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(c.passwordHint, style: LK.micro.copyWith(fontSize: 12)),
              ),
            ],
            const SizedBox(height: 10),
            _field(c.confirmLabel, Icons.lock_person_outlined),
            const SizedBox(height: 24),
            CtaButton(label: c.submitLabel, expand: true, onTap: () {}),
            if (c.terms.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(c.terms, textAlign: TextAlign.center, style: LK.micro.copyWith(fontSize: 11.5)),
            ],
          ],
        ),
        const SizedBox(height: 22),
        _prompt(c.footerQuestion, c.footerAction),
      ]);

  final List<Widget> Function(BuildContext) _build;

  static Widget _field(String label, IconData icon) => IgnorePointer(
        child: AuthField(controller: TextEditingController(), label: label, icon: icon),
      );

  static Widget _prompt(String q, String a) => AuthFooterPrompt(question: q, action: a, onTap: () {});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: _build(context)),
        ),
      ),
    );
  }
}

/// The "free trial" strip above the sign-up fields.
class _Banner extends StatelessWidget {
  const _Banner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => TrialBanner(text: text);
}

/// The trial promise above the sign-up fields. Public so the real screen and the
/// editor preview share it.
class TrialBanner extends StatelessWidget {
  const TrialBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: LK.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LK.teal.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: LK.teal, size: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: LK.micro.copyWith(
                color: LK.teal,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
