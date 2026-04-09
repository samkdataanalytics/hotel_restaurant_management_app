import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
import '../providers/app_auth_provider.dart';
import '../router.dart';
import '../services/staff_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final input    = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email/username and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // If the input has no '@' it's a username — look up the synthetic email
    String email = input;
    if (!input.contains('@')) {
      final resolved = await StaffService().getEmailByUsername(input);
      if (resolved == null || resolved.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Username not found. Please check and try again.';
        });
        return;
      }
      email = resolved;
    }

    // Sign in via Riverpod auth notifier — GoRouter redirect handles navigation
    final err = await ref.read(authProvider.notifier).signIn(email, password);

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _isLoading = false;
        _error = null; // clear any old inline error
      });
      _showAuthError(err);
    }
    // On success: GoRouter listens to authProvider and redirects automatically
  }

  void _showAuthError(String message) {
    // Translate Supabase raw messages to friendlier text
    final String friendly;
    final String detail;
    if (message.toLowerCase().contains('invalid login') ||
        message.toLowerCase().contains('invalid credentials') ||
        message.toLowerCase().contains('user not found')) {
      friendly = 'Account not found';
      detail = 'No account matches these credentials.\n'
          'Check your email/username and password, or create a new account.';
    } else if (message.toLowerCase().contains('wrong password') ||
        message.toLowerCase().contains('invalid password')) {
      friendly = 'Incorrect password';
      detail = 'The password you entered is incorrect. Please try again.';
    } else if (message.toLowerCase().contains('email not confirmed')) {
      friendly = 'Email not verified';
      detail = 'Please verify your email address before signing in.';
    } else {
      friendly = 'Sign-in failed';
      detail = message;
    }

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1E293B),
        icon: Icon(Icons.error_outline_rounded,
            color: AppTheme.danger, size: 40),
        title: Text(
          friendly,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Text(
          detail,
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.adminPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(120, 40),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Gradient background shared by both loading and form states
    final bg = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.sidebarDark,
          const Color(0xFF1E293B),
          const Color(0xFF0F172A),
        ],
      ),
    );

    // Full-screen loading state — shown after submit while auth + navigation completes
    if (_isLoading) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: bg,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/hotrest_logo.webp',
                  width: 160,
                  height: 160,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.goldPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Signing in…',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: bg,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 420,
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
                  // Logo
                  Image.asset(
                    'assets/images/hotrest_logo.webp',
                    width: 180,
                    height: 180,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Management Portal',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Email or Username
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Email or Username',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.adminPrimary),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white.withOpacity(0.4),
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.adminPrimary),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),

                  // Validation errors (empty fields) shown inline
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppTheme.danger, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                                color: AppTheme.danger, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Sign up link
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.signup),
                        child: Text(
                          'Create one',
                          style: TextStyle(
                            color: AppTheme.adminPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.adminPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
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
