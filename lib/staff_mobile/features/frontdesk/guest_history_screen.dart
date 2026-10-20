import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/booking.dart';
import '../../data/front_desk_repository.dart';
import '../../data/guest_history.dart';
import '../../data/money.dart';
import '../../session/staff_session.dart';
import '../../theme/staff_theme.dart';

final _guestHistoryProvider =
    FutureProvider.autoDispose<List<GuestRecord>>((ref) async {
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));
  return ref.watch(frontDeskRepositoryProvider).loadGuestHistory();
});

/// Who has stayed before, and what they asked for.
///
/// The point is recognition at the desk: knowing that the person in front of
/// you is on their fourth visit, and that last time they asked for a quiet
/// room, is the difference between a transaction and being remembered. The
/// data was always there — only the view was missing.
class GuestHistoryScreen extends ConsumerStatefulWidget {
  const GuestHistoryScreen({super.key});

  @override
  ConsumerState<GuestHistoryScreen> createState() =>
      _GuestHistoryScreenState();
}

class _GuestHistoryScreenState extends ConsumerState<GuestHistoryScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  bool _returningOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_guestHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Guests')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Search by name, phone or email',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: FilterChip(
                label: const Text('Returning only'),
                selected: _returningOnly,
                onSelected: (v) => setState(() => _returningOnly = v),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(_guestHistoryProvider.future),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Could not load guests.\n\n$e',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ]),
                data: (records) {
                  final visible = _filter(records);
                  if (visible.isEmpty) {
                    return ListView(children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          _search.isEmpty && !_returningOnly
                              ? 'No guests yet.'
                              : 'Nobody matches.',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _GuestCard(record: visible[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<GuestRecord> _filter(List<GuestRecord> records) {
    final q = _search.trim().toLowerCase();
    return records.where((r) {
      if (_returningOnly && !r.isReturning) return false;
      if (q.isEmpty) return true;
      // Phone and email as well as name: a desk often has only the number the
      // guest called from.
      return r.guest.fullName.toLowerCase().contains(q) ||
          r.guest.phone.toLowerCase().contains(q) ||
          r.guest.email.toLowerCase().contains(q);
    }).toList();
  }
}

class _GuestCard extends ConsumerStatefulWidget {
  final GuestRecord record;
  const _GuestCard({required this.record});

  @override
  ConsumerState<_GuestCard> createState() => _GuestCardState();
}

class _GuestCardState extends ConsumerState<_GuestCard> {
  bool _expanded = false;

  static final _dayFormat = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = ref.watch(moneyProvider);
    final record = widget.record;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: record.stays.isEmpty
            ? null
            : () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.guest.fullName.trim().isEmpty
                          ? 'Unnamed guest'
                          : record.guest.fullName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // A returning guest is the one fact worth seeing without
                  // reading anything else on the card.
                  if (record.isReturning)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: StaffTheme.tableReady.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${record.visitCount} visits',
                        style: const TextStyle(
                          color: StaffTheme.tableReady,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              if (record.guest.phone.trim().isNotEmpty ||
                  record.guest.email.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  [record.guest.phone, record.guest.email]
                      .where((v) => v.trim().isNotEmpty)
                      .join('  ·  '),
                  style:
                      TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              if (record.visitCount > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Stat(
                      label: 'Nights',
                      value: '${record.totalNights}',
                    ),
                    const SizedBox(width: 20),
                    _Stat(
                      label: 'Spend',
                      value: money.format(record.totalSpend),
                    ),
                    const SizedBox(width: 20),
                    if (record.lastStay != null)
                      _Stat(
                        label: 'Last stay',
                        value: _dayFormat.format(record.lastStay!),
                      ),
                  ],
                ),
              ],

              if (record.pastRequests.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final request in record.pastRequests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.push_pin_outlined,
                            size: 14, color: scheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              if (_expanded) ...[
                const Divider(height: 20),
                for (final stay in record.stays)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            _dayFormat.format(stay.booking.checkInDate),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Room ${stay.room?.roomNumber ?? '—'}'
                            '  ·  ${_statusLabel(stay.booking.status)}',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                        Text(
                          money.format(stay.booking.totalAmount),
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ] else if (record.stays.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Tap for all ${record.stays.length} booking'
                    '${record.stays.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(BookingStatus s) => switch (s) {
        BookingStatus.pending => 'Booked',
        BookingStatus.checkedIn => 'In house',
        BookingStatus.checkedOut => 'Stayed',
        BookingStatus.cancelled => 'Cancelled',
      };
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        Text(label,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
