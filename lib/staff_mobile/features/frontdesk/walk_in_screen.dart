import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/booking.dart';
import '../../../domain/entities/guest.dart';
import '../../../domain/entities/room.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/front_desk_repository.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';
import '../../data/money.dart';

const _uuid = Uuid();

final _availableRoomsProvider =
    FutureProvider.autoDispose<List<Room>>((ref) async {
  final rooms = await ref.watch(frontDeskRepositoryProvider).loadRooms();
  // Only rooms that can actually take a guest tonight.
  return rooms.where((r) => r.status == RoomStatus.available).toList();
});

/// Quick create for a walk-in.
///
/// Deliberately minimal: a guest is standing at the desk, so this asks only for
/// what a booking cannot exist without. Channel attribution is fixed to direct,
/// which is what a walk-in is, and rate editing stays on the web where the
/// locked-rate rules live — guessing at those here would risk writing a price
/// the property never agreed to.
class WalkInScreen extends ConsumerStatefulWidget {
  const WalkInScreen({super.key});

  @override
  ConsumerState<WalkInScreen> createState() => _WalkInScreenState();
}

class _WalkInScreenState extends ConsumerState<WalkInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  Room? _room;
  DateTime _checkIn = DateTime.now();
  DateTime _checkOut = DateTime.now().add(const Duration(days: 1));
  int _guests = 1;
  bool _saving = false;

  static final _dayFormat = DateFormat('EEE d MMM');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  int get _nights => _checkOut.difference(_checkIn).inDays.clamp(1, 365);

  double get _estimate => (_room?.pricePerNight ?? 0) * _nights;

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(_availableRoomsProvider);
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final mayCreate = session?.canEdit('hotel_reservations') ?? false;
    final scheme = Theme.of(context).colorScheme;
    final money = ref.watch(moneyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Walk-in booking')),
      body: Column(
        children: [
          const OfflineBanner(),
          if (!mayCreate)
            Container(
              width: double.infinity,
              color: scheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'View only — you cannot create reservations.',
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Guest name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'A name is needed' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('Stay', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Arriving',
                          value: _checkIn,
                          format: _dayFormat,
                          onPick: _pickCheckIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'Leaving',
                          value: _checkOut,
                          format: _dayFormat,
                          onPick: _pickCheckOut,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('$_nights night${_nights == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Guests',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      IconButton(
                        onPressed: _guests > 1
                            ? () => setState(() => _guests--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text('$_guests',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _guests++),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Text('Room', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  roomsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('Could not load rooms.\n\n$e'),
                    data: (rooms) {
                      if (rooms.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'No rooms are free right now. Check someone out '
                              'first, or create this booking on the web where '
                              'you can override.',
                              style:
                                  TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final room in rooms)
                            ChoiceChip(
                              label: Text(
                                  '${room.roomNumber} · ${room.typeLabel}'),
                              selected: _room?.id == room.id,
                              onSelected: (_) => setState(() => _room = room),
                            ),
                        ],
                      );
                    },
                  ),

                  if (_room != null) ...[
                    const SizedBox(height: 18),
                    Card(
                      color: scheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$_nights night${_nights == 1 ? '' : 's'} at '
                                '${money.format(_room!.pricePerNight)}',
                                style: TextStyle(
                                    color: scheme.onSecondaryContainer),
                              ),
                            ),
                            Text(money.format(_estimate),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSecondaryContainer,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: (!mayCreate || _saving) ? null : _create,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.event_available_rounded),
                    label: Text(_saving ? 'Creating' : 'Create booking'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCheckIn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _checkIn = picked;
      // Keep the stay valid: a departure on or before arrival is not a stay.
      if (!_checkOut.isAfter(_checkIn)) {
        _checkOut = _checkIn.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickCheckOut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOut,
      firstDate: _checkIn.add(const Duration(days: 1)),
      lastDate: _checkIn.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _checkOut = picked);
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_room == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Pick a room first.')));
      return;
    }

    setState(() => _saving = true);
    final booking = ref.read(bookingServiceProvider);
    final isOnline = ref.read(isOnlineProvider);

    try {
      final guest = Guest(
        id: _uuid.v4(),
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        idType: 'Passport',
        idNumber: '',
        nationality: '',
      );
      await booking.addGuest(guest);

      // Reference comes from the server sequence, so a walk-in taken on the
      // phone numbers consistently with one taken on the web.
      final reference = await booking.getNextBookingRef();

      await booking.addReservation(Booking(
        id: _uuid.v4(),
        bookingRef: reference,
        guestId: guest.id,
        roomId: _room!.id,
        checkInDate: _checkIn,
        checkOutDate: _checkOut,
        status: BookingStatus.pending,
        numberOfGuests: _guests,
        source: BookingSource.direct,
        totalAmount: _estimate,
      ));

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            '$reference created for ${guest.fullName} — room '
            '${_room!.roomNumber}',
          ),
        ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Creating the booking',
      );
    }
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final DateFormat format;
  final VoidCallback onPick;

  const _DateField({
    required this.label,
    required this.value,
    required this.format,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(format.format(value),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
