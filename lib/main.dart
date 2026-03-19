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
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvaXVtcnF4YnNkYXlxbW1ncGV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MzQzOTgsImV4cCI6MjA4OTQxMDM5OH0.KbK0UupdZf7Gg4ouysySH-DZf1X5vv7T2Vq3CG_G_sA',
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
