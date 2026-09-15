import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/booking.dart';
import '../../domain/entities/guest.dart';
import '../../domain/entities/room.dart';
import '../../providers/service_providers.dart';

/// Where a booking sits relative to today, which is what a front desk actually
/// sorts by — not the raw BookingStatus.
enum ArrivalBucket {
  /// Due to arrive today and not yet checked in.
  arrivingToday,

  /// Checked in, and today is their departure day.
  departingToday,

  /// Checked in, staying beyond today.
  inHouse,

  /// Arriving on a later date.
  upcoming,
}

/// A booking with its guest and room resolved.
class ArrivalEntry {
  final Booking booking;
  final Guest? guest;
  final Room? room;

  const ArrivalEntry({required this.booking, this.guest, this.room});

  String get guestName =>
      (guest?.fullName.trim().isNotEmpty ?? false) ? guest!.fullName : 'Guest';

  String get roomLabel => room?.roomNumber ?? 'Unassigned';

  int get nights =>
      booking.checkOutDate.difference(booking.checkInDate).inDays.clamp(0, 999);

  ArrivalBucket? bucketFor(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    bool sameDay(DateTime d) =>
        d.year == day.year && d.month == day.month && d.day == day.day;

    switch (booking.status) {
      case BookingStatus.cancelled:
      case BookingStatus.checkedOut:
        return null;
      case BookingStatus.pending:
        if (sameDay(booking.checkInDate)) return ArrivalBucket.arrivingToday;
        // A pending booking whose date has passed is a no-show; it stays in
        // arrivingToday so the desk can see and deal with it rather than
        // having it silently vanish.
        if (booking.checkInDate.isBefore(day)) return ArrivalBucket.arrivingToday;
        return ArrivalBucket.upcoming;
      case BookingStatus.checkedIn:
        if (sameDay(booking.checkOutDate) ||
            booking.checkOutDate.isBefore(day)) {
          return ArrivalBucket.departingToday;
        }
        return ArrivalBucket.inHouse;
    }
  }
}

/// Reads for the front-desk surfaces.
///
/// Same seam principle as [RestaurantRepository]: screens never call a service
/// directly, so a cache can be introduced in one place later.
///
/// Note these screens refresh on pull rather than realtime. Only
/// `restaurant_orders` is in the `supabase_realtime` publication — `bookings`,
/// `check_ins` and `rooms` are not, so a subscription here would silently never
/// fire. Adding them is a one-line migration, deliberately not taken here
/// because this change touches no backend.
class FrontDeskRepository {
  final Ref _ref;
  FrontDeskRepository(this._ref);

  /// Every live booking with guest and room attached.
  Future<List<ArrivalEntry>> loadArrivals() async {
    final rows = await _ref.read(bookingServiceProvider).getEnrichedBookings();
    return rows
        .map((r) => ArrivalEntry(
              booking: r['booking'] as Booking,
              guest: r['guest'] as Guest?,
              room: r['room'] as Room?,
            ))
        .toList();
  }

  Future<List<Room>> loadRooms() async {
    final rooms = await _ref.read(bookingServiceProvider).getAllRooms();
    rooms.sort(_byRoomNumber);
    return rooms;
  }

  /// Numeric where room numbers are numeric ("2" before "10"), otherwise
  /// case-insensitive text.
  static int _byRoomNumber(Room a, Room b) {
    final an = int.tryParse(a.roomNumber.trim());
    final bn = int.tryParse(b.roomNumber.trim());
    if (an != null && bn != null) return an.compareTo(bn);
    if (an != null) return -1;
    if (bn != null) return 1;
    return a.roomNumber.toLowerCase().compareTo(b.roomNumber.toLowerCase());
  }
}

final frontDeskRepositoryProvider = Provider<FrontDeskRepository>(
  FrontDeskRepository.new,
);
