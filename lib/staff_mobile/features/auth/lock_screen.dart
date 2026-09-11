import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/app_lock.dart';
import '../property/property_switcher_sheet.dart';

/// Covers the app when it resumes after being backgrounded past the lock
/// timeout. The session is still valid underneath — this only re-establishes
/// who is holding the device.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _prompting = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Prompt immediately: the user has just deliberately reopened the app, so
    // making them tap "Unlock" first is a wasted step.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  Future<void> _prompt() async {
    if (_prompting) return;
    setState(() {
      _prompting = true;
      _failed = false;
    });

    final ok = await ref.read(appLockProvider.notifier).unlock();

    if (!mounted) return;
    setState(() {
      _prompting = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 64, color: scheme.primary),
              const SizedBox(height: 24),
              Text(
                'Locked',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                _failed
                    ? 'Unlock did not succeed. Try again, or sign out to hand '
                        'the device to someone else.'
                    : 'Confirm it is you to get back to your shift.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _failed ? scheme.error : scheme.onSurfaceVariant,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: _prompting ? null : _prompt,
                icon: _prompting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.fingerprint_rounded),
                label: Text(_prompting ? 'Waiting' : 'Unlock'),
              ),
              const SizedBox(height: 10),
              // Always available: a lock that can strand a signed-in user with
              // a broken sensor is worse than no lock.
              TextButton.icon(
                onPressed: () async {
                  ref.read(appLockProvider.notifier).reset();
                  await confirmSignOut(context);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
