import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/menu_item.dart';
import '../../data/connectivity.dart';
import '../../data/restaurant_repository.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';
import '../../data/money.dart';
import '../../data/table_realtime.dart';

final _fullMenuProvider =
    FutureProvider.autoDispose<Map<String, List<MenuItem>>>((ref) async {
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  // A toggle made on the web panel, or by another manager, lands here.
  ref.watch(tableRealtimeProvider('menu_items'));
  return ref.watch(restaurantRepositoryProvider).loadFullMenuByCategory();
});

/// Mark a dish sold out, or put it back on.
///
/// One tap from the floor, reflected on the guest QR menu and every other
/// device immediately. Small feature, disproportionate daily value: the
/// alternative is a waiter taking an order for something the kitchen ran out
/// of twenty minutes ago.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  final _busy = <String>{};
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_fullMenuProvider);
    final session = ref.watch(staffSessionProvider).valueOrNull;

    // Availability is menu data, so it is gated on the restaurant management
    // section rather than POS — a waiter taking orders is not necessarily
    // trusted to change the menu.
    final mayEdit = session?.canEdit('restaurant_management') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Sold out')),
      body: Column(
        children: [
          const OfflineBanner(),
          if (!mayEdit)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'View only — ask a manager to change what is available.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search the menu',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Could not load the menu.\n\n$e',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (menu) {
                final items = _visible(menu);
                if (items.isEmpty) {
                  return const Center(child: Text('Nothing matches.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(_fullMenuProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ItemRow(
                      item: items[i],
                      busy: _busy.contains(items[i].id),
                      enabled: mayEdit,
                      onToggle: () => _toggle(items[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<MenuItem> _visible(Map<String, List<MenuItem>> menu) {
    final all = [for (final items in menu.values) ...items];
    final q = _search.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all.where((i) => i.name.toLowerCase().contains(q)).toList();
    // Sold-out items float to the top: they are what someone came here to fix.
    filtered.sort((a, b) {
      if (a.isAvailable != b.isAvailable) return a.isAvailable ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  Future<void> _toggle(MenuItem item) async {
    if (_busy.contains(item.id)) return;
    setState(() => _busy.add(item.id));
    final isOnline = ref.read(isOnlineProvider);

    try {
      await ref
          .read(restaurantRepositoryProvider)
          .setItemAvailability(item, !item.isAvailable);
      if (!mounted) return;
      setState(() => _busy.remove(item.id));
      ref.invalidate(_fullMenuProvider);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(item.isAvailable
                ? '${item.name} marked sold out'
                : '${item.name} is back on'),
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(item.id));
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Updating ${item.name}',
      );
    }
  }
}

class _ItemRow extends ConsumerWidget {
  final MenuItem item;
  final bool busy;
  final bool enabled;
  final VoidCallback onToggle;

  const _ItemRow({
    required this.item,
    required this.busy,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyProvider);
    final scheme = Theme.of(context).colorScheme;
    final soldOut = !item.isAvailable;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled && !busy ? onToggle : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        decoration: soldOut ? TextDecoration.lineThrough : null,
                        color:
                            soldOut ? scheme.onSurfaceVariant : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.category} · ${money.format(item.price)}',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Switch(
                  value: item.isAvailable,
                  onChanged: enabled ? (_) => onToggle() : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
