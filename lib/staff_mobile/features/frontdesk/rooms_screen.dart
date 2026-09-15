import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/room.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/front_desk_repository.dart';
import '../../session/staff_session.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/offline_banner.dart';
import 'front_desk_message.dart';

final _roomsProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));
  return ref.watch(frontDeskRepositoryProvider).loadRooms();
});

/// Room board — status at a glance, updatable from the corridor.
///
/// Housekeeping's whole case for being on a phone is not carrying a paper round
/// back to the desk, so status changes are available here rather than read-only.
///
/// A caveat worth knowing: `rooms.status` is a three-state column
/// (available / occupied / maintenance). There is no separate housekeeping
/// state, so "dirty / cleaning / inspected / ready" cannot be expressed yet —
/// that needs a schema column, and this change touches no backend.
class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  RoomStatus? _filter;
  final _busy = <String>{};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_roomsProvider);
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final mayEdit = session?.canEdit('hotel_rooms') ?? false;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FrontDeskMessage(
        icon: Icons.error_outline_rounded,
        title: 'Could not load rooms',
        body: '$e',
        onRetry: () => ref.invalidate(_roomsProvider),
      ),
      data: (rooms) {
        final counts = <RoomStatus, int>{
          for (final s in RoomStatus.values)
            s: rooms.where((r) => r.status == s).length,
        };
        final visible =
            _filter == null ? rooms : rooms.where((r) => r.status == _filter).toList();

        return Column(
          children: [
            _StatusBar(
              total: rooms.length,
              counts: counts,
              selected: _filter,
              onSelected: (s) => setState(() => _filter = s),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.refresh(_roomsProvider.future),
                child: visible.isEmpty
                    ? FrontDeskMessage(
                        icon: Icons.meeting_room_outlined,
                        title: rooms.isEmpty ? 'No rooms yet' : 'Nothing here',
                        body: rooms.isEmpty
                            ? 'Rooms are set up on the web panel.'
                            : 'No room has this status right now.',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisExtent: 124,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (_, i) => _RoomCard(
                          room: visible[i],
                          busy: _busy.contains(visible[i].id),
                          onTap: mayEdit ? () => _cycle(visible[i]) : null,
                          onBlocked: mayEdit ? null : _explainReadOnly,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _explainReadOnly() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'You have view-only access to Rooms, so you cannot change status.',
          ),
        ),
      );
  }

  Future<void> _cycle(Room room) async {
    if (_busy.contains(room.id)) return;
    setState(() => _busy.add(room.id));
    final isOnline = ref.read(isOnlineProvider);

    try {
      // Reuses the service's own cycle rather than deciding the next status
      // here: available -> maintenance -> available, occupied -> occupied.
      await ref.read(bookingServiceProvider).toggleRoomStatus(room);
      if (!mounted) return;
      setState(() => _busy.remove(room.id));
      // Rooms are not in the realtime publication, so refresh explicitly.
      ref.invalidate(_roomsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(room.id));
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Updating room ${room.roomNumber}',
      );
    }
  }
}

class _StatusBar extends StatelessWidget {
  final int total;
  final Map<RoomStatus, int> counts;
  final RoomStatus? selected;
  final ValueChanged<RoomStatus?> onSelected;

  const _StatusBar({
    required this.total,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ChoiceChip(
            label: Text('All  $total'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final status in RoomStatus.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('${_label(status)}  ${counts[status] ?? 0}'),
              selected: selected == status,
              onSelected: (_) => onSelected(status),
            ),
          ],
        ],
      ),
    );
  }

  static String _label(RoomStatus s) => switch (s) {
        RoomStatus.available => 'Available',
        RoomStatus.occupied => 'Occupied',
        RoomStatus.maintenance => 'Maintenance',
      };
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onBlocked;

  const _RoomCard({
    required this.room,
    required this.busy,
    required this.onTap,
    required this.onBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent(room.status);

    // An occupied room is not something housekeeping flips from the corridor —
    // it clears when the guest checks out. Tapping it would either do nothing
    // or do something surprising, so it is not offered.
    final tappable = onTap != null && room.status != RoomStatus.occupied;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : (tappable ? onTap : onBlocked),
        child: Stack(
          children: [
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
                          room.roomNumber,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (busy)
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${room.typeLabel}  ·  Floor ${room.floor}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      room.statusLabel.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    tappable
                        ? 'Tap to mark ${_nextLabel(room.status)}'
                        : room.status == RoomStatus.occupied
                            ? 'Clears at check-out'
                            : '',
                    style: TextStyle(
                      fontSize: 11.5,
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

  static String _nextLabel(RoomStatus s) => switch (s) {
        RoomStatus.available => 'maintenance',
        RoomStatus.maintenance => 'available',
        RoomStatus.occupied => '',
      };

  static Color _accent(RoomStatus s) => switch (s) {
        RoomStatus.available => StaffTheme.tableReady,
        RoomStatus.occupied => StaffTheme.tableSeated,
        RoomStatus.maintenance => StaffTheme.tableBillRequested,
      };
}
