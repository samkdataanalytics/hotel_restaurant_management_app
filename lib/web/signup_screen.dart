import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../providers/app_auth_provider.dart';
import '../router.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool _obscurePassword  = true;
  bool _obscureConfirm   = true;
  bool _isLoading        = false;
  bool _emailSent        = false;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

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
    _confirmController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm  = _confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error     = null;
    });

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email:    email,
        password: password,
      );

      if (!mounted) return;

      if (res.user == null) {
        setState(() {
          _isLoading = false;
          _error     = 'Sign up failed. Please try again.';
        });
        return;
      }

      // If session is returned immediately (email confirmation disabled),
      // load the auth context and let GoRouter redirect.
      if (res.session != null) {
        await ref.read(authProvider.notifier).reload();
        // GoRouter redirect will take over
        return;
      }

      // Email confirmation required — show success message.
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _error     = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error     = 'Unexpected error: $e';
      });
    }
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
              child: _emailSent ? _buildEmailSentState() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Image.asset(
          'assets/images/hotrest_logo.png',
          width: 140,
          height: 140,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 24),

        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Register your company on HotRest',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
        ),
        const SizedBox(height: 32),

        // Email
        _darkField(
          controller: _emailController,
          hint: 'Work email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        // Password
        _darkField(
          controller: _passwordController,
          hint: 'Password',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 14),

        // Confirm password
        _darkField(
          controller: _confirmController,
          hint: 'Confirm password',
          icon: Icons.lock_outline,
          obscure: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          onSubmitted: (_) => _signup(),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppTheme.danger, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Sign up button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.adminPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Back to login
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
            GestureDetector(
              onTap: () => context.go(AppRoutes.login),
              child: Text(
                'Sign in',
                style: TextStyle(
                  color: AppTheme.adminPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmailSentState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.success.withOpacity(0.4)),
          ),
          child: Icon(Icons.mark_email_read_rounded, color: AppTheme.success, size: 36),
        ),
        const SizedBox(height: 24),
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a confirmation link to\n${_emailController.text.trim()}\n\nClick the link to verify your account, then come back to sign in.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => context.go(AppRoutes.login),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.adminPrimary),
        ),
      ),
    );
  }
}
