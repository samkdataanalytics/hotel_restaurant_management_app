import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider, Provider;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mobile/mobile_app.dart';
import 'providers/hotel_session.dart';
import 'router.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://voiumrqxbsdayqmmgpew.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvaXVtcnF4YnNkYXlxbW1ncGV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MzQzOTgsImV4cCI6MjA4OTQxMDM5OH0.KbK0UupdZf7Gg4ouysySH-DZf1X5vv7T2Vq3CG_G_sA',
  );

  // Legacy HotelSession (still used by existing hotel screens)
  final session = HotelSession();
  if (kIsWeb) await session.restoreSession();

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
        return (name != null && name.isNotEmpty) ? name : 'Hotel Management';
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.webTheme,
      routerConfig: router,
    );
  }
}
