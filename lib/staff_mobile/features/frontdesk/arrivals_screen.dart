import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/front_desk_repository.dart';
import '../../session/staff_session.dart';
import '../../theme/staff_theme.dart';
import 'front_desk_message.dart';

final _arrivalsProvider =
    FutureProvider.autoDispose<List<ArrivalEntry>>((ref) async {
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));
  return ref.watch(frontDeskRepositoryProvider).loadArrivals();
});

/// Today's front desk: who is arriving, who is leaving, who is in house.
///
/// Read-only in this build. Performing a check-in needs ID capture by camera
/// and a signature — that is the reason the flow belongs on mobile at all, and
/// also why it is its own piece of work rather than a button bolted on here.
class ArrivalsScreen extends ConsumerStatefulWidget {
  const ArrivalsScreen({super.key});

  @override
  ConsumerState<ArrivalsScreen> createState() => _ArrivalsScreenState();
}

class _ArrivalsScreenState extends ConsumerState<ArrivalsScreen> {
  ArrivalBucket _bucket = ArrivalBucket.arrivingToday;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_arrivalsProvider);
    final today = DateTime.now();

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FrontDeskMessage(
        icon: Icons.error_outline_rounded,
        title: 'Could not load arrivals',
        body: '$e',
        onRetry: () => ref.invalidate(_arrivalsProvider),
      ),
      data: (all) {
        // Bucket once, so the counts on the chips and the list below can never
        // disagree with each other.
        final byBucket = <ArrivalBucket, List<ArrivalEntry>>{
          for (final b in ArrivalBucket.values) b: [],
        };
        for (final entry in all) {
          final b = entry.bucketFor(today);
          if (b != null) byBucket[b]!.add(entry);
        }
        for (final list in byBucket.values) {
          list.sort(
              (a, b) => a.booking.checkInDate.compareTo(b.booking.checkInDate));
        }

        final visible = byBucket[_bucket]!;

        return Column(
          children: [
            _BucketBar(
              counts: {for (final e in byBucket.entries) e.key: e.value.length},
              selected: _bucket,
              onSelected: (b) => setState(() => _bucket = b),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.refresh(_arrivalsProvider.future),
                child: visible.isEmpty
                    ? FrontDeskMessage(
                        icon: Icons.event_available_outlined,
                        title: switch (_bucket) {
                          ArrivalBucket.arrivingToday => 'No arrivals today',
                          ArrivalBucket.departingToday => 'No departures today',
                          ArrivalBucket.inHouse => 'Nobody in house',
                          ArrivalBucket.upcoming => 'Nothing upcoming',
                        },
                        body: 'Reservations are created on the web panel.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ArrivalCard(
                          entry: visible[i],
                          bucket: _bucket,
                          today: today,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BucketBar extends StatelessWidget {
  final Map<ArrivalBucket, int> counts;
  final ArrivalBucket selected;
  final ValueChanged<ArrivalBucket> onSelected;

  const _BucketBar({
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  static const _labels = {
    ArrivalBucket.arrivingToday: 'Arriving',
    ArrivalBucket.departingToday: 'Departing',
    ArrivalBucket.inHouse: 'In house',
    ArrivalBucket.upcoming: 'Upcoming',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final bucket in ArrivalBucket.values) ...[
            ChoiceChip(
              label: Text('${_labels[bucket]}  ${counts[bucket] ?? 0}'),
              selected: selected == bucket,
              onSelected: (_) => onSelected(bucket),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ArrivalCard extends StatelessWidget {
  final ArrivalEntry entry;
  final ArrivalBucket bucket;
  final DateTime today;

  const _ArrivalCard({
    required this.entry,
    required this.bucket,
    required this.today,
  });

  static final _dayFormat = DateFormat('EEE d MMM');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final booking = entry.booking;

    final day = DateTime(today.year, today.month, today.day);
    final isOverdueArrival = bucket == ArrivalBucket.arrivingToday &&
        booking.checkInDate.isBefore(day);
    final isOverdueDeparture = bucket == ArrivalBucket.departingToday &&
        booking.checkOutDate.isBefore(day);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.guestName,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.roomLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${booking.bookingRef}  ·  ${entry.nights} night'
              '${entry.nights == 1 ? '' : 's'}  ·  '
              '${booking.numberOfGuests} guest'
              '${booking.numberOfGuests == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.login_rounded,
                    size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(_dayFormat.format(booking.checkInDate),
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 14),
                Icon(Icons.logout_rounded,
                    size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(_dayFormat.format(booking.checkOutDate),
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (booking.specialRequests.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking.specialRequests,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // A date that has already passed is the thing a desk must act on,
            // so it is called out rather than left for someone to spot.
            if (isOverdueArrival || isOverdueDeparture) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 15, color: StaffTheme.tableInKitchen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isOverdueArrival
                          ? 'Expected ${_dayFormat.format(booking.checkInDate)}, '
                              'not checked in yet'
                          : 'Due out ${_dayFormat.format(booking.checkOutDate)}, '
                              'still checked in',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: StaffTheme.tableInKitchen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (entry.guest?.phone.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(entry.guest!.phone,
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
