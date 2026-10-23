/// Sign-in and sign-up wording as it shipped. The trial length is a placeholder
/// so the banner can never promise something the database does not grant.
const Map<String, Object?> kAuthDefaults = {
  'schema': 1,
  'sections': [
    {
      'id': 'login',
      'type': 'loginCopy',
      'layout': {'spaceBefore': 'none'},
      'style': {'reveal': false},
      'content': {
        'metaTitle': 'Sign in — HotRest',
        'backLabel': 'Back to site',
        'title': 'Welcome back',
        'subtitle': 'Sign in to your management portal.',
        'identifierLabel': 'Email or username',
        'passwordLabel': 'Password',
        'submitLabel': 'Sign in',
        'footerQuestion': "Don't have an account?",
        'footerAction': 'Create one',
      },
    },
    {
      'id': 'signup',
      'type': 'signupCopy',
      'layout': {'spaceBefore': 'none'},
      'style': {'reveal': false},
      'content': {
        'metaTitle': 'Create your account — HotRest',
        'backLabel': 'Back to site',
        'title': 'Create your account',
        'subtitle': 'Register your company on HotRest.',
        'trialBanner': '{trialDays}-day free trial — full access to every feature. '
            'No credit card required.',
        'emailLabel': 'Work email',
        'passwordLabel': 'Password',
        'passwordHint': 'At least 6 characters.',
        'confirmLabel': 'Confirm password',
        'submitLabel': 'Create account',
        'terms': 'By creating an account you agree to our Terms of Service and '
            'Privacy Policy.',
        'footerQuestion': 'Already have an account?',
        'footerAction': 'Sign in',
        'sentTitle': 'Check your inbox',
        'sentSubtitle': 'One more step to finish setting up.',
        'sentLead': 'We sent a verification link to',
        'sentHelp': 'Click the link in that email to activate your account. '
            'It may take a minute to arrive — check your spam folder too.',
        'sentPrimary': 'Go to sign in',
        'sentSecondary': 'Use a different email',
      },
    },
  ],
};
