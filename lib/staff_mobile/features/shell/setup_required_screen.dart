import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/staff_session.dart';
import '../property/property_switcher_sheet.dart';

/// Shown when the account is valid but the staff app cannot proceed:
/// no organisation, no property, an expired trial, or a superadmin.
///
/// The mobile app deliberately does not reimplement onboarding, billing or the
/// superadmin panel. Those are configuration tasks done sitting down, they are
/// already built and working on the web, and porting them would multiply the
/// surface area that has to stay in sync for no operational gain.
class SetupRequiredScreen extends ConsumerWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.open_in_browser_rounded,
                  size: 64, color: scheme.primary),
              const SizedBox(height: 24),
              Text(
                'One more step on the web',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                session?.blockerReason ??
                    'Your account is not ready for the staff app yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                  fontSize: 15.5,
                ),
              ),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: () => ref.invalidate(staffSessionProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Check again'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
