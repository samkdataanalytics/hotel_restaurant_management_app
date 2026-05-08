import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';
import '../../providers/app_auth_provider.dart';
import '../../services/organization_service.dart';
import 'onboarding_shell.dart' show buildOnboardingBrandHeader, buildOnboardingStepIndicator, buildOnboardingFormCard;
import 'step2_admin_profile.dart';

/// Step 2 of onboarding — Admin Profile.
/// Lives at /onboarding/profile so the browser back button returns to /onboarding.
class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  ConsumerState<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends ConsumerState<OnboardingProfileScreen> {
  bool _isSubmitting = false;

  Future<void> _onComplete(Map<String, String> profileData) async {
    setState(() => _isSubmitting = true);

    final orgData = ref.read(onboardingStep1DataProvider);

    try {
      // 1. Create org (skip if already exists from a previous attempt)
      final existing = await OrganizationService().getMyOrganization();
      if (existing == null) {
        await OrganizationService().createOrganization(
          name:    orgData['name']    ?? '',
          slug:    orgData['slug']    ?? '',
          country: orgData['country'] ?? '',
          phone:   orgData['phone']   ?? '',
        );
      }

      // 2. Save profile via SECURITY DEFINER RPC to avoid RLS upsert conflicts
      await Supabase.instance.client.rpc('upsert_my_profile', params: {
        'p_full_name': profileData['fullName'] ?? '',
        'p_job_title': profileData['jobTitle'] ?? '',
        'p_phone':     profileData['phone']    ?? '',
      });

      // 3. Refresh auth state
      await ref.read(authProvider.notifier).refreshAfterOnboarding();

      if (!mounted) return;
      // Clear step 1 data
      ref.read(onboardingStep1DataProvider.notifier).state = {};
      context.go('/property-setup');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final isDuplicate = msg.contains('duplicate') ||
          msg.contains('unique') ||
          msg.contains('already exists') ||
          msg.contains('23505');
      if (isDuplicate) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 40),
            title: const Text('Organization already exists',
                textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text(
              'An organization with this name or slug already exists.\n'
              'Try a different company name, or sign in to your existing account.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.adminPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(120, 40),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
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
            colors: [AppTheme.sidebarDark, AppTheme.sidebarBg, const Color(0xFF1E3A5F)],
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
                  buildOnboardingBrandHeader(),
                  const SizedBox(height: 32),
                  buildOnboardingStepIndicator(activeStep: 1),
                  const SizedBox(height: 24),
                  buildOnboardingFormCard(
                    isSubmitting: _isSubmitting,
                    submittingLabel: 'Setting up your organization...',
                    child: Step2AdminProfile(
                      onComplete: _onComplete,
                      onBack: () => context.pop(),
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
