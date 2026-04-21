import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Palette (same as landing) ────────────────────────────────────────────────
class _C {
  static const bg      = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8FAFC);
  static const border  = Color(0xFFE2E8F0);
  static const gold    = Color(0xFFD4A853);
  static const goldLight = Color(0xFFEDD07A);
  static const text    = Color(0xFF0F172A);
  static const subtext = Color(0xFF64748B);
  static const muted   = Color(0xFF94A3B8);
}

enum LegalPage { terms, returns, privacy }

extension LegalPageX on LegalPage {
  String get title => switch (this) {
    LegalPage.terms   => 'Terms of Service',
    LegalPage.returns => 'Return & Refund Policy',
    LegalPage.privacy => 'Privacy Policy',
  };

  String get lastUpdated => 'April 8, 2025';
}

class LegalScreen extends StatelessWidget {
  final LegalPage page;
  const LegalScreen({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 48,
              vertical: 20,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                // Logo
                GestureDetector(
                  onTap: () => context.go('/'),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/images/hotrest_logo.webp',
                        width: 34, height: 34, fit: BoxFit.contain),
                    const SizedBox(width: 8),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (b) => const LinearGradient(
                        colors: [_C.goldLight, _C.gold],
                      ).createShader(b),
                      child: const Text('HotRest',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17)),
                    ),
                  ]),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16,
                      color: _C.subtext),
                  label: const Text('Back to Home',
                      style: TextStyle(color: _C.subtext, fontSize: 13)),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
              ],
            ),
          ),

          // ── Scrollable content ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 40,
                      vertical: 48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page header
                        Text(page.title,
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: _C.text,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Text('Last updated: ${page.lastUpdated}',
                            style: const TextStyle(
                                color: _C.muted, fontSize: 13)),
                        const SizedBox(height: 32),
                        const Divider(color: _C.border),
                        const SizedBox(height: 32),

                        // Content
                        _buildContent(page),

                        const SizedBox(height: 64),

                        // Footer links
                        const Divider(color: _C.border),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 24,
                          runSpacing: 8,
                          children: LegalPage.values.map((p) {
                            final active = p == page;
                            return TextButton(
                              onPressed: active ? null : () => context.go(_routeFor(p)),
                              style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero),
                              child: Text(p.title,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: active ? _C.gold : _C.muted,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w400)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        const Text('© 2025 HotRest. All rights reserved.',
                            style: TextStyle(
                                color: _C.muted, fontSize: 12)),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _routeFor(LegalPage p) => switch (p) {
    LegalPage.terms   => '/terms',
    LegalPage.returns => '/returns',
    LegalPage.privacy => '/privacy',
  };

  Widget _buildContent(LegalPage page) => switch (page) {
    LegalPage.terms   => const _TermsContent(),
    LegalPage.returns => const _ReturnsContent(),
    LegalPage.privacy => const _PrivacyContent(),
  };
}

// ─── Section helpers ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String heading;
  final List<Widget> children;
  const _Section({required this.heading, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _C.text)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14, color: _C.subtext, height: 1.7)),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: CircleAvatar(
                radius: 3, backgroundColor: _C.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: _C.subtext, height: 1.7)),
          ),
        ],
      ),
    );
  }
}

// ─── Terms of Service ─────────────────────────────────────────────────────────

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(heading: '1. Acceptance of Terms', children: [
          _Body(
              'By accessing or using HotRest ("the Service"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the Service.'),
          _Body(
              'HotRest is a SaaS platform providing hotel and restaurant management tools. These terms apply to all users, including administrators, staff members, and guests who interact with the platform.'),
        ]),
        _Section(heading: '2. Account Registration', children: [
          _Body(
              'To use the Service, you must create an account by providing accurate and complete information. You are responsible for maintaining the confidentiality of your login credentials.'),
          _Bullet('You must be at least 18 years old to create an account.'),
          _Bullet('One organisation may have multiple properties and staff accounts under a single subscription.'),
          _Bullet('You are responsible for all activity that occurs under your account.'),
        ]),
        _Section(heading: '3. Subscription Plans & Billing', children: [
          _Body(
              'HotRest offers Free, Starter, Pro, and Enterprise subscription plans. Plan features and limits are described on the pricing page and may change with reasonable notice.'),
          _Bullet('Subscriptions are billed monthly or annually as selected at sign-up.'),
          _Bullet('Enterprise plans are negotiated individually and governed by a separate agreement.'),
          _Bullet('You authorise HotRest to charge the payment method on file at each billing cycle.'),
          _Bullet('Failure to pay may result in suspension or termination of your account.'),
        ]),
        _Section(heading: '4. Acceptable Use', children: [
          _Body('You agree not to:'),
          _Bullet('Use the Service for any unlawful purpose or in violation of any regulations.'),
          _Bullet('Attempt to gain unauthorised access to other accounts or systems.'),
          _Bullet('Interfere with the proper functioning of the platform.'),
          _Bullet('Reverse engineer, copy, or resell any part of the Service.'),
          _Bullet('Upload malicious code, spam, or harmful content.'),
        ]),
        _Section(heading: '5. Data & Intellectual Property', children: [
          _Body(
              'You retain ownership of all data you input into HotRest. By using the Service, you grant HotRest a limited licence to process your data solely to provide the Service.'),
          _Body(
              'All platform software, branding, and content are the intellectual property of HotRest and may not be used without prior written consent.'),
        ]),
        _Section(heading: '6. Limitation of Liability', children: [
          _Body(
              'HotRest is provided "as is" without warranties of any kind. To the fullest extent permitted by law, HotRest shall not be liable for any indirect, incidental, special, or consequential damages arising out of your use of the Service.'),
        ]),
        _Section(heading: '7. Termination', children: [
          _Body(
              'We reserve the right to suspend or terminate your account at any time for violation of these terms. You may cancel your account at any time from your account settings.'),
        ]),
        _Section(heading: '8. Changes to Terms', children: [
          _Body(
              'We may update these terms from time to time. We will notify you of significant changes via email or an in-app notice. Continued use of the Service constitutes acceptance of the updated terms.'),
        ]),
        _Section(heading: '9. Contact', children: [
          _Body(
              'For any questions about these Terms, please contact us at kasun@ideadeck.biz.'),
        ]),
      ],
    );
  }
}

// ─── Return & Refund Policy ───────────────────────────────────────────────────

class _ReturnsContent extends StatelessWidget {
  const _ReturnsContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(heading: 'Overview', children: [
          _Body(
              'HotRest is a software-as-a-service (SaaS) platform. Because we deliver digital services rather than physical goods, our refund policy reflects the nature of software subscriptions.'),
        ]),
        _Section(heading: '1. Free Plan', children: [
          _Body(
              'The Free plan is available at no charge and is not eligible for any refund consideration.'),
        ]),
        _Section(heading: '2. Paid Subscriptions — 14-Day Trial Period', children: [
          _Body(
              'New paid subscriptions (Starter and Pro) are eligible for a full refund if requested within 14 days of the initial charge, provided the account has not exceeded reasonable usage limits (defined as fewer than 100 orders processed during the trial period).'),
          _Body(
              'To request a refund within the trial period, contact kasun@ideadeck.biz with your account email and reason for the refund.'),
        ]),
        _Section(heading: '3. After the Trial Period', children: [
          _Body(
              'After the 14-day trial period, subscription fees are non-refundable. You may cancel your subscription at any time, and access will continue until the end of the current billing period.'),
          _Bullet('Monthly subscriptions: access continues until the end of the current month.'),
          _Bullet('Annual subscriptions: access continues until the end of the paid annual term.'),
          _Bullet('No pro-rated refunds are issued for early cancellation of annual plans.'),
        ]),
        _Section(heading: '4. Billing Errors', children: [
          _Body(
              'If you believe you have been charged in error (e.g. duplicate charge or incorrect plan amount), please contact us within 30 days of the charge. We will investigate and, if the error is confirmed, issue a full refund for the incorrect amount within 5–10 business days.'),
        ]),
        _Section(heading: '5. Enterprise Plans', children: [
          _Body(
              'Refund terms for Enterprise plans are governed by the individual agreement signed between HotRest and the customer. Please refer to your contract or contact your account manager.'),
        ]),
        _Section(heading: '6. Chargebacks', children: [
          _Body(
              'If you initiate a chargeback or payment dispute with your bank without first contacting us, we reserve the right to suspend your account until the matter is resolved.'),
        ]),
        _Section(heading: '7. How to Request a Refund', children: [
          _Body('Please email kasun@ideadeck.biz with:'),
          _Bullet('Your registered email address.'),
          _Bullet('The invoice number or date of charge.'),
          _Bullet('The reason for the refund request.'),
          _Body(
              'We aim to respond to all refund requests within 3 business days.'),
        ]),
      ],
    );
  }
}

// ─── Privacy Policy ───────────────────────────────────────────────────────────

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(heading: 'Introduction', children: [
          _Body(
              'HotRest ("we", "our", "us") is committed to protecting your personal information. This Privacy Policy explains what data we collect, how we use it, and your rights regarding that data.'),
          _Body(
              'By using HotRest, you agree to the collection and use of information in accordance with this policy.'),
        ]),
        _Section(heading: '1. Information We Collect', children: [
          _Body('We collect the following categories of information:'),
          _Bullet('Account information: name, email address, phone number, and business details provided during registration.'),
          _Bullet('Usage data: features used, pages visited, session duration, and interaction logs for improving the platform.'),
          _Bullet('Operational data: hotel bookings, guest records, restaurant orders, inventory, and financial reports that you enter into the platform. This data belongs to you.'),
          _Bullet('Payment information: processed securely via third-party payment providers. We do not store full card numbers on our servers.'),
          _Bullet('Device & technical data: IP address, browser type, and device identifiers for security and analytics purposes.'),
        ]),
        _Section(heading: '2. How We Use Your Information', children: [
          _Body('We use your data to:'),
          _Bullet('Provide, operate, and improve the HotRest platform.'),
          _Bullet('Process payments and manage billing.'),
          _Bullet('Send transactional emails (e.g. invoices, password resets, account notifications).'),
          _Bullet('Respond to support requests and enquiries.'),
          _Bullet('Detect and prevent fraud or security incidents.'),
          _Bullet('Comply with legal obligations.'),
          _Body(
              'We do not sell your personal data to third parties and we do not use your operational data (guest records, orders, etc.) for any purpose other than providing the Service to you.'),
        ]),
        _Section(heading: '3. Data Storage & Security', children: [
          _Body(
              'Your data is stored on Supabase-hosted infrastructure with industry-standard encryption at rest and in transit (TLS 1.2+). Access to production data is restricted to authorised personnel only.'),
          _Body(
              'While we take all reasonable precautions, no method of transmission over the internet is 100% secure. We cannot guarantee absolute security.'),
        ]),
        _Section(heading: '4. Data Retention', children: [
          _Body(
              'We retain your account data for as long as your account is active. If you close your account, we will delete or anonymise your personal data within 90 days, unless retention is required by law.'),
          _Body(
              'Operational data (orders, bookings, etc.) is retained for 7 years to meet standard financial record-keeping requirements, after which it is securely deleted.'),
        ]),
        _Section(heading: '5. Third-Party Services', children: [
          _Body('HotRest uses trusted third-party services that may process your data:'),
          _Bullet('Supabase — database and authentication infrastructure.'),
          _Bullet('Payhere / payment processors — payment handling.'),
          _Bullet('Google Fonts — font delivery (no personal data shared).'),
          _Body(
              'Each third-party provider has their own privacy policy. We encourage you to review them.'),
        ]),
        _Section(heading: '6. Cookies', children: [
          _Body(
              'We use essential session cookies to keep you logged in and to maintain application state. We do not use tracking or advertising cookies.'),
        ]),
        _Section(heading: '7. Your Rights', children: [
          _Body('Depending on your jurisdiction, you may have the right to:'),
          _Bullet('Access the personal data we hold about you.'),
          _Bullet('Request correction of inaccurate data.'),
          _Bullet('Request deletion of your personal data ("right to be forgotten").'),
          _Bullet('Object to or restrict certain processing activities.'),
          _Bullet('Export your data in a portable format.'),
          _Body(
              'To exercise any of these rights, please email kasun@ideadeck.biz. We will respond within 30 days.'),
        ]),
        _Section(heading: '8. Children\'s Privacy', children: [
          _Body(
              'HotRest is not intended for use by individuals under the age of 18. We do not knowingly collect personal data from minors.'),
        ]),
        _Section(heading: '9. Changes to This Policy', children: [
          _Body(
              'We may update this Privacy Policy periodically. When we do, we will revise the "last updated" date at the top of this page and notify you via email for material changes.'),
        ]),
        _Section(heading: '10. Contact', children: [
          _Body(
              'For privacy-related questions or to exercise your rights, please contact our Data Protection team at kasun@ideadeck.biz.'),
        ]),
      ],
    );
  }
}
