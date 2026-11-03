// The three legal pages exactly as they shipped, generated from the original
// widget tree. The contradictions in them (a Free plan that no longer exists, a
// 14-day refund window beside a 45-day trial) are the owner's to resolve; they
// are reproduced here, not corrected.
//
// `{supportEmail}` stands for the contact address, which used to be typed into
// each page; it is filled from `global:site`.

const Map<String, Object?> kTermsDefaults = {
  'schema': 1,
  'seo': {'title': 'Terms of Service — HotRest'},
  'sections': [
    {
      'id': 'terms',
      'type': 'legalDoc',
      'layout': {'spaceBefore': 'none'},
      'style': {'reveal': false},
      'content': {
        'title': 'Terms of Service',
        'updated': 'April 8, 2025',
        'updatedLabel': 'Last updated: {date}',
        'backLabel': 'Back to Home',
        'copyright': '© {year} HotRest. All rights reserved.',
        'footerLinks': [
            {'label': 'Terms of Service', 'link': {'type': 'internal', 'value': '/terms'}},
            {'label': 'Return & Refund Policy', 'link': {'type': 'internal', 'value': '/returns'}},
            {'label': 'Privacy Policy', 'link': {'type': 'internal', 'value': '/privacy'}},
        ],
        'sections': [
          {
            'heading': '1. Acceptance of Terms',
            'blocks': [
              {'kind': 'p', 'text': 'By accessing or using HotRest ("the Service"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the Service.'},
              {'kind': 'p', 'text': 'HotRest is a SaaS platform providing hotel and restaurant management tools. These terms apply to all users, including administrators, staff members, and guests who interact with the platform.'},
            ],
          },
          {
            'heading': '2. Account Registration',
            'blocks': [
              {'kind': 'p', 'text': 'To use the Service, you must create an account by providing accurate and complete information. You are responsible for maintaining the confidentiality of your login credentials.'},
              {'kind': 'bullet', 'text': 'You must be at least 18 years old to create an account.'},
              {'kind': 'bullet', 'text': 'One organisation may have multiple properties and staff accounts under a single subscription.'},
              {'kind': 'bullet', 'text': 'You are responsible for all activity that occurs under your account.'},
            ],
          },
          {
            'heading': '3. Subscription Plans & Billing',
            'blocks': [
              {'kind': 'p', 'text': 'HotRest offers Free, Starter, Pro, and Enterprise subscription plans. Plan features and limits are described on the pricing page and may change with reasonable notice.'},
              {'kind': 'bullet', 'text': 'Subscriptions are billed monthly or annually as selected at sign-up.'},
              {'kind': 'bullet', 'text': 'Enterprise plans are negotiated individually and governed by a separate agreement.'},
              {'kind': 'bullet', 'text': 'You authorise HotRest to charge the payment method on file at each billing cycle.'},
              {'kind': 'bullet', 'text': 'Failure to pay may result in suspension or termination of your account.'},
            ],
          },
          {
            'heading': '4. Acceptable Use',
            'blocks': [
              {'kind': 'p', 'text': 'You agree not to:'},
              {'kind': 'bullet', 'text': 'Use the Service for any unlawful purpose or in violation of any regulations.'},
              {'kind': 'bullet', 'text': 'Attempt to gain unauthorised access to other accounts or systems.'},
              {'kind': 'bullet', 'text': 'Interfere with the proper functioning of the platform.'},
              {'kind': 'bullet', 'text': 'Reverse engineer, copy, or resell any part of the Service.'},
              {'kind': 'bullet', 'text': 'Upload malicious code, spam, or harmful content.'},
            ],
          },
          {
            'heading': '5. Data & Intellectual Property',
            'blocks': [
              {'kind': 'p', 'text': 'You retain ownership of all data you input into HotRest. By using the Service, you grant HotRest a limited licence to process your data solely to provide the Service.'},
              {'kind': 'p', 'text': 'All platform software, branding, and content are the intellectual property of HotRest and may not be used without prior written consent.'},
            ],
          },
          {
            'heading': '6. Limitation of Liability',
            'blocks': [
              {'kind': 'p', 'text': 'HotRest is provided "as is" without warranties of any kind. To the fullest extent permitted by law, HotRest shall not be liable for any indirect, incidental, special, or consequential damages arising out of your use of the Service.'},
            ],
          },
          {
            'heading': '7. Termination',
            'blocks': [
              {'kind': 'p', 'text': 'We reserve the right to suspend or terminate your account at any time for violation of these terms. You may cancel your account at any time from your account settings.'},
            ],
          },
          {
            'heading': '8. Changes to Terms',
            'blocks': [
              {'kind': 'p', 'text': 'We may update these terms from time to time. We will notify you of significant changes via email or an in-app notice. Continued use of the Service constitutes acceptance of the updated terms.'},
            ],
          },
          {
            'heading': '9. Contact',
            'blocks': [
              {'kind': 'p', 'text': 'For any questions about these Terms, please contact us at {supportEmail}.'},
            ],
          },
        ],
      },
    },
  ],
};

const Map<String, Object?> kReturnsDefaults = {
  'schema': 1,
  'seo': {'title': 'Return & Refund Policy — HotRest'},
  'sections': [
    {
      'id': 'returns',
      'type': 'legalDoc',
      'layout': {'spaceBefore': 'none'},
      'style': {'reveal': false},
      'content': {
        'title': 'Return & Refund Policy',
        'updated': 'April 8, 2025',
        'updatedLabel': 'Last updated: {date}',
        'backLabel': 'Back to Home',
        'copyright': '© {year} HotRest. All rights reserved.',
        'footerLinks': [
            {'label': 'Terms of Service', 'link': {'type': 'internal', 'value': '/terms'}},
            {'label': 'Return & Refund Policy', 'link': {'type': 'internal', 'value': '/returns'}},
            {'label': 'Privacy Policy', 'link': {'type': 'internal', 'value': '/privacy'}},
        ],
        'sections': [
          {
            'heading': 'Overview',
            'blocks': [
              {'kind': 'p', 'text': 'HotRest is a software-as-a-service (SaaS) platform. Because we deliver digital services rather than physical goods, our refund policy reflects the nature of software subscriptions.'},
            ],
          },
          {
            'heading': '1. Free Plan',
            'blocks': [
              {'kind': 'p', 'text': 'The Free plan is available at no charge and is not eligible for any refund consideration.'},
            ],
          },
          {
            'heading': '2. Paid Subscriptions — 14-Day Trial Period',
            'blocks': [
              {'kind': 'p', 'text': 'New paid subscriptions (Starter and Pro) are eligible for a full refund if requested within 14 days of the initial charge, provided the account has not exceeded reasonable usage limits (defined as fewer than 100 orders processed during the trial period).'},
              {'kind': 'p', 'text': 'To request a refund within the trial period, contact {supportEmail} with your account email and reason for the refund.'},
            ],
          },
          {
            'heading': '3. After the Trial Period',
            'blocks': [
              {'kind': 'p', 'text': 'After the 14-day trial period, subscription fees are non-refundable. You may cancel your subscription at any time, and access will continue until the end of the current billing period.'},
              {'kind': 'bullet', 'text': 'Monthly subscriptions: access continues until the end of the current month.'},
              {'kind': 'bullet', 'text': 'Annual subscriptions: access continues until the end of the paid annual term.'},
              {'kind': 'bullet', 'text': 'No pro-rated refunds are issued for early cancellation of annual plans.'},
            ],
          },
          {
            'heading': '4. Billing Errors',
            'blocks': [
              {'kind': 'p', 'text': 'If you believe you have been charged in error (e.g. duplicate charge or incorrect plan amount), please contact us within 30 days of the charge. We will investigate and, if the error is confirmed, issue a full refund for the incorrect amount within 5–10 business days.'},
            ],
          },
          {
            'heading': '5. Enterprise Plans',
            'blocks': [
              {'kind': 'p', 'text': 'Refund terms for Enterprise plans are governed by the individual agreement signed between HotRest and the customer. Please refer to your contract or contact your account manager.'},
            ],
          },
          {
            'heading': '6. Chargebacks',
            'blocks': [
              {'kind': 'p', 'text': 'If you initiate a chargeback or payment dispute with your bank without first contacting us, we reserve the right to suspend your account until the matter is resolved.'},
            ],
          },
          {
            'heading': '7. How to Request a Refund',
            'blocks': [
              {'kind': 'p', 'text': 'Please email {supportEmail} with:'},
              {'kind': 'bullet', 'text': 'Your registered email address.'},
              {'kind': 'bullet', 'text': 'The invoice number or date of charge.'},
              {'kind': 'bullet', 'text': 'The reason for the refund request.'},
              {'kind': 'p', 'text': 'We aim to respond to all refund requests within 3 business days.'},
            ],
          },
        ],
      },
    },
  ],
};

const Map<String, Object?> kPrivacyDefaults = {
  'schema': 1,
  'seo': {'title': 'Privacy Policy — HotRest'},
  'sections': [
    {
      'id': 'privacy',
      'type': 'legalDoc',
      'layout': {'spaceBefore': 'none'},
      'style': {'reveal': false},
      'content': {
        'title': 'Privacy Policy',
        'updated': 'April 8, 2025',
        'updatedLabel': 'Last updated: {date}',
        'backLabel': 'Back to Home',
        'copyright': '© {year} HotRest. All rights reserved.',
        'footerLinks': [
            {'label': 'Terms of Service', 'link': {'type': 'internal', 'value': '/terms'}},
            {'label': 'Return & Refund Policy', 'link': {'type': 'internal', 'value': '/returns'}},
            {'label': 'Privacy Policy', 'link': {'type': 'internal', 'value': '/privacy'}},
        ],
        'sections': [
          {
            'heading': 'Introduction',
            'blocks': [
              {'kind': 'p', 'text': 'HotRest ("we", "our", "us") is committed to protecting your personal information. This Privacy Policy explains what data we collect, how we use it, and your rights regarding that data.'},
              {'kind': 'p', 'text': 'By using HotRest, you agree to the collection and use of information in accordance with this policy.'},
            ],
          },
          {
            'heading': '1. Information We Collect',
            'blocks': [
              {'kind': 'p', 'text': 'We collect the following categories of information:'},
              {'kind': 'bullet', 'text': 'Account information: name, email address, phone number, and business details provided during registration.'},
              {'kind': 'bullet', 'text': 'Usage data: features used, pages visited, session duration, and interaction logs for improving the platform.'},
              {'kind': 'bullet', 'text': 'Operational data: hotel bookings, guest records, restaurant orders, inventory, and financial reports that you enter into the platform. This data belongs to you.'},
              {'kind': 'bullet', 'text': 'Payment information: processed securely via third-party payment providers. We do not store full card numbers on our servers.'},
              {'kind': 'bullet', 'text': 'Device & technical data: IP address, browser type, and device identifiers for security and analytics purposes.'},
            ],
          },
          {
            'heading': '2. How We Use Your Information',
            'blocks': [
              {'kind': 'p', 'text': 'We use your data to:'},
              {'kind': 'bullet', 'text': 'Provide, operate, and improve the HotRest platform.'},
              {'kind': 'bullet', 'text': 'Process payments and manage billing.'},
              {'kind': 'bullet', 'text': 'Send transactional emails (e.g. invoices, password resets, account notifications).'},
              {'kind': 'bullet', 'text': 'Respond to support requests and enquiries.'},
              {'kind': 'bullet', 'text': 'Detect and prevent fraud or security incidents.'},
              {'kind': 'bullet', 'text': 'Comply with legal obligations.'},
              {'kind': 'p', 'text': 'We do not sell your personal data to third parties and we do not use your operational data (guest records, orders, etc.) for any purpose other than providing the Service to you.'},
            ],
          },
          {
            'heading': '3. Data Storage & Security',
            'blocks': [
              {'kind': 'p', 'text': 'Your data is stored on Supabase-hosted infrastructure with industry-standard encryption at rest and in transit (TLS 1.2+). Access to production data is restricted to authorised personnel only.'},
              {'kind': 'p', 'text': 'While we take all reasonable precautions, no method of transmission over the internet is 100% secure. We cannot guarantee absolute security.'},
            ],
          },
          {
            'heading': '4. Data Retention',
            'blocks': [
              {'kind': 'p', 'text': 'We retain your account data for as long as your account is active. If you close your account, we will delete or anonymise your personal data within 90 days, unless retention is required by law.'},
              {'kind': 'p', 'text': 'Operational data (orders, bookings, etc.) is retained for 7 years to meet standard financial record-keeping requirements, after which it is securely deleted.'},
            ],
          },
          {
            'heading': '5. Third-Party Services',
            'blocks': [
              {'kind': 'p', 'text': 'HotRest uses trusted third-party services that may process your data:'},
              {'kind': 'bullet', 'text': 'Supabase — database and authentication infrastructure.'},
              {'kind': 'bullet', 'text': 'Payhere / payment processors — payment handling.'},
              {'kind': 'bullet', 'text': 'Google Fonts — font delivery (no personal data shared).'},
              {'kind': 'p', 'text': 'Each third-party provider has their own privacy policy. We encourage you to review them.'},
            ],
          },
          {
            'heading': '6. Cookies',
            'blocks': [
              {'kind': 'p', 'text': 'We use essential session cookies to keep you logged in and to maintain application state. We do not use tracking or advertising cookies.'},
            ],
          },
          {
            'heading': '7. Your Rights',
            'blocks': [
              {'kind': 'p', 'text': 'Depending on your jurisdiction, you may have the right to:'},
              {'kind': 'bullet', 'text': 'Access the personal data we hold about you.'},
              {'kind': 'bullet', 'text': 'Request correction of inaccurate data.'},
              {'kind': 'bullet', 'text': 'Request deletion of your personal data ("right to be forgotten").'},
              {'kind': 'bullet', 'text': 'Object to or restrict certain processing activities.'},
              {'kind': 'bullet', 'text': 'Export your data in a portable format.'},
              {'kind': 'p', 'text': 'To exercise any of these rights, please email {supportEmail}. We will respond within 30 days.'},
            ],
          },
          {
            'heading': '8. Children\'s Privacy',
            'blocks': [
              {'kind': 'p', 'text': 'HotRest is not intended for use by individuals under the age of 18. We do not knowingly collect personal data from minors.'},
            ],
          },
          {
            'heading': '9. Changes to This Policy',
            'blocks': [
              {'kind': 'p', 'text': 'We may update this Privacy Policy periodically. When we do, we will revise the "last updated" date at the top of this page and notify you via email for material changes.'},
            ],
          },
          {
            'heading': '10. Contact',
            'blocks': [
              {'kind': 'p', 'text': 'For privacy-related questions or to exercise your rights, please contact our Data Protection team at {supportEmail}.'},
            ],
          },
        ],
      },
    },
  ],
};
