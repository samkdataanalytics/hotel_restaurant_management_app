import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../providers/app_auth_provider.dart';
import '../router.dart';
import '../services/staff_service.dart';

class AcceptInviteScreen extends ConsumerStatefulWidget {
  final String token;
  const AcceptInviteScreen({super.key, required this.token});

  @override
  ConsumerState<AcceptInviteScreen> createState() =>
      _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen>
    with SingleTickerProviderStateMixin {
  final _staffService = StaffService();

  // Invite preview
  Map<String, dynamic>? _preview;
  bool _loadingPreview = true;
  String? _previewError;

  // Tab: 0 = Sign Up, 1 = Log In
  late final TabController _tabCtrl;

  // Form fields
  final _signupFormKey = GlobalKey<FormState>();
  final _loginFormKey  = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl  = TextEditingController();

  bool _submitting = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadPreview();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    try {
      final preview = await _staffService.getInvitePreview(widget.token);
      if (!mounted) return;
      if (preview == null) {
        setState(() {
          _previewError = 'This invite link is invalid.';
          _loadingPreview = false;
        });
        return;
      }
      if (preview['expired'] == true || preview['status'] != 'pending') {
        setState(() {
          _previewError = preview['status'] == 'accepted'
              ? 'This invite has already been used.'
              : 'This invite link has expired.';
          _loadingPreview = false;
        });
        return;
      }
      final invitedEmail = preview['invited_email'] as String? ?? '';
      setState(() {
        _preview = preview;
        _loadingPreview = false;
        // Pre-fill email fields from the invite
        _emailCtrl.text = invitedEmail;
        _loginEmailCtrl.text = invitedEmail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewError = 'Could not load invite: $e';
        _loadingPreview = false;
      });
    }
  }

  // ── Sign up as new user then accept ───────────────────────────────────────

  Future<void> _signUp() async {
    if (!_signupFormKey.currentState!.validate()) return;
    setState(() { _submitting = true; _authError = null; });
    try {
      final db = Supabase.instance.client;

      // 1. Create Supabase auth account
      final res = await db.auth.signUp(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text,
        data:     {'full_name': _nameCtrl.text.trim()},
      );

      if (res.user == null) {
        throw Exception('Sign up failed. Please try again.');
      }

      // 2. Update profile name
      await db.from('profiles').upsert({
        'id':        res.user!.id,
        'full_name': _nameCtrl.text.trim(),
        'email':     _emailCtrl.text.trim().toLowerCase(),
      }, onConflict: 'id').onError((_, __) => []);

      // 3. Accept the invite
      await _staffService.acceptInvite(widget.token);

      // 4. Reload auth state so router detects org + property
      await ref.read(authProvider.notifier).reload();

      if (!mounted) return;
      context.go(AppRoutes.app);
    } on AuthException catch (e) {
      setState(() { _submitting = false; _authError = e.message; });
    } catch (e) {
      setState(() { _submitting = false; _authError = e.toString(); });
    }
  }

  // ── Log in as existing user then accept ───────────────────────────────────

  Future<void> _logIn() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() { _submitting = true; _authError = null; });
    try {
      // 1. Sign in
      final err = await ref.read(authProvider.notifier).signIn(
        _loginEmailCtrl.text.trim(),
        _loginPassCtrl.text,
      );
      if (err != null) throw Exception(err);

      // 2. Accept the invite
      await _staffService.acceptInvite(widget.token);

      // 3. Reload so auth state includes the new org + property
      await ref.read(authProvider.notifier).reload();

      if (!mounted) return;
      context.go(AppRoutes.app);
    } catch (e) {
      setState(() { _submitting = false; _authError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / brand
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFD4A853), Color(0xFFE8C97A)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.hotel_rounded,
                      color: Color(0xFF0F172A), size: 28),
                ),
                const SizedBox(height: 24),

                if (_loadingPreview)
                  const CircularProgressIndicator()
                else if (_previewError != null)
                  _ErrorCard(message: _previewError!)
                else
                  _buildInviteCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCard() {
    final propertyName =
        _preview?['property_name'] as String? ?? 'a property';

    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Invite header
            Column(
              children: [
                const Icon(Icons.people_alt_rounded,
                    size: 36, color: Color(0xFF818CF8)),
                const SizedBox(height: 12),
                Text(
                  "You're invited!",
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black54),
                    children: [
                      const TextSpan(text: 'Join '),
                      TextSpan(
                        text: propertyName,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.adminPrimary),
                      ),
                      const TextSpan(
                          text: ' as a team member.'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 4)
                  ],
                ),
                labelColor: AppTheme.adminPrimary,
                unselectedLabelColor: Colors.black45,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Create Account'),
                  Tab(text: 'I have an account'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 320,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildSignUpForm(),
                  _buildLoginForm(),
                ],
              ),
            ),

            if (_authError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _authError!,
                  style:
                      TextStyle(color: AppTheme.danger, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _signupFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: _inputDeco('Full name', Icons.person_outline),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter your name' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDeco('Email', Icons.email_outlined),
            validator: (v) =>
                v == null || !v.contains('@') ? 'Valid email required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passCtrl,
            obscureText: true,
            decoration: _inputDeco('Password', Icons.lock_outline),
            validator: (v) => v == null || v.length < 6
                ? 'At least 6 characters'
                : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _signUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.adminPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create Account & Join',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _loginEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDeco('Email', Icons.email_outlined),
            validator: (v) =>
                v == null || !v.contains('@') ? 'Valid email required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _loginPassCtrl,
            obscureText: true,
            decoration: _inputDeco('Password', Icons.lock_outline),
            validator: (v) =>
                v == null || v.isEmpty ? 'Password required' : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _logIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.adminPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Log In & Join',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

// ─── Error card ───────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.link_off_rounded,
                size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            Text(
              message,
              style:
                  const TextStyle(fontSize: 15, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
