import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../brand_kit.dart';

/// Shared chrome for sign-in and sign-up.
///
/// Light, matching the marketing site rather than the old dark glass panel —
/// the two screens sit either side of the same click from the landing page, so
/// a hard cut from white to near-black read as a different product.
///
/// Both screens pass only their fields; the card, background, logo, heading and
/// back-link live here so they cannot drift apart.
class AuthScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  /// Optional banner between the heading and the fields.
  final Widget? banner;

  /// "Already have an account?" style prompt under the card.
  final Widget? footer;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.banner,
    this.footer,
  });

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);

    return Scaffold(
      backgroundColor: LK.white,
      body: Stack(
        children: [
          // Same backdrop as the landing hero, so arriving from the site feels
          // like the same place.
          const Positioned.fill(child: GridLines(spacing: 64)),
          Positioned.fill(
            child: MeshBackdrop(blobs: [
              (
                at: const Alignment(-0.9, -0.8),
                color: LK.tealPure,
                size: 640,
                opacity: 0.15
              ),
              (
                at: const Alignment(1.0, 0.9),
                color: LK.navy,
                size: 720,
                opacity: 0.12
              ),
            ]),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
              // minHeight pins the scroll content to at least the viewport, so
              // the card sits in the middle of the window on a desktop while
              // still scrolling when the form outgrows a short one.
              child: LayoutBuilder(builder: (context, viewport) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 20 : 32,
                    vertical: mobile ? 28 : 40,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewport.maxHeight - (mobile ? 56 : 80),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BackToSite(),
                            const SizedBox(height: 26),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => context.go('/'),
                                child: Image.asset(
                                  'assets/images/hotrest_logo_new.png',
                                  height: 38,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Text(
                                    'HotRest',
                                    style:
                                        LK.h3(context).copyWith(color: LK.navy),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(mobile ? 24 : 34),
                              decoration: BoxDecoration(
                                color: LK.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: LK.line),
                                boxShadow: [
                                  BoxShadow(
                                    color: LK.navy.withValues(alpha: 0.07),
                                    blurRadius: 40,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title,
                                    textAlign: TextAlign.center,
                                    style:
                                        LK.h3(context).copyWith(fontSize: 24),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    widget.subtitle,
                                    textAlign: TextAlign.center,
                                    style: LK.small.copyWith(color: LK.body),
                                  ),
                                  if (widget.banner != null) ...[
                                    const SizedBox(height: 20),
                                    widget.banner!,
                                  ],
                                  const SizedBox(height: 26),
                                  ...widget.children,
                                ],
                              ),
                            ),
                            if (widget.footer != null) ...[
                              const SizedBox(height: 22),
                              widget.footer!,
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackToSite extends StatefulWidget {
  @override
  State<_BackToSite> createState() => _BackToSiteState();
}

class _BackToSiteState extends State<_BackToSite> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => context.go('/'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded,
                  size: 16, color: _hover ? LK.teal : LK.muted),
              const SizedBox(width: 7),
              Text(
                'Back to site',
                style: LK.micro.copyWith(
                  color: _hover ? LK.teal : LK.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field styled for the light auth card.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool useFormField;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.onSubmitted,
    this.validator,
    this.useFormField = false,
  });

  InputDecoration _decoration() => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontFamily: 'Outfit', color: LK.muted, fontSize: 14.5),
        floatingLabelStyle: const TextStyle(
            fontFamily: 'Outfit', color: LK.teal, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: LK.muted, size: 20),
        suffixIcon: trailing,
        filled: true,
        fillColor: LK.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LK.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LK.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LK.teal, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LK.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LK.danger, width: 1.7),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      );

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'Outfit', fontSize: 15, color: LK.ink);

    // Signup validates through a Form; login does its own checks, and a
    // TextFormField outside a Form would be harmless but misleading.
    if (useFormField) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        style: style,
        decoration: _decoration(),
        validator: validator,
        onFieldSubmitted: onSubmitted,
      );
    }
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: style,
      decoration: _decoration(),
      onSubmitted: onSubmitted,
    );
  }
}

/// Inline validation message under the fields.
class AuthInlineError extends StatelessWidget {
  final String message;
  const AuthInlineError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LK.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: LK.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: LK.danger, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: LK.micro.copyWith(color: LK.danger, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Button-shaped spinner, so the card does not change height while submitting.
class AuthBusyButton extends StatelessWidget {
  const AuthBusyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LK.navy.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const SizedBox(
        width: 21,
        height: 21,
        child: CircularProgressIndicator(strokeWidth: 2.3, color: Colors.white),
      ),
    );
  }
}

/// "Don't have an account? Create one" prompt beneath the card.
class AuthFooterPrompt extends StatefulWidget {
  final String question;
  final String action;
  final VoidCallback onTap;
  const AuthFooterPrompt({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  @override
  State<AuthFooterPrompt> createState() => _AuthFooterPromptState();
}

class _AuthFooterPromptState extends State<AuthFooterPrompt> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(widget.question, style: LK.micro.copyWith(fontSize: 13.5)),
        const SizedBox(width: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Text(
              widget.action,
              style: TextStyle(
                fontFamily: 'Outfit',
                color: LK.teal,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                decoration: _hover ? TextDecoration.underline : null,
                decorationColor: LK.teal,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
