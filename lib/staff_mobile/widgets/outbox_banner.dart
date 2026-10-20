import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';
import '../data/outbox.dart';

/// Shows what is still waiting to reach the server.
///
/// Visible on purpose. A waiter who fired a round offline has already told the
/// kitchen it is in; the one thing the app must never do is leave them assuming
/// it synced when it did not.
class OutboxBanner extends ConsumerWidget {
  const OutboxBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outbox = ref.watch(outboxProvider);
    if (outbox.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final blocked = outbox.blockedCount;
    final pending = outbox.pendingCount;

    // Blocked entries are a problem needing a decision; merely pending ones are
    // normal and just need reporting.
    final isProblem = blocked > 0;
    final background =
        isProblem ? scheme.errorContainer : scheme.tertiaryContainer;
    final foreground =
        isProblem ? scheme.onErrorContainer : scheme.onTertiaryContainer;

    return Material(
      color: background,
      child: InkWell(
        onTap: () => _showQueue(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (outbox.draining)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: foreground),
                )
              else
                Icon(
                  isProblem
                      ? Icons.error_outline_rounded
                      : Icons.cloud_upload_outlined,
                  size: 17,
                  color: foreground,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isProblem
                      ? '$blocked order${blocked == 1 ? '' : 's'} could not be '
                          'sent — tap to review'
                      : outbox.draining
                          ? 'Sending $pending saved order'
                              '${pending == 1 ? '' : 's'}…'
                          : '$pending order${pending == 1 ? '' : 's'} waiting '
                              'to send',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _QueueSheet(),
    );
  }
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outbox = ref.watch(outboxProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('Waiting to send',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(height: 1),
            Flexible(
              child: outbox.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Everything has been sent.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: outbox.entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) =>
                          _QueueRow(entry: outbox.entries[i]),
                    ),
            ),
            if (outbox.blockedCount > 0) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: FilledButton.icon(
                  onPressed: () =>
                      ref.read(outboxProvider.notifier).retryBlocked(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('Retry ${outbox.blockedCount} failed'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends ConsumerWidget {
  final OutboxEntry entry;
  const _QueueRow({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final itemCount = switch (entry.kind) {
      OutboxKind.createOrder =>
        ((entry.payload['order'] as Map?)?['items'] as List?)?.length ?? 0,
      OutboxKind.addItems => (entry.payload['items'] as List?)?.length ?? 0,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.kind == OutboxKind.createOrder
                      ? 'New order · $itemCount item'
                          '${itemCount == 1 ? '' : 's'}'
                      : 'Extra items · $itemCount item'
                          '${itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Taken ${_ago(DateTime.now().difference(entry.queuedAt))}',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
                if (entry.isBlocked) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Failed ${entry.attempts} times'
                    '${entry.lastError == null ? '' : ': ${entry.lastError}'}',
                    style: TextStyle(fontSize: 12, color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
          // Discarding is only offered once automatic retries have given up,
          // so a queued order can never be thrown away by a stray tap.
          if (entry.isBlocked)
            IconButton(
              tooltip: 'Discard this order',
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              onPressed: () => _confirmDiscard(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this order?'),
        content: const Text(
          'It has not reached the kitchen and cannot be recovered. Only do '
          'this if the order was already entered another way.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(outboxProvider.notifier).discard(entry.id);
    }
  }

  static String _ago(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
