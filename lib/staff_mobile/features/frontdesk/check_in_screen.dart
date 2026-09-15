import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/guest.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/front_desk_repository.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';

/// Check a guest in.
///
/// ## What is missing, and why
///
/// The roadmap specifies capturing the guest's ID by camera and taking a
/// signature — the camera being the reason this belongs on a phone at all.
/// Neither is here, and it is not an oversight: there is nowhere to put the
/// files. The only storage bucket in the project is `property-logos`, which is
/// public, and guest identity documents are exactly the kind of data that must
/// not land in a public bucket. `Guest` and `CheckIn` also carry no column for
/// a document URL.
///
/// Doing it properly needs a private bucket with its own RLS, a column, and a
/// retention decision about how long a photographed passport is kept. That is a
/// backend change and a privacy decision, so it is surfaced rather than bodged.
///
/// Everything else works: look the booking up, confirm and correct the guest's
/// details, and check them in from the door.
class CheckInScreen extends ConsumerStatefulWidget {
  /// Pre-selected stay, when arriving from the arrivals board.
  final ArrivalEntry? stay;

  const CheckInScreen({super.key, this.stay});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _refController = TextEditingController();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _nationality = TextEditingController();
  String _idType = 'Passport';

  ArrivalEntry? _stay;
  bool _looking = false;
  bool _checkingIn = false;
  String? _lookupError;

  static const _idTypes = ['Passport', 'NIC', 'Driving Licence', 'Other'];
  static final _dayFormat = DateFormat('EEE d MMM');

  @override
  void initState() {
    super.initState();
    if (widget.stay != null) _adopt(widget.stay!);
  }

  @override
  void dispose() {
    _refController.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _idNumber.dispose();
    _nationality.dispose();
    super.dispose();
  }

  void _adopt(ArrivalEntry stay) {
    _stay = stay;
    final guest = stay.guest;
    _name.text = guest?.fullName ?? '';
    _email.text = guest?.email ?? '';
    _phone.text = guest?.phone ?? '';
    _idNumber.text = guest?.idNumber ?? '';
    _nationality.text = guest?.nationality ?? '';
    if (guest != null && _idTypes.contains(guest.idType)) {
      _idType = guest.idType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final mayCheckIn = session?.canEdit('hotel_checkins') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Check in')),
      body: Column(
        children: [
          const OfflineBanner(),
          if (!mayCheckIn)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'View only — you cannot check guests in.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: _stay == null ? _lookupView() : _detailsView(mayCheckIn),
          ),
        ],
      ),
    );
  }

  Widget _lookupView() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        Icon(Icons.qr_code_2_rounded, size: 56, color: scheme.primary),
        const SizedBox(height: 18),
        Text('Find the booking',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Enter the reference from the guest\'s confirmation, or pick them '
          'off the arrivals list.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _refController,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Booking reference',
            hintText: 'BK-0001',
            prefixIcon: Icon(Icons.confirmation_number_outlined),
          ),
          onSubmitted: (_) => _lookup(),
        ),
        if (_lookupError != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 20, color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_lookupError!,
                      style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _looking ? null : _lookup,
          child: _looking
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Find booking'),
        ),
      ],
    );
  }

  Widget _detailsView(bool mayCheckIn) {
    final stay = _stay!;
    final scheme = Theme.of(context).colorScheme;
    final booking = stay.booking;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(booking.bookingRef,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Room ${stay.roomLabel}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: scheme.onSecondaryContainer,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_dayFormat.format(booking.checkInDate)} → '
                    '${_dayFormat.format(booking.checkOutDate)}  ·  '
                    '${stay.nights} night${stay.nights == 1 ? '' : 's'}  ·  '
                    '${booking.numberOfGuests} guest'
                    '${booking.numberOfGuests == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
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
                          child: Text(booking.specialRequests,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.primary,
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Guest details',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Correct anything the guest tells you — this is saved with the '
            'check-in.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'A name is needed to check in'
                : null,
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
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return null;
              // Deliberately loose: a desk should not be blocked by a strict
              // pattern rejecting a valid but unusual address.
              return value.contains('@') ? null : 'That does not look like an email';
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _idType,
            decoration: const InputDecoration(
              labelText: 'ID type',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: [
              for (final type in _idTypes)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (v) => setState(() => _idType = v ?? _idType),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _idNumber,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'ID number',
              prefixIcon: Icon(Icons.numbers_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nationality,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nationality',
              prefixIcon: Icon(Icons.public_rounded),
            ),
          ),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.photo_camera_outlined,
                    size: 19, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Photographing the ID and taking a signature are not '
                    'available yet — they need somewhere private to store the '
                    'files. Record the ID number above in the meantime.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (!mayCheckIn || _checkingIn) ? null : _checkIn,
            icon: _checkingIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.how_to_reg_rounded),
            label: Text(_checkingIn ? 'Checking in' : 'Check in'),
          ),
          const SizedBox(height: 8),
          if (widget.stay == null)
            TextButton(
              onPressed: () => setState(() {
                _stay = null;
                _lookupError = null;
              }),
              child: const Text('Find a different booking'),
            ),
        ],
      ),
    );
  }

  Future<void> _lookup() async {
    final ref_ = _refController.text.trim();
    if (ref_.isEmpty) {
      setState(() => _lookupError = 'Enter a booking reference.');
      return;
    }

    setState(() {
      _looking = true;
      _lookupError = null;
    });

    try {
      final found =
          await ref.read(frontDeskRepositoryProvider).lookupBooking(ref_);
      if (!mounted) return;

      if (found == null) {
        setState(() {
          _looking = false;
          _lookupError = 'No booking matches "$ref_" on this property.';
        });
        return;
      }

      // Guard against checking someone in twice, or checking in a booking
      // that was cancelled — both leave the room state wrong.
      final status = found.booking.status.name;
      if (status == 'checkedIn') {
        setState(() {
          _looking = false;
          _lookupError = '${found.guestName} is already checked in.';
        });
        return;
      }
      if (status == 'cancelled' || status == 'checkedOut') {
        setState(() {
          _looking = false;
          _lookupError = 'That booking is $status and cannot be checked in.';
        });
        return;
      }

      setState(() {
        _looking = false;
        _adopt(found);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _looking = false;
        _lookupError = 'Could not look that up: $e';
      });
    }
  }

  Future<void> _checkIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final stay = _stay!;

    setState(() => _checkingIn = true);
    final isOnline = ref.read(isOnlineProvider);

    // Carries the existing guest id forward so this updates the booking's
    // guest rather than creating a duplicate person.
    final guest = Guest(
      id: stay.guest?.id ?? stay.booking.guestId,
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      idType: _idType,
      idNumber: _idNumber.text.trim(),
      nationality: _nationality.text.trim(),
      passportOrNic: stay.guest?.passportOrNic,
      dateOfBirth: stay.guest?.dateOfBirth,
      whatsApp: stay.guest?.whatsApp,
    );

    try {
      await ref.read(bookingServiceProvider).performCheckIn(
            booking: stay.booking,
            guest: guest,
          );
      if (!mounted) return;
      setState(() => _checkingIn = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${guest.fullName} checked in to room ${stay.roomLabel}',
            ),
          ),
        );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingIn = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Checking ${guest.fullName} in',
      );
    }
  }
}
