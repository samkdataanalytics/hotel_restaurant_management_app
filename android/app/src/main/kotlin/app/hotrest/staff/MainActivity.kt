package app.hotrest.staff

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: local_auth's Android
// implementation shows the biometric prompt via AndroidX BiometricPrompt, which
// requires a FragmentActivity host. With the plain FlutterActivity the prompt
// throws at runtime ("no_fragment_activity").
//
// It is a drop-in replacement and changes nothing for the legacy guest kiosk
// that lib/main.dart still boots on this same activity.
class MainActivity : FlutterFragmentActivity()
