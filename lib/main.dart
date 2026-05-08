import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'url_strategy_stub.dart'
    if (dart.library.html) 'url_strategy_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider, Provider;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'di/injection_container.dart';
import 'mobile/mobile_app.dart';
import 'providers/hotel_session.dart';
import 'router.dart';
import 'app_theme.dart';

void main() async {
  configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // All fonts are bundled locally — disable GoogleFonts HTTP fetching entirely.
  GoogleFonts.config.allowRuntimeFetching = false;

  await Supabase.initialize(
    url: 'https://voiumrqxbsdayqmmgpew.supabase.co',
    anonKey: 'REMOVED_ANON_KEY',
  );
  await initDependencies();

  // Legacy HotelSession (still used by existing hotel screens)
  // restoreSession() is intentionally skipped here — AppShell._initialize()
  // calls setHotelId() which loads hotel_settings as part of its own flow,
  // avoiding a duplicate pair of DB round-trips at startup.
  final session = HotelSession();

  runApp(
    ProviderScope(
      child: kIsWeb
          ? ChangeNotifierProvider<HotelSession>.value(
              value: session,
              child: const _WebApp(),
            )
          : ChangeNotifierProvider<HotelSession>.value(
              value: session,
              child: const MobileApp(),
            ),
    ),
  );
}

class _WebApp extends ConsumerWidget {
  const _WebApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (ctx) {
        final name = Provider.of<HotelSession>(ctx, listen: false)
            .settings
            ?.displayName;
        return (name != null && name.isNotEmpty) ? name : 'HotRest';
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.webTheme,
      routerConfig: router,
    );
  }
}
