import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';
import '../../providers/app_auth_provider.dart';
import '../../services/organization_service.dart';
import 'step1_company_details.dart';
import 'step2_admin_profile.dart';

class OnboardingShell extends ConsumerStatefulWidget {
  const OnboardingShell({super.key});

  @override
  ConsumerState<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends ConsumerState<OnboardingShell> {
  int _currentStep = 0;
  Map<String, String> _organizationData = {};
  bool _isSubmitting = false;

  void _onStep1Complete(Map<String, String> data) {
    setState(() {
      _organizationData = data;
      _currentStep = 1;
    });
  }

  Future<void> _onStep2Complete(Map<String, String> profileData) async {
    setState(() => _isSubmitting = true);

    try {
      // 1. Create the organization
      await OrganizationService().createOrganization(
        name:    _organizationData['name']    ?? '',
        slug:    _organizationData['slug']    ?? '',
        country: _organizationData['country'] ?? '',
        phone:   _organizationData['phone']   ?? '',
      );

      // 2. Update profile in Supabase
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id':         userId,
          'full_name':  profileData['fullName']  ?? '',
          'job_title':  profileData['jobTitle']  ?? '',
          'phone':      profileData['phone']      ?? '',
        });
      }

      // 3. Refresh auth state so the app knows the org now exists
      await ref.read(authProvider.notifier).refreshAfterOnboarding();

      if (!mounted) return;

      // 4. Navigate to property setup
      context.go('/property-setup');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Setup failed: ${e.toString()}'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.sidebarDark,
              AppTheme.sidebarBg,
              const Color(0xFF1E3A5F),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / brand header
                  _buildBrandHeader(),
                  const SizedBox(height: 32),

                  // Step indicator
                  _buildStepIndicator(),
                  const SizedBox(height: 24),

                  // Form card
                  _buildFormCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD4A853), Color(0xFFE8C97A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.goldPrimary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.hotel_rounded, color: Color(0xFF0F172A), size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Welcome to HotRest',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Set up your organization in just 2 steps',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepDot(
          stepNumber: 1,
          label: 'Company',
          isActive: _currentStep == 0,
          isCompleted: _currentStep > 0,
        ),
        _StepConnector(isCompleted: _currentStep > 0),
        _StepDot(
          stepNumber: 2,
          label: 'Profile',
          isActive: _currentStep == 1,
          isCompleted: false,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(40),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _currentStep == 0
                ? Step1CompanyDetails(
                    key: const ValueKey('step1'),
                    onNext: _onStep1Complete,
                  )
                : Step2AdminProfile(
                    key: const ValueKey('step2'),
                    onComplete: _onStep2Complete,
                    onBack: () => setState(() => _currentStep = 0),
                  ),
          ),
          if (_isSubmitting)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Setting up your organization...',
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Step indicator widgets ───────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _StepDot({
    required this.stepNumber,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor = isCompleted
        ? AppTheme.success
        : isActive
            ? AppTheme.adminPrimary
            : Colors.white.withOpacity(0.3);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: isActive && !isCompleted
                ? Border.all(color: Colors.white, width: 2)
                : null,
            boxShadow: isActive || isCompleted
                ? [BoxShadow(color: dotColor.withOpacity(0.4), blurRadius: 10)]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    '$stepNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool isCompleted;
  const _StepConnector({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isCompleted ? AppTheme.success : Colors.white.withOpacity(0.2),
      ),
    );
  }
}
