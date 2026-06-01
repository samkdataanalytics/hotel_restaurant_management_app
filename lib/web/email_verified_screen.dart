import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../providers/app_auth_provider.dart';
import '../router.dart';

/// Landing page after the user clicks the "Confirm your email" link.
/// Supabase processes the auth code in the URL and fires an onAuthStateChange
/// event. We listen and automatically redirect once the session is ready.
class EmailVerifiedScreen extends ConsumerStatefulWidget {
  const EmailVerifiedScreen({super.key});

  @override
  ConsumerState<EmailVerifiedScreen> createState() => _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends ConsumerState<EmailVerifiedScreen>
    with SingleTickerProviderStateMixin {
  bool _sessionReady = false;

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    // Supabase automatically exchanges the code in the URL for a session.
    // Listen for SIGNED_IN so we can reflect the ready state in the UI.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        // Reload the Riverpod auth state so GoRouter can redirect if needed.
        ref.read(authProvider.notifier).reload();
        setState(() => _sessionReady = true);
      }
    });

    // Also handle the case where the session was already established
    // before this widget mounted (e.g. fast redirect).
    if (Supabase.instance.client.auth.currentSession != null) {
      _sessionReady = true;
      ref.read(authProvider.notifier).reload();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.sidebarDark,
              const Color(0xFF1E293B),
              const Color(0xFF0F172A),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 440,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated checkmark circle
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) => Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.success.withOpacity(0.5), width: 2),
                      ),
                      child: Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 44),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Email Verified!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your email address has been confirmed.\nYou can now sign in to your HotRest account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 36),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_sessionReady) {
                          // Session exists — GoRouter will redirect to onboarding/dashboard
                          context.go(AppRoutes.appDashboard);
                        } else {
                          context.go(AppRoutes.login);
                        }
                      },
                      icon: Icon(
                        _sessionReady
                            ? Icons.dashboard_rounded
                            : Icons.login_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _sessionReady ? 'Go to Dashboard' : 'Sign In',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
