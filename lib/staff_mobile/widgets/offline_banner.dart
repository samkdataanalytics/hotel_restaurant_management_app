import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/connectivity.dart';

/// Slim bar shown above the content while the device has no network.
///
/// Deliberately non-blocking: this build is online-only, and the honest thing
/// is to tell staff the floor data may be stale rather than to pretend an
/// offline mode exists. Writes are still attempted and surface their real
/// error — see `showWriteBlockedMessage`.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isOnlineProvider)) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 18, color: scheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No connection — this may be out of date',
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains a write that failed while the device is offline.
///
/// Called from a catch block, so the user gets a cause rather than a raw
/// PostgrestException. Returns whether the failure looked connectivity-related.
void showWriteFailure(
  BuildContext context, {
  required Object error,
  required bool isOnline,
  required String action,
}) {
  if (!context.mounted) return;

  final message = isOnline
      ? '$action failed: $error'
      : '$action needs a connection. Nothing was saved — try again once '
          'you are back online.';

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 5),
      ),
    );
}
