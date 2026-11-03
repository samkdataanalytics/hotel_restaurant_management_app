import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../providers/app_auth_provider.dart';

/// Where a suspended company's members are sent.
const kSuspendedPath = '/suspended';

/// The router rule for suspension, kept apart from the router so it can be tested
/// (the router pulls in screens that do not compile under `flutter test`).
/// A suspended user may only be on [kSuspendedPath]; anyone else is kept off it.
/// Returns the location to redirect to, or null to carry on with the other rules.
String? suspensionRedirect({required bool suspended, required String location}) {
  if (suspended) return location == kSuspendedPath ? null : kSuspendedPath;
  return null;
}

/// Shown instead of the app when the user's company has been suspended.
/// The only action is signing out; the router sends every other route here.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(authProvider).valueOrNull?.organization?.name ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pause_circle_outline_rounded, size: 56, color: Color(0xFFB91C1C)),
                const SizedBox(height: 20),
                const Text('Account suspended',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                Text(
                  company.isEmpty
                      ? 'Your organisation\'s account has been suspended, so it cannot be used right now.'
                      : '$company\'s account has been suspended, so it cannot be used right now.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your data is safe. Please contact support to have access restored.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.brandTeal),
                  onPressed: () => ref.read(authProvider.notifier).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
