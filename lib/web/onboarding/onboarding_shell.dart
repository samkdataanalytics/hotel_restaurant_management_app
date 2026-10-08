import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../providers/app_auth_provider.dart';
import 'step1_company_details.dart';

// ─── Shared onboarding UI helpers ─────────────────────────────────────────────

Widget buildOnboardingBrandHeader() {
  return Column(
    children: [
      Image.asset(
        'assets/images/hotrest_logo_light.png',
        width: 210,
        height: 67,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: 8),
      const Text(
        'Welcome to HotRest',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
      ),
      const SizedBox(height: 6),
      Text(
        'Set up your organization in just 2 steps',
        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
      ),
    ],
  );
}

Widget buildOnboardingStepIndicator({required int activeStep}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _StepDot(stepNumber: 1, label: 'Company', isActive: activeStep == 0, isCompleted: activeStep > 0),
      _StepConnector(isCompleted: activeStep > 0),
      _StepDot(stepNumber: 2, label: 'Profile',  isActive: activeStep == 1, isCompleted: false),
    ],
  );
}

Widget buildOnboardingFormCard({required Widget child, bool isSubmitting = false, String submittingLabel = 'Setting up...'}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 12))],
    ),
    padding: const EdgeInsets.all(40),
    child: Stack(
      children: [
        child,
        if (isSubmitting)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(submittingLabel, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Step 1 of onboarding — Company Details.
/// Pushes a dummy browser history entry on mount so the browser back button
/// can be intercepted; back → sign out → login.
class OnboardingShell extends ConsumerStatefulWidget {
  const OnboardingShell({super.key});

  @override
  ConsumerState<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends ConsumerState<OnboardingShell> {
  web.EventListener? _popListener;

  @override
  void initState() {
    super.initState();
    // Push a sentinel entry so the browser has something to "go back from".
    web.window.history.pushState(
      {'sentinel': 'onboarding'}.jsify(),
      '',
      web.window.location.href,
    );

    // When the browser fires popstate (back pressed), sign out and go to login.
    // Must be non-async — .toJS only accepts void-returning functions.
    _popListener = (web.Event _) {
      if (!mounted) return;
      ref.read(authProvider.notifier).signOut().then((_) {
        if (mounted) context.go('/login');
      });
    }.toJS;
    web.window.addEventListener('popstate', _popListener);
  }

  @override
  void dispose() {
    web.window.removeEventListener('popstate', _popListener);
    super.dispose();
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
                  buildOnboardingStepIndicator(activeStep: 0),
                  const SizedBox(height: 24),
                  buildOnboardingFormCard(
                    child: Step1CompanyDetails(
                      onNext: (data) {
                        ref.read(onboardingStep1DataProvider.notifier).state = data;
                        context.push('/onboarding/profile');
                      },
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
            ? AppTheme.brandOnDark
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
