import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'di/injection_container.dart';
import 'staff_mobile/app.dart';
import 'staff_mobile/data/local_store.dart';
import 'staff_mobile/session/secure_session_storage.dart';

/// Entry point for the HotRest **staff mobile app**.
///
///   flutter run -t lib/main_mobile.dart \
///     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// Separate from `lib/main.dart`, which stays the web entry point and is not
/// modified by the mobile work. The split is not stylistic: `main.dart` imports
/// `router.dart`, which pulls in the whole `lib/web/` screen tree, and five of
/// those screens (plus `invoice_service`, `menu_doc_service` and
/// `payhere_service`) import `dart:js_interop` / `package:web`. Those are
/// web-only libraries, so a native build that reaches them fails to compile.
/// A `kIsWeb` check does not help — that is a runtime branch, and the compiler
/// has already followed the imports.
///
/// So the rule this file exists to enforce: **nothing reachable from here may
/// import `router.dart`, `lib/web/`, or `lib/mobile/`.** Shared business logic
/// under `services/`, `domain/`, `data/`, `di/` and `providers/` is fair game
/// and is reused rather than rebuilt.
///
/// `lib/mobile/` (the legacy guest self-check-in kiosk) is deliberately left in
/// place and unreachable from this entry point. `lib/main.dart` still boots it
/// on native, so nothing about its current behaviour changes.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // All fonts are bundled in assets/fonts — never fetch at runtime. A kitchen
  // wifi that resolves DNS but stalls on fonts.googleapis.com would otherwise
  // block first paint.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Portrait-first. The kitchen display (a later phase) is the one landscape
  // surface and will opt back in for itself.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  assert(supabaseUrl.isNotEmpty,
      'SUPABASE_URL is not set — pass --dart-define=SUPABASE_URL=...');
  assert(supabaseAnonKey.isNotEmpty,
      'SUPABASE_ANON_KEY is not set — pass --dart-define=SUPABASE_ANON_KEY=...');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    // Shared devices: keep the refresh token in the platform keystore rather
    // than plaintext SharedPreferences. Mobile-only — web keeps the default.
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(),
    ),
  );

  // Same get_it container the web app uses — repositories and use cases are
  // platform-agnostic and are reused unchanged.
  await initDependencies();

  // Offline layer. Opened before runApp so nothing downstream has to cope with
  // a half-initialised store; a failure here is survivable, and the app falls
  // back to online-only rather than refusing to start.
  final localStore = LocalStore();
  try {
    await localStore.init();
  } catch (e) {
    debugPrint('Offline storage unavailable, continuing online-only: $e');
  }

  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(localStore)],
      child: const StaffMobileApp(),
    ),
  );
}
