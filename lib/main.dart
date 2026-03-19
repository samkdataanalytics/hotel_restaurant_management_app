import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mobile/mobile_app.dart';
import 'web/admin_app.dart';
import 'providers/hotel_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://voiumrqxbsdayqmmgpew.supabase.co',
    anonKey: 'REMOVED_ANON_KEY',
  );

  // Restore any existing Supabase session (web: from localStorage)
  final session = HotelSession();
  if (kIsWeb) await session.restoreSession();

  runApp(
    ChangeNotifierProvider<HotelSession>.value(
      value: session,
      child: kIsWeb ? const AdminApp() : const MobileApp(),
    ),
  );
}
