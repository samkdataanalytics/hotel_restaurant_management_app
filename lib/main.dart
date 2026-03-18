import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mobile/mobile_app.dart';
import 'web/admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://voiumrqxbsdayqmmgpew.supabase.co',
    anonKey: 'REMOVED_ANON_KEY',
  );

  runApp(
    kIsWeb ? const AdminApp() : const MobileApp(),
  );
}
