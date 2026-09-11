import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/orders_realtime.dart';
import '../../data/table_floor_repository.dart';
import '../../router/staff_router.dart';
import '../../session/staff_session.dart';
import '../../theme/staff_theme.dart';
import '../shell/staff_tabs.dart';

/// The floor board: every table with its live order state.
///
/// Refreshed by the realtime stream on `restaurant_orders` rather than a timer,
/// so firing an order from the web POS updates the phone within a second and an
/// idle board costs nothing.
final _floorProvider =
    FutureProvider.autoDispose<List<TableFloorEntry>>((ref) async {
  // Re-read whenever an order changes for this property. Watching the stream's
  // tick rather than patching rows keeps one source of truth.
  ref.watch(ordersRealtimeProvider);

  // Also rebuild on property switch.
  ref.watch(staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  return ref.watch(tableFloorRepositoryProvider).loadFloor();
});

class TableFloorScreen extends ConsumerStatefulWidget {
  const TableFloorScreen({super.key});

  @override
  ConsumerState<TableFloorScreen> createState() => _TableFloorScreenState();
}

class _TableFloorScreenState extends ConsumerState<TableFloorScreen> {
  Timer? _ageTicker;

  @override
  void initState() {
    super.initState();
    // Order ageing is the one thing that changes with no server event. A
    // 30-second repaint keeps "waiting 12m" honest without re-querying.
    _ageTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ageTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final floorAsync = ref.watch(_floorProvider);
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final mayOrder = session != null && canTakeOrders(session);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(_floorProvider.future),
      child: floorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _FloorError(
          error: e,
          onRetry: () => ref.invalidate(_floorProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) return const _NoTables();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              // Caps at 2 columns on a phone, 3-4 on a tablet, while keeping
              // every card comfortably above the minimum touch target.
              maxCrossAxisExtent: 220,
              mainAxisExtent: 132,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: entries.length,
            itemBuilder: (_, i) => _TableCard(
              entry: entries[i],
              enabled: mayOrder,
              onTap: () => _openTable(entries[i], mayOrder),
            ),
          );
        },
      ),
    );
  }

  void _openTable(TableFloorEntry entry, bool mayOrder) {
    if (!mayOrder) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'You have view-only access to the POS section, so you cannot '
              'take orders.',
            ),
          ),
        );
      return;
    }
    context.push(StaffRoutes.orderEntry(entry.table.id));
  }
}

class _TableCard extends StatelessWidget {
  final TableFloorEntry entry;
  final bool enabled;
  final VoidCallback onTap;

  const _TableCard({
    required this.entry,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accentFor(entry.state);
    final isFree = entry.state == FloorState.free;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Status is carried by a left edge bar as well as colour, so the
            // board stays readable for colour-blind staff.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 5, color: accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.table.tableNumber,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.people_outline_rounded,
                          size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        '${entry.table.capacity}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _labelFor(entry.state),
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!isFree)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.openItemCount} item'
                            '${entry.openItemCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.waitingFor != null)
                          Text(
                            _age(entry.waitingFor!),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              // Past 20 minutes a table is a problem, not a
                              // status — surface it in the warning colour.
                              color: entry.waitingFor!.inMinutes >= 20
                                  ? StaffTheme.tableInKitchen
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    )
                  else
                    Text(
                      enabled ? 'Tap to start an order' : 'Free',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _age(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  static Color _accentFor(FloorState state) => switch (state) {
        FloorState.free => StaffTheme.tableFree,
        FloorState.inKitchen => StaffTheme.tableInKitchen,
        FloorState.seated => StaffTheme.tableSeated,
        FloorState.billDue => StaffTheme.tableBillRequested,
      };

  static String _labelFor(FloorState state) => switch (state) {
        FloorState.free => 'FREE',
        FloorState.inKitchen => 'IN KITCHEN',
        FloorState.seated => 'SEATED',
        FloorState.billDue => 'BILL DUE',
      };
}

class _NoTables extends StatelessWidget {
  const _NoTables();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Must stay scrollable so pull-to-refresh still works on an empty floor.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Icon(Icons.table_restaurant_outlined, size: 56, color: scheme.outline),
        const SizedBox(height: 20),
        Text('No tables yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Tables are set up on the web panel under Restaurant.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _FloorError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _FloorError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Icon(Icons.error_outline_rounded, size: 56, color: scheme.error),
        const SizedBox(height: 20),
        Text('Could not load the floor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text('$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5)),
        ),
        const SizedBox(height: 28),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
