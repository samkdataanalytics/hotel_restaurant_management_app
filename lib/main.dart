import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/database_service.dart';
import 'mobile/mobile_app.dart';
import 'web/admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database with seed data
  final db = DatabaseService();
  await db.initialize();

  runApp(
    kIsWeb ? const AdminApp() : const MobileApp(),
  );
}
