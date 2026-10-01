import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/booking.dart';
import '../../domain/entities/guest.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/restaurant_order.dart';
import '../../domain/entities/room.dart';
import '../../providers/service_providers.dart';
import 'guest_history.dart';

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


/// Everything a guest owes at check-out, assembled from the three places a
/// charge can come from.
class GuestFolio {
  final ArrivalEntry stay;

  /// Restaurant orders that were billed to the room.
  final List<RestaurantOrder> restaurantOrders;

  /// Room-linked expenses — minibar, laundry, damages.
  final List<Expense> expenses;

  const GuestFolio({
    required this.stay,
    this.restaurantOrders = const [],
    this.expenses = const [],
  });

  /// What the room itself costs for the stay.
  double get roomCharge => stay.booking.totalAmount;

  double get restaurantTotal =>
      restaurantOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

  /// Only billable expenses reach the guest — an internal cost recorded
  /// against the room is the hotel's, not theirs.
  double get expensesTotal => expenses
      .where((e) => e.isBillable)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get total => roomCharge + restaurantTotal + expensesTotal;

  bool get isEmpty =>
      restaurantOrders.isEmpty && expenses.isEmpty && roomCharge == 0;
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


  /// Assembles what a guest owes.
  ///
  /// The three sources are fetched together — a folio missing its restaurant
  /// charges because one call was slow would undercharge the guest.
  Future<GuestFolio> loadFolio(ArrivalEntry stay) async {
    final booking = _ref.read(bookingServiceProvider);
    final restaurant = _ref.read(restaurantServiceProvider);

    final results = await (
      restaurant.getChargedToRoomOrders(stay.booking.id),
      booking.getExpensesByBookingId(stay.booking.id),
    ).wait;

    return GuestFolio(
      stay: stay,
      restaurantOrders: results.$1,
      expenses: results.$2,
    );
  }

  /// Looks a booking up by its reference, for a guest arriving at the door
  /// with a confirmation on their phone.
  Future<ArrivalEntry?> lookupBooking(String bookingRef) async {
    final result =
        await _ref.read(bookingServiceProvider).lookupBooking(bookingRef.trim());
    if (result == null) return null;
    return ArrivalEntry(
      booking: result['booking'] as Booking,
      guest: result['guest'] as Guest?,
      room: result['room'] as Room?,
    );
  }

  /// Every guest with their stay history attached.
  ///
  /// Two reads rather than one per guest: pulling a guest's bookings
  /// individually would be an N+1 across the whole book, and the enriched
  /// booking query already returns everything needed to group them locally.
  Future<List<GuestRecord>> loadGuestHistory() async {
    final booking = _ref.read(bookingServiceProvider);
    final results = await (
      booking.getAllGuests(),
      booking.getEnrichedBookings(),
    ).wait;

    return buildGuestHistory(
      guests: results.$1,
      bookings: [
        for (final row in results.$2)
          (booking: row['booking'] as Booking, room: row['room'] as Room?),
      ],
    );
  }

  Future<List<Room>> loadRooms() async {
    final rooms = await _ref.read(bookingServiceProvider).getAllRooms();
    rooms.sort(_byRoomNumber);
    return rooms;
  }

  /// Moves a room through the cleaning cycle.
  ///
  /// Writes only the housekeeping column, deliberately leaving rooms.status
  /// alone: occupancy is driven by check-in and check-out, and a housekeeper
  /// marking a room clean must not accidentally free an occupied one.
  Future<void> setHousekeeping(Room room, HousekeepingStatus next) async {
    await Supabase.instance.client
        .from('rooms')
        .update({'housekeeping_status': next.name})
        .eq('id', room.id);
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
