import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'welcome_screen.dart';
import 'booking_lookup_screen.dart';
import 'guest_details_screen.dart';
import 'checkin_confirm_screen.dart';
import 'checkin_success_screen.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hotel Check-In',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.mobileTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/lookup': (context) => const BookingLookupScreen(),
        '/guest-details': (context) => const GuestDetailsScreen(),
        '/confirm': (context) => const CheckinConfirmScreen(),
        '/success': (context) => const CheckinSuccessScreen(),
      },
    );
  }
}
