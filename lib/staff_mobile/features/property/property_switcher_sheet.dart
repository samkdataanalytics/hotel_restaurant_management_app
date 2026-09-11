import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_auth_provider.dart';
import '../../session/staff_session.dart';

/// Bottom sheet listing the properties this user is attached to.
///
/// Selecting one re-scopes every tenant-aware singleton through
/// `StaffSession.switchProperty`, which is the mobile side of the same
/// `applyPropertyScope` the web shell uses.
Future<void> showPropertySwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _PropertySwitcherSheet(),
  );
}

class _PropertySwitcherSheet extends ConsumerWidget {
  const _PropertySwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(staffSessionProvider).valueOrNull;
    if (session == null) return const SizedBox.shrink();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text('Switch property',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: RadioGroup<String>(
                groupValue: session.activeProperty?.id,
                onChanged: (id) async {
                  if (id == null) return;
                  final property =
                      session.properties.firstWhere((p) => p.id == id);
                  Navigator.of(context).pop();
                  await ref
                      .read(staffSessionProvider.notifier)
                      .switchProperty(property);
                },
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final property in session.properties)
                      RadioListTile<String>(
                        value: property.id,
                        title: Text(property.name),
                        subtitle:
                            property.city.isEmpty ? null : Text(property.city),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Confirms before ending the session.
///
/// Worth a confirmation step on a shared device: an accidental sign-out mid
/// service means re-entering credentials with a table waiting.
Future<void> confirmSignOut(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'You will need your username and password to sign back in.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // Read through the container rather than a captured ref: the dialog's context
  // is gone by now, and the router will unmount this subtree as soon as auth
  // flips to signed-out.
  await container.read(authProvider.notifier).signOut();
}
