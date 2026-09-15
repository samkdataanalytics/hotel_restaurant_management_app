import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/front_desk_repository.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';

final _folioProvider = FutureProvider.autoDispose
    .family<GuestFolio, ArrivalEntry>((ref, stay) async {
  return ref.watch(frontDeskRepositoryProvider).loadFolio(stay);
});

/// Check out and settle the folio.
///
/// Shows everything the guest owes in one place — the room, anything billed
/// from the restaurant, and room-linked expenses — before releasing the room.
///
/// The invoice PDF is not generated here. `invoice_service.dart` imports
/// `dart:js_interop` and `package:web`, so it cannot compile for native at all;
/// producing a PDF on mobile needs that service split along a platform seam
/// first. Until then the folio is shown on screen and the invoice is issued
/// from the web panel.
class CheckOutScreen extends ConsumerStatefulWidget {
  final ArrivalEntry stay;
  const CheckOutScreen({super.key, required this.stay});

  @override
  ConsumerState<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends ConsumerState<CheckOutScreen> {
  bool _checkingOut = false;

  static final _dayFormat = DateFormat('EEE d MMM');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_folioProvider(widget.stay));
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final mayCheckOut = session?.canEdit('hotel_checkins') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Check out'),
            Text(
              '${widget.stay.guestName} · room ${widget.stay.roomLabel}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Could not load the folio.\n\n$e',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Checking out without it could release the room with '
                        'charges unpaid.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(_folioProvider(widget.stay)),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (folio) => _folioView(folio),
            ),
          ),
        ],
      ),
      bottomNavigationBar: async.hasValue
          ? _CheckOutBar(
              folio: async.requireValue,
              busy: _checkingOut,
              enabled: mayCheckOut,
              onCheckOut: () => _checkOut(async.requireValue),
            )
          : null,
    );
  }

  Widget _folioView(GuestFolio folio) {
    final scheme = Theme.of(context).colorScheme;
    final booking = folio.stay.booking;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.bookingRef,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${_dayFormat.format(booking.checkInDate)} → '
                  '${_dayFormat.format(booking.checkOutDate)}  ·  '
                  '${folio.stay.nights} night'
                  '${folio.stay.nights == 1 ? '' : 's'}',
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _Section(
          title: 'Room',
          rows: [(label: '${folio.stay.nights} night stay', amount: folio.roomCharge)],
        ),

        if (folio.restaurantOrders.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Restaurant',
            rows: [
              for (final order in folio.restaurantOrders)
                (
                  label: 'Order #${order.orderNumber}',
                  amount: order.totalAmount,
                ),
            ],
          ),
        ],

        if (folio.expenses.where((e) => e.isBillable).isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Extras',
            rows: [
              for (final expense in folio.expenses.where((e) => e.isBillable))
                (label: expense.description, amount: expense.amount),
            ],
          ),
        ],

        const SizedBox(height: 18),
        Card(
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text('Total due',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSecondaryContainer,
                      )),
                ),
                Text(folio.total.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSecondaryContainer,
                    )),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 17, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'The invoice PDF is issued from the web panel. Checking out '
                'here releases the room and closes the booking.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _checkOut(GuestFolio folio) async {
    if (_checkingOut) return;

    // Checking out releases the room and closes the booking, and there is no
    // undo in the service. Worth one confirmation, with the balance on it.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check out?'),
        content: Text(
          '${folio.stay.guestName} owes ${folio.total.toStringAsFixed(2)}.\n\n'
          'Room ${folio.stay.roomLabel} will be released and the booking '
          'closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Check out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _checkingOut = true);
    final isOnline = ref.read(isOnlineProvider);

    try {
      await ref
          .read(bookingServiceProvider)
          .performCheckOut(folio.stay.booking.id);
      if (!mounted) return;
      setState(() => _checkingOut = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${folio.stay.guestName} checked out — room '
              '${folio.stay.roomLabel} is free',
            ),
          ),
        );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingOut = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Checking ${folio.stay.guestName} out',
      );
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<({String label, double amount})> rows;

  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: scheme.onSurfaceVariant,
                )),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(row.label,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    Text(row.amount.toStringAsFixed(2),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckOutBar extends StatelessWidget {
  final GuestFolio folio;
  final bool busy;
  final bool enabled;
  final VoidCallback onCheckOut;

  const _CheckOutBar({
    required this.folio,
    required this.busy,
    required this.enabled,
    required this.onCheckOut,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: (!enabled || busy) ? null : onCheckOut,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(busy
                ? 'Checking out'
                : enabled
                    ? 'Check out  ${folio.total.toStringAsFixed(2)}'
                    : 'View only'),
          ),
        ),
      ),
    );
  }
}
